#include "module.h"
#include "audio_processor.h"
#include "lua_interface.h"
#include <windows.h>
#include <cstring>
#include <cstdint>

#define VO_SHARED_MEMORY_NAME "VoiceOcclusionData"
#define VO_MAX_PLAYERS 64
#define VO_MAX_NAME 64
#define VO_SHARED_VERSION 8

struct VOPlayerData {
    char name[VO_MAX_NAME];
    float occlusion;
    float distance;
    float position[3];
    float velocity[3];
    float indoorAmount;
    float roomSize;
    uint32_t isUnderwater;
    uint32_t voiceMode;
};

struct VOSharedData {
    uint32_t version;
    uint32_t tick;
    uint32_t playerCount;
    float listenerPosition[3];
    float listenerAngles[3];
    float listenerIndoorAmount;
    float listenerRoomSize;
    float listenerSurfaceAbsorb;
    uint32_t listenerIsUnderwater;
    VOPlayerData players[VO_MAX_PLAYERS];
};

GarrysMod::Lua::ILuaBase* g_Lua = nullptr;
static HANDLE g_hSharedMap = nullptr;
static VOSharedData* g_pSharedData = nullptr;

void VO_InitSharedMemory()
{
    g_hSharedMap = CreateFileMappingA(
        INVALID_HANDLE_VALUE, NULL, PAGE_READWRITE,
        0, sizeof(VOSharedData), VO_SHARED_MEMORY_NAME);

    if (g_hSharedMap)
    {
        g_pSharedData = (VOSharedData*)MapViewOfFile(g_hSharedMap, FILE_MAP_ALL_ACCESS, 0, 0, sizeof(VOSharedData));
        if (g_pSharedData)
        {
            memset(g_pSharedData, 0, sizeof(VOSharedData));
            g_pSharedData->version = VO_SHARED_VERSION;
            VO_PRINT("Shared memory created");
        }
    }
}

void VO_ShutdownSharedMemory()
{
    if (g_pSharedData) {
        g_pSharedData->playerCount = 0;
        g_pSharedData->tick++;
    }
    if (g_pSharedData) { UnmapViewOfFile(g_pSharedData); g_pSharedData = nullptr; }
    if (g_hSharedMap) { CloseHandle(g_hSharedMap); g_hSharedMap = nullptr; }
}

void VO_SetPlayerOcclusion(const char* name, float level, float distance, float x, float y, float z, float vx, float vy, float vz, float indoor, float room, uint32_t underwater, uint32_t voiceMode)
{
    if (!g_pSharedData || !name) return;

    for (uint32_t i = 0; i < g_pSharedData->playerCount && i < VO_MAX_PLAYERS; i++)
    {
        if (_stricmp(g_pSharedData->players[i].name, name) == 0)
        {
            g_pSharedData->players[i].occlusion = level;
            g_pSharedData->players[i].distance = distance;
            g_pSharedData->players[i].position[0] = x;
            g_pSharedData->players[i].position[1] = y;
            g_pSharedData->players[i].position[2] = z;
            g_pSharedData->players[i].velocity[0] = vx;
            g_pSharedData->players[i].velocity[1] = vy;
            g_pSharedData->players[i].velocity[2] = vz;
            g_pSharedData->players[i].indoorAmount = indoor;
            g_pSharedData->players[i].roomSize = room;
            g_pSharedData->players[i].isUnderwater = underwater;
            g_pSharedData->players[i].voiceMode = voiceMode;
            g_pSharedData->tick++;
            return;
        }
    }

    if (g_pSharedData->playerCount < VO_MAX_PLAYERS)
    {
        uint32_t idx = g_pSharedData->playerCount++;
        strncpy_s(g_pSharedData->players[idx].name, VO_MAX_NAME, name, _TRUNCATE);
        g_pSharedData->players[idx].occlusion = level;
        g_pSharedData->players[idx].distance = distance;
        g_pSharedData->players[idx].position[0] = x;
        g_pSharedData->players[idx].position[1] = y;
        g_pSharedData->players[idx].position[2] = z;
        g_pSharedData->players[idx].velocity[0] = vx;
        g_pSharedData->players[idx].velocity[1] = vy;
        g_pSharedData->players[idx].velocity[2] = vz;
        g_pSharedData->players[idx].indoorAmount = indoor;
        g_pSharedData->players[idx].roomSize = room;
        g_pSharedData->players[idx].isUnderwater = underwater;
        g_pSharedData->players[idx].voiceMode = voiceMode;
        g_pSharedData->tick++;
    }
}

void VO_SetListenerPosition(float x, float y, float z, float yaw, float pitch, float roll, float indoor, float room, float surfaceAbsorb, uint32_t underwater)
{
    if (!g_pSharedData) return;
    g_pSharedData->listenerPosition[0] = x;
    g_pSharedData->listenerPosition[1] = y;
    g_pSharedData->listenerPosition[2] = z;
    g_pSharedData->listenerAngles[0] = yaw;
    g_pSharedData->listenerAngles[1] = pitch;
    g_pSharedData->listenerAngles[2] = roll;
    g_pSharedData->listenerIndoorAmount = indoor;
    g_pSharedData->listenerRoomSize = room;
    g_pSharedData->listenerSurfaceAbsorb = surfaceAbsorb;
    g_pSharedData->listenerIsUnderwater = underwater;
}

void VO_ClearPlayerOcclusion()
{
    if (!g_pSharedData) return;
    g_pSharedData->playerCount = 0;
    g_pSharedData->tick++;
}

GMOD_MODULE_OPEN()
{
    g_Lua = LUA;

    VO_InitSharedMemory();

    if (!VoiceOcclusion::LuaInterface::Initialize())
    {
        g_Lua->ThrowError("Failed to initialize Lua interface");
        return 0;
    }

    if (!VoiceOcclusion::AudioProcessor::Initialize())
    {
        g_Lua->ThrowError("Failed to initialize audio processor");
        return 0;
    }

    VO_PRINT("Module loaded successfully");
    return 0;
}

GMOD_MODULE_CLOSE()
{
    VoiceOcclusion::AudioProcessor::Shutdown();
    VoiceOcclusion::LuaInterface::Shutdown();
    VO_ShutdownSharedMemory();
    g_Lua = nullptr;

    VO_PRINT("Module unloaded");
    return 0;
}
