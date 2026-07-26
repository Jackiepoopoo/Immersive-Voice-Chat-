#ifndef IMMERSIVE_VOICE_CHAT_SHARED_MEMORY_H
#define IMMERSIVE_VOICE_CHAT_SHARED_MEMORY_H

#include <stdint.h>

#define VO_SHARED_MEMORY_NAME "ImmersiveVoiceChatData"
#define VO_MAX_PLAYERS 64
#define VO_MAX_NAME 64
#define VO_SHARED_VERSION 9

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
    uint32_t isRadio;
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

#endif
