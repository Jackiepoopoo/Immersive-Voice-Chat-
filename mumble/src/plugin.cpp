#include <windows.h>
#include <cstdint>
#include <cstring>
#include <cmath>
#include <string>
#include <vector>
#include <unordered_map>

#include "MumblePlugin.h"
#include "SharedMemory.h"
#include "LowPassFilter.h"

static mumble_plugin_id_t g_pluginID = 0;
static MumbleAPI g_api = {};
static mumble_connection_t g_connection = -1;

static HANDLE g_hMapFile = nullptr;
static VOSharedData* g_sharedData = nullptr;
static uint32_t g_lastTick = 0;
static uint32_t g_ticksSinceUpdate = 0;
static DWORD g_lastUpdateTimeMs = 0;

static std::unordered_map<uint32_t, LowPassFilter> g_filters;
static std::unordered_map<uint32_t, LowPassFilter> g_distFilters;
static std::unordered_map<uint32_t, float> g_lastOcclusion;
static std::unordered_map<uint32_t, float> g_currentCutoff;
static std::unordered_map<uint32_t, float> g_currentDistCutoff;
static std::unordered_map<uint32_t, std::string> g_userNames;

// Doppler: track previous speaker positions per user
struct DopplerState {
    float prevPos[3];
    uint32_t prevTick;
    float pitchShift;
};
static std::unordered_map<uint32_t, DopplerState> g_doppler;

// Simple reverb using multiple comb filters with high-frequency damping
static const uint32_t REVERB_MAX_DELAY = 6000;  // 125ms at 48kHz
// Prime-number delay times avoid harmonic resonance (metallic sound)
static const uint32_t REVERB_DELAYS[] = { 1559, 2137, 2909, 3823 };
static const float REVERB_FEEDBACK_BASE = 0.65f;

struct ReverbState {
    float bufs[4][REVERB_MAX_DELAY] = {};
    uint32_t positions[4] = {};
    float lpfState[4] = {};  // Low-pass state per comb filter
};

static std::unordered_map<uint32_t, ReverbState> g_reverb;

static const float CLEAR_CUTOFF = 20000.0f;
static const float OCCLUDED_CUTOFF = 80.0f;
static const float PROXIMITY_MIN_DIST = 80.0f;
static const float PROXIMITY_MAX_DIST = 1000.0f;
static const float FILTER_BYPASS_THRESHOLD = 0.02f;
static const float PI = 3.14159265358979f;
static const float DIST_ROLLOFF_MIN_DIST = 200.0f;
static const float DIST_ROLLOFF_MAX_DIST = 1200.0f;
static const float UNDERWATER_CUTOFF = 500.0f;
static const float SPEED_OF_SOUND = 1100.0f;  // Source engine units/sec

static bool OpenSharedMemory() {
    g_hMapFile = OpenFileMappingA(FILE_MAP_READ, FALSE, VO_SHARED_MEMORY_NAME);
    if (!g_hMapFile) return false;

    g_sharedData = (VOSharedData*)MapViewOfFile(g_hMapFile, FILE_MAP_READ, 0, 0, sizeof(VOSharedData));
    if (!g_sharedData) {
        CloseHandle(g_hMapFile);
        g_hMapFile = nullptr;
        return false;
    }
    return true;
}

static void CloseSharedMemory() {
    if (g_sharedData) { UnmapViewOfFile(g_sharedData); g_sharedData = nullptr; }
    if (g_hMapFile) { CloseHandle(g_hMapFile); g_hMapFile = nullptr; }
}

struct LookupResult {
    float occlusion;
    float distance;
    float position[3];
    float velocity[3];
    float indoorAmount;
    float roomSize;
    uint32_t isUnderwater;
    uint32_t voiceMode;
};

static LookupResult LookupPlayer(const char* name) {
    LookupResult result = { 0.0f, 0.0f, {0, 0, 0}, {0, 0, 0}, 0.0f, 0.0f, 0, 1 };
    if (!g_sharedData || g_sharedData->version != VO_SHARED_VERSION) return result;
    for (uint32_t i = 0; i < g_sharedData->playerCount && i < VO_MAX_PLAYERS; i++) {
        if (_stricmp(g_sharedData->players[i].name, name) == 0) {
            result.occlusion = g_sharedData->players[i].occlusion;
            result.distance = g_sharedData->players[i].distance;
            result.position[0] = g_sharedData->players[i].position[0];
            result.position[1] = g_sharedData->players[i].position[1];
            result.position[2] = g_sharedData->players[i].position[2];
            result.velocity[0] = g_sharedData->players[i].velocity[0];
            result.velocity[1] = g_sharedData->players[i].velocity[1];
            result.velocity[2] = g_sharedData->players[i].velocity[2];
            result.indoorAmount = g_sharedData->players[i].indoorAmount;
            result.roomSize = g_sharedData->players[i].roomSize;
            result.isUnderwater = g_sharedData->players[i].isUnderwater;
            result.voiceMode = g_sharedData->players[i].voiceMode;
            return result;
        }
    }
    return result;
}

static std::string GetUserName(mumble_userid_t userID) {
    if (!g_api.getUserName || g_connection < 0) return "";

    const char* name = nullptr;
    mumble_error_t err = g_api.getUserName(g_pluginID, g_connection, userID, &name);
    if (err != MUMBLE_EC_OK || !name) return "";

    std::string result(name);
    g_api.freeMemory(g_pluginID, name);
    return result;
}

static void RefreshConnection() {
    if (g_api.getActiveServerConnection && g_api.isConnectionSynchronized) {
        mumble_connection_t conn = -1;
        g_api.getActiveServerConnection(g_pluginID, &conn);
        if (conn >= 0) {
            bool synced = false;
            g_api.isConnectionSynchronized(g_pluginID, conn, &synced);
            if (synced) {
                g_connection = conn;
            }
        }
    }
}

static void ApplyStereoPanning(float *pcm, uint32_t sampleCount, uint16_t channelCount, float pan) {
    if (channelCount < 2) return;

    // pan: -1 = full left, 0 = center, +1 = full right
    // Equal-power panning
    float angle = (pan + 1.0f) * 0.25f * PI;  // 0 to PI/2
    float leftGain = cosf(angle);
    float rightGain = sinf(angle);

    for (uint32_t i = 0; i < sampleCount; i++) {
        pcm[i * 2]     *= leftGain;
        pcm[i * 2 + 1] *= rightGain;
    }
}

static void ApplyReverb(float *pcm, uint32_t sampleCount, uint16_t channelCount, uint32_t sampleRate, float indoorAmount, float roomSize, float surfaceAbsorb) {
    if (indoorAmount < 0.05f) return;

    auto& rev = g_reverb[0];

    // Room size scales reverb parameters
    // roomSize: 0-200 = small room, 200-500 = medium, 500+ = large hall/mall
    float sizeNorm = roomSize / 200.0f;
    if (sizeNorm > 1.0f) sizeNorm = 1.0f;

    // Surface absorbency modulates reverb
    // High absorb (carpet/dirt): less reverb, more damping, less sustain
    // Low absorb (concrete/tile): more reverb, less damping, more sustain
    float absorbMod = 1.0f - surfaceAbsorb;

    float wetMix = indoorAmount * (0.20f + sizeNorm * 0.35f) * (0.3f + absorbMod * 0.7f);
    float feedback = (0.35f + sizeNorm * 0.40f + indoorAmount * 0.15f) * (0.4f + absorbMod * 0.6f);
    float damping = 0.55f - sizeNorm * 0.30f + surfaceAbsorb * 0.2f;

    uint32_t totalSamples = sampleCount * channelCount;
    for (uint32_t i = 0; i < totalSamples; i++) {
        float summed = 0.0f;

        for (int c = 0; c < 4; c++) {
            uint32_t readPos = (rev.positions[c] + REVERB_MAX_DELAY - REVERB_DELAYS[c]) % REVERB_MAX_DELAY;
            float delayed = rev.bufs[c][readPos];

            // High-frequency damping: simple low-pass in feedback loop
            // Simulates walls absorbing treble faster than bass
            rev.lpfState[c] = rev.lpfState[c] * (1.0f - damping) + delayed * damping;

            // Write input + damped feedback into delay line
            rev.bufs[c][rev.positions[c]] = pcm[i] + rev.lpfState[c] * feedback;
            rev.positions[c] = (rev.positions[c] + 1) % REVERB_MAX_DELAY;

            summed += delayed;
        }

        summed *= 0.25f;  // Average the 4 comb filters

        // Mix dry + wet
        pcm[i] = pcm[i] * (1.0f - wetMix) + summed * wetMix;
    }
}

static void ApplyUnderwaterEffect(float *pcm, uint32_t sampleCount, uint16_t channelCount, uint32_t sampleRate) {
    // Heavy low-pass simulating water absorption of high frequencies
    static float uwState = 0.0f;
    float alpha = 1.0f - expf(-2.0f * PI * UNDERWATER_CUTOFF / (float)sampleRate);
    
    uint32_t totalSamples = sampleCount * channelCount;
    for (uint32_t i = 0; i < totalSamples; i++) {
        uwState = uwState + alpha * (pcm[i] - uwState);
        pcm[i] = uwState * 0.7f;  // Also reduce overall volume underwater
    }
}

static void ApplyDopplerShift(float *pcm, uint32_t sampleCount, uint16_t channelCount, uint32_t sampleRate, mumble_userid_t userID, const float* speakerPos, const float* speakerVelocity, uint32_t currentTick) {
    if (!g_sharedData || !speakerPos || !speakerVelocity) return;
    
    auto& dop = g_doppler[userID];
    
    // Calculate relative velocity of speaker toward listener
    float lx = g_sharedData->listenerPosition[0];
    float ly = g_sharedData->listenerPosition[1];
    float lz = g_sharedData->listenerPosition[2];
    
    float dx = speakerPos[0] - lx;
    float dy = speakerPos[1] - ly;
    float dz = speakerPos[2] - lz;
    float dist = sqrtf(dx*dx + dy*dy + dz*dz);
    if (dist < 1.0f) return;
    
    // Unit vector from listener to speaker
    float ux = dx / dist;
    float uy = dy / dist;
    float uz = dz / dist;
    
    // Project speaker velocity onto listener->speaker direction
    // Positive = moving away, negative = moving toward
    float radialVel = speakerVelocity[0] * ux + speakerVelocity[1] * uy + speakerVelocity[2] * uz;
    
    // Doppler pitch shift: 1 + (radialVel / speedOfSound)
    // Moving toward: pitch goes up, Moving away: pitch goes down
    float targetShift = 1.0f + radialVel / SPEED_OF_SOUND;
    
    // Clamp to prevent extreme pitch shifts
    if (targetShift < 0.85f) targetShift = 0.85f;
    if (targetShift > 1.15f) targetShift = 1.15f;
    
    // Smooth the shift to prevent artifacts
    dop.pitchShift = dop.pitchShift + (targetShift - dop.pitchShift) * 0.1f;
    
    // Store current position for next frame
    dop.prevPos[0] = speakerPos[0];
    dop.prevPos[1] = speakerPos[1];
    dop.prevPos[2] = speakerPos[2];
    dop.prevTick = currentTick;
    
    // Apply pitch shift via linear interpolation resampling
    float shift = dop.pitchShift;
    if (fabsf(shift - 1.0f) < 0.005f) return;  // Skip if negligible
    
    uint32_t totalSamples = sampleCount * channelCount;
    uint32_t outSamples = (uint32_t)(totalSamples * shift);
    if (outSamples > totalSamples * 2) outSamples = totalSamples * 2;
    
    std::vector<float> temp(totalSamples);
    memcpy(temp.data(), pcm, totalSamples * sizeof(float));
    
    for (uint32_t i = 0; i < totalSamples; i++) {
        float readPos = (float)i / shift;
        uint32_t idx = (uint32_t)readPos;
        float frac = readPos - idx;
        
        if (idx + 1 < totalSamples) {
            pcm[i] = temp[idx] * (1.0f - frac) + temp[idx + 1] * frac;
        } else if (idx < totalSamples) {
            pcm[i] = temp[idx];
        } else {
            pcm[i] = 0.0f;
        }
    }
}

extern "C" {

MUMBLE_PLUGIN_EXPORT mumble_error_t MUMBLE_PLUGIN_CALLING_CONVENTION mumble_init(mumble_plugin_id_t id) {
    g_pluginID = id;
    OpenSharedMemory();
    return MUMBLE_EC_OK;
}

MUMBLE_PLUGIN_EXPORT void MUMBLE_PLUGIN_CALLING_CONVENTION mumble_shutdown() {
    CloseSharedMemory();
    g_filters.clear();
    g_distFilters.clear();
    g_userNames.clear();
    g_currentCutoff.clear();
    g_currentDistCutoff.clear();
    g_reverb.clear();
    g_doppler.clear();
}

MUMBLE_PLUGIN_EXPORT struct MumbleStringWrapper MUMBLE_PLUGIN_CALLING_CONVENTION mumble_getName() {
    static const char name[] = "Immersive Voice Chat";
    return { name, sizeof(name) - 1, false };
}

MUMBLE_PLUGIN_EXPORT mumble_version_t MUMBLE_PLUGIN_CALLING_CONVENTION mumble_getAPIVersion() {
    return MUMBLE_PLUGIN_API_VERSION;
}

MUMBLE_PLUGIN_EXPORT void MUMBLE_PLUGIN_CALLING_CONVENTION mumble_registerAPIFunctions(void *apiStruct) {
    if (apiStruct) {
        memcpy(&g_api, apiStruct, sizeof(MumbleAPI));
    }
}

MUMBLE_PLUGIN_EXPORT void MUMBLE_PLUGIN_CALLING_CONVENTION mumble_releaseResource(const void*) {}

MUMBLE_PLUGIN_EXPORT void MUMBLE_PLUGIN_CALLING_CONVENTION mumble_setMumbleInfo(mumble_version_t, mumble_version_t, mumble_version_t) {}

MUMBLE_PLUGIN_EXPORT mumble_version_t MUMBLE_PLUGIN_CALLING_CONVENTION mumble_getVersion() {
    return { 1, 0, 0 };
}

MUMBLE_PLUGIN_EXPORT struct MumbleStringWrapper MUMBLE_PLUGIN_CALLING_CONVENTION mumble_getAuthor() {
    static const char author[] = "ImmersiveVoiceChat";
    return { author, sizeof(author) - 1, false };
}

MUMBLE_PLUGIN_EXPORT struct MumbleStringWrapper MUMBLE_PLUGIN_CALLING_CONVENTION mumble_getDescription() {
    static const char desc[] = "Voice occlusion, proximity, and 3D spatial audio for Garry's Mod";
    return { desc, sizeof(desc) - 1, false };
}

MUMBLE_PLUGIN_EXPORT uint32_t MUMBLE_PLUGIN_CALLING_CONVENTION mumble_getFeatures() {
    return MUMBLE_FEATURE_AUDIO;
}

MUMBLE_PLUGIN_EXPORT uint32_t MUMBLE_PLUGIN_CALLING_CONVENTION mumble_deactivateFeatures(uint32_t) {
    return MUMBLE_FEATURE_NONE;
}

MUMBLE_PLUGIN_EXPORT uint8_t MUMBLE_PLUGIN_CALLING_CONVENTION mumble_initPositionalData(const char *const*, const uint64_t*, size_t) {
    return MUMBLE_PDEC_ERROR_PERM;
}

MUMBLE_PLUGIN_EXPORT bool MUMBLE_PLUGIN_CALLING_CONVENTION mumble_fetchPositionalData(float*, float*, float*, float*, float*, float*, const char**, const char**) {
    return false;
}

MUMBLE_PLUGIN_EXPORT void MUMBLE_PLUGIN_CALLING_CONVENTION mumble_shutdownPositionalData() {}

MUMBLE_PLUGIN_EXPORT struct MumbleStringWrapper MUMBLE_PLUGIN_CALLING_CONVENTION mumble_getPositionalDataContextPrefix() {
    static const char prefix[] = "immersivevoicechat";
    return { prefix, sizeof(prefix) - 1, false };
}

MUMBLE_PLUGIN_EXPORT void MUMBLE_PLUGIN_CALLING_CONVENTION mumble_onServerConnected(mumble_connection_t conn) {
    g_connection = conn;
}

MUMBLE_PLUGIN_EXPORT void MUMBLE_PLUGIN_CALLING_CONVENTION mumble_onServerDisconnected(mumble_connection_t) {
    g_connection = -1;
    g_userNames.clear();
}

MUMBLE_PLUGIN_EXPORT void MUMBLE_PLUGIN_CALLING_CONVENTION mumble_onServerSynchronized(mumble_connection_t conn) {
    g_connection = conn;
}

MUMBLE_PLUGIN_EXPORT void MUMBLE_PLUGIN_CALLING_CONVENTION mumble_onChannelEntered(mumble_connection_t, mumble_userid_t, mumble_channelid_t, mumble_channelid_t) {}
MUMBLE_PLUGIN_EXPORT void MUMBLE_PLUGIN_CALLING_CONVENTION mumble_onChannelExited(mumble_connection_t, mumble_userid_t, mumble_channelid_t) {}
MUMBLE_PLUGIN_EXPORT void MUMBLE_PLUGIN_CALLING_CONVENTION mumble_onUserTalkingStateChanged(mumble_connection_t, mumble_userid_t, mumble_talking_state_t) {}

MUMBLE_PLUGIN_EXPORT bool MUMBLE_PLUGIN_CALLING_CONVENTION mumble_onAudioInput(short*, uint32_t, uint16_t, uint32_t, bool) {
    return false;
}

MUMBLE_PLUGIN_EXPORT bool MUMBLE_PLUGIN_CALLING_CONVENTION
mumble_onAudioSourceFetched(float *outputPCM, uint32_t sampleCount, uint16_t channelCount, uint32_t sampleRate, bool isSpeech, mumble_userid_t userID) {
    // Allow reverb tail to decay even after speech stops
    bool hasReverbTail = false;
    auto revIt = g_reverb.find(0);
    if (revIt != g_reverb.end()) {
        hasReverbTail = revIt->second.lpfState[0] > 0.001f ||
                        revIt->second.lpfState[1] > 0.001f ||
                        revIt->second.lpfState[2] > 0.001f ||
                        revIt->second.lpfState[3] > 0.001f;
    }

    if (!isSpeech && !hasReverbTail) return false;
    if (!outputPCM || sampleCount == 0) return false;

    if (!g_sharedData && !OpenSharedMemory()) {
        return false;
    }
    if (g_sharedData->version != VO_SHARED_VERSION) {
        return false;
    }

    RefreshConnection();

    std::string userName = GetUserName(userID);
    if (userName.empty()) {
        return false;
    }

    g_userNames[userID] = userName;

    // If no speech and no reverb tail, skip
    if (!isSpeech) {
        // Still apply reverb decay on silence
        uint32_t total = sampleCount * channelCount;
        std::vector<float> silence(total, 0.0f);
        float indoor = 0.5f;
        ApplyReverb(silence.data(), sampleCount, channelCount, sampleRate, 0.5f, 150.0f, 0.5f);
        for (uint32_t i = 0; i < total; i++) {
            outputPCM[i] = silence[i];
        }
        return true;
    }

    // Check if shared memory is stale (server closed)
    DWORD now = GetTickCount();
    if (g_sharedData->tick != g_lastTick) {
        g_lastTick = g_sharedData->tick;
        g_lastUpdateTimeMs = now;
    }

    // If no updates for 30 seconds, server is likely gone (heartbeat keeps it alive at 500ms)
    if (now - g_lastUpdateTimeMs > 30000) {
        return false;
    }

    LookupResult info = LookupPlayer(userName.c_str());
    float occlusion = info.occlusion;
    float distance = info.distance;

    // --- Voice mode volume multiplier ---
    static const float VOICE_MODE_VOLUME[] = { 0.5f, 1.0f, 1.4f };
    static const float VOICE_MODE_CUTOFF_MULT[] = { 0.4f, 1.0f, 2.5f };
    uint32_t modeIdx = info.voiceMode;
    if (modeIdx > 2) modeIdx = 1;
    float modeVolume = VOICE_MODE_VOLUME[modeIdx];
    float modeCutoffMult = VOICE_MODE_CUTOFF_MULT[modeIdx];

    if (modeVolume < 1.0f) {
        uint32_t totalSamples = sampleCount * channelCount;
        for (uint32_t i = 0; i < totalSamples; i++) {
            outputPCM[i] *= modeVolume;
        }
    }

    // --- Skip filter entirely when audio is effectively clear ---
    if (occlusion < FILTER_BYPASS_THRESHOLD) {
        g_lastOcclusion[userID] = occlusion;
        g_currentCutoff[userID] = CLEAR_CUTOFF;
    } else {
        auto& filter = g_filters[userID];
        auto& lastOcc = g_lastOcclusion[userID];
        auto& curCutoff = g_currentCutoff[userID];

        // Steeper exponential curve: (1-t)^2 gives harsher wall muffling
        float t = occlusion;
        float norm = (1.0f - t) * (1.0f - t);
        float targetCutoff = OCCLUDED_CUTOFF + (CLEAR_CUTOFF - OCCLUDED_CUTOFF) * norm;
        targetCutoff *= modeCutoffMult;
        if (targetCutoff > CLEAR_CUTOFF) targetCutoff = CLEAR_CUTOFF;
        if (targetCutoff < 20.0f) targetCutoff = 20.0f;

        // Smooth cutoff transitions to prevent crackling
        if (curCutoff < 1.0f) curCutoff = targetCutoff;  // First time
        float lerpFactor = 0.15f;  // ~15% toward target per callback
        curCutoff = curCutoff + (targetCutoff - curCutoff) * lerpFactor;

        lastOcc = occlusion;

        filter.SetCutoff(curCutoff, (float)sampleRate);
        filter.ProcessBuffer(outputPCM, sampleCount, channelCount);
    }

    // --- Proximity volume (sqrt curve for smooth, natural fade) ---
    float distVolume = 1.0f;
    if (distance > PROXIMITY_MIN_DIST) {
        float t = (distance - PROXIMITY_MIN_DIST) / (PROXIMITY_MAX_DIST - PROXIMITY_MIN_DIST);
        if (t > 1.0f) t = 1.0f;
        distVolume = 1.0f - sqrtf(t);  // Sqrt: starts gentle, accelerates near end
        if (distVolume < 0.0f) distVolume = 0.0f;
    }

    // --- Elevation attenuation: sound from above/below is quieter ---
    if (g_sharedData) {
        float listenerZ = g_sharedData->listenerPosition[2];
        float speakerZ = info.position[2];
        float elevDiff = fabsf(speakerZ - listenerZ);
        // Every 128 units of height (~1 floor) reduces volume by ~15%
        float elevPenalty = elevDiff / 128.0f * 0.15f;
        if (elevPenalty > 0.6f) elevPenalty = 0.6f;  // Cap at 60% reduction
        distVolume *= (1.0f - elevPenalty);
    }

    if (distVolume < 1.0f) {
        uint32_t totalSamples = sampleCount * channelCount;
        for (uint32_t i = 0; i < totalSamples; i++) {
            outputPCM[i] *= distVolume;
        }
    }

    // --- 3D stereo panning ---
    if (channelCount >= 2) {
        float lx = g_sharedData->listenerPosition[0];
        float ly = g_sharedData->listenerPosition[1];
        float yaw = g_sharedData->listenerAngles[0];  // degrees, 0 = forward (+Y)

        float dx = info.position[0] - lx;
        float dy = info.position[1] - ly;

        float dist2D = sqrtf(dx * dx + dy * dy);
        if (dist2D > 1.0f) {
            float yawRad = yaw * PI / 180.0f;
            float rightX = sinf(yawRad);
            float rightY = -cosf(yawRad);

            float dotRight = (dx * rightX + dy * rightY) / dist2D;

            float pan = dotRight;
            if (pan < -1.0f) pan = -1.0f;
            if (pan > 1.0f) pan = 1.0f;

            ApplyStereoPanning(outputPCM, sampleCount, channelCount, pan);
        }
    }

    // --- Distance frequency rolloff: high frequencies drop off with distance ---
    if (distance > DIST_ROLLOFF_MIN_DIST) {
        auto& distFilter = g_distFilters[userID];
        auto& curDistCutoff = g_currentDistCutoff[userID];

        float t = (distance - DIST_ROLLOFF_MIN_DIST) / (DIST_ROLLOFF_MAX_DIST - DIST_ROLLOFF_MIN_DIST);
        if (t > 1.0f) t = 1.0f;
        // At close range: 15000Hz (full clarity), at max range: 2500Hz (bass-heavy muffled)
        float targetDistCutoff = 15000.0f - t * 12500.0f;

        if (curDistCutoff < 1.0f) curDistCutoff = targetDistCutoff;
        curDistCutoff = curDistCutoff + (targetDistCutoff - curDistCutoff) * 0.15f;

        distFilter.SetCutoff(curDistCutoff, (float)sampleRate);
        distFilter.ProcessBuffer(outputPCM, sampleCount, channelCount);
    } else {
        g_currentDistCutoff[userID] = 15000.0f;
    }

    // --- Doppler shift: pitch change based on relative velocity ---
    g_lastTick = g_sharedData ? g_sharedData->tick : g_lastTick;
    ApplyDopplerShift(outputPCM, sampleCount, channelCount, sampleRate, userID, info.position, info.velocity, g_lastTick);

    // --- Environmental reverb for indoor spaces ---
    float surfaceAbsorb = g_sharedData ? g_sharedData->listenerSurfaceAbsorb : 0.5f;
    ApplyReverb(outputPCM, sampleCount, channelCount, sampleRate, info.indoorAmount, info.roomSize, surfaceAbsorb);

    // --- Underwater audio effect ---
    bool speakerUnderwater = info.isUnderwater != 0;
    bool listenerUnderwater = g_sharedData && g_sharedData->listenerIsUnderwater != 0;
    if (speakerUnderwater || listenerUnderwater) {
        ApplyUnderwaterEffect(outputPCM, sampleCount, channelCount, sampleRate);
    }

    return true;
}

MUMBLE_PLUGIN_EXPORT bool MUMBLE_PLUGIN_CALLING_CONVENTION mumble_onAudioOutputAboutToPlay(float*, uint32_t, uint16_t, uint32_t) {
    return false;
}

MUMBLE_PLUGIN_EXPORT bool MUMBLE_PLUGIN_CALLING_CONVENTION mumble_onReceiveData(mumble_connection_t, mumble_userid_t, const uint8_t*, size_t, const char*) {
    return false;
}

MUMBLE_PLUGIN_EXPORT void MUMBLE_PLUGIN_CALLING_CONVENTION mumble_onUserAdded(mumble_connection_t, mumble_userid_t) {}

MUMBLE_PLUGIN_EXPORT void MUMBLE_PLUGIN_CALLING_CONVENTION mumble_onUserRemoved(mumble_connection_t, mumble_userid_t userID) {
    g_userNames.erase(userID);
    g_filters.erase(userID);
    g_distFilters.erase(userID);
    g_lastOcclusion.erase(userID);
    g_currentCutoff.erase(userID);
    g_currentDistCutoff.erase(userID);
    g_doppler.erase(userID);
}

MUMBLE_PLUGIN_EXPORT void MUMBLE_PLUGIN_CALLING_CONVENTION mumble_onChannelAdded(mumble_connection_t, mumble_channelid_t) {}
MUMBLE_PLUGIN_EXPORT void MUMBLE_PLUGIN_CALLING_CONVENTION mumble_onChannelRemoved(mumble_connection_t, mumble_channelid_t) {}
MUMBLE_PLUGIN_EXPORT void MUMBLE_PLUGIN_CALLING_CONVENTION mumble_onChannelRenamed(mumble_connection_t, mumble_channelid_t) {}
MUMBLE_PLUGIN_EXPORT void MUMBLE_PLUGIN_CALLING_CONVENTION mumble_onKeyEvent(uint32_t, bool) {}
MUMBLE_PLUGIN_EXPORT bool MUMBLE_PLUGIN_CALLING_CONVENTION mumble_hasUpdate() { return false; }

MUMBLE_PLUGIN_EXPORT struct MumbleStringWrapper MUMBLE_PLUGIN_CALLING_CONVENTION mumble_getUpdateDownloadURL() {
    static const char url[] = "";
    return { url, 0, false };
}

}
