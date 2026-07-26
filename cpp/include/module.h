#ifndef IMMERSIVE_VOICE_CHAT_MODULE_H
#define IMMERSIVE_VOICE_CHAT_MODULE_H

#include <cstdio>
#include <GarrysMod/Lua/Interface.h>

#define IMMERSIVE_VOICE_CHAT_VERSION "1.0.0"
#define VO_PRINT(fmt, ...) printf("[ImmersiveVoiceChat] " fmt "\n", ##__VA_ARGS__)

extern GarrysMod::Lua::ILuaBase* g_Lua;

#endif
