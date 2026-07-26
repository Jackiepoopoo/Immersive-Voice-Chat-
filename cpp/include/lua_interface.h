#ifndef IMMERSIVE_VOICE_CHAT_LUA_INTERFACE_H
#define IMMERSIVE_VOICE_CHAT_LUA_INTERFACE_H

#include <GarrysMod/Lua/LuaBase.h>

namespace ImmersiveVoiceChat {

class LuaInterface
{
public:
    static bool Initialize();
    static void Shutdown();

private:
    static int Lua_SetOcclusion(lua_State* L);
    static int Lua_SetEnabled(lua_State* L);
    static int Lua_SetStrength(lua_State* L);
    static int Lua_GetOcclusion(lua_State* L);
    static int Lua_GetEnabled(lua_State* L);
    static int Lua_GetStrength(lua_State* L);
    static int Lua_GetVersion(lua_State* L);
    static int Lua_GetStatus(lua_State* L);
    static int Lua_SetPlayerOcclusion(lua_State* L);
    static int Lua_SetPlayerOcclusions(lua_State* L);
    static int Lua_ClearPlayers(lua_State* L);
    static int Lua_SetListenerPosition(lua_State* L);
};

}

#endif
