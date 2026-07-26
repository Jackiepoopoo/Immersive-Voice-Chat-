#ifndef VOICE_OCCLUSION_MODULE_H
#define VOICE_OCCLUSION_MODULE_H

#include <cstdio>
#include <GarrysMod/Lua/Interface.h>

#define VOICE_OCCLUSION_VERSION "1.0.0"
#define VO_PRINT(fmt, ...) printf("[VoiceOcclusion] " fmt "\n", ##__VA_ARGS__)

extern GarrysMod::Lua::ILuaBase* g_Lua;

#endif
