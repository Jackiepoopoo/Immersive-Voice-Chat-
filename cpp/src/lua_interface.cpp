#include "lua_interface.h"
#include "audio_processor.h"
#include "module.h"
#include <cstdint>

extern void VO_SetPlayerOcclusion(const char* name, float level, float distance, float x, float y, float z, float vx, float vy, float vz, float indoor, float room, uint32_t underwater, uint32_t voiceMode, uint32_t isRadio);
extern void VO_SetListenerPosition(float x, float y, float z, float yaw, float pitch, float roll, float indoor, float room, float surfaceAbsorb, uint32_t underwater);
extern void VO_ClearPlayerOcclusion();

namespace ImmersiveVoiceChat {

bool LuaInterface::Initialize()
{
    g_Lua->PushSpecial(GarrysMod::Lua::SPECIAL_GLOB);
    g_Lua->CreateTable();

    g_Lua->PushCFunction(Lua_SetOcclusion);
    g_Lua->SetField(-2, "SetOcclusion");

    g_Lua->PushCFunction(Lua_SetEnabled);
    g_Lua->SetField(-2, "SetEnabled");

    g_Lua->PushCFunction(Lua_SetStrength);
    g_Lua->SetField(-2, "SetStrength");

    g_Lua->PushCFunction(Lua_GetOcclusion);
    g_Lua->SetField(-2, "GetOcclusion");

    g_Lua->PushCFunction(Lua_GetEnabled);
    g_Lua->SetField(-2, "GetEnabled");

    g_Lua->PushCFunction(Lua_GetStrength);
    g_Lua->SetField(-2, "GetStrength");

    g_Lua->PushCFunction(Lua_GetVersion);
    g_Lua->SetField(-2, "GetVersion");

    g_Lua->PushCFunction(Lua_GetStatus);
    g_Lua->SetField(-2, "GetStatus");

    g_Lua->PushCFunction(Lua_SetPlayerOcclusion);
    g_Lua->SetField(-2, "SetPlayerOcclusion");

    g_Lua->PushCFunction(Lua_SetPlayerOcclusions);
    g_Lua->SetField(-2, "SetPlayerOcclusions");

    g_Lua->PushCFunction(Lua_ClearPlayers);
    g_Lua->SetField(-2, "ClearPlayers");

    g_Lua->PushCFunction(Lua_SetListenerPosition);
    g_Lua->SetField(-2, "SetListenerPosition");

    g_Lua->SetField(-2, "immersivevoicechat");
    g_Lua->Pop(1);

    VO_PRINT("Lua interface initialized");
    return true;
}

void LuaInterface::Shutdown()
{
    VO_PRINT("Lua interface shutdown");
}

int LuaInterface::Lua_SetOcclusion(lua_State* L)
{
    float level = g_Lua->GetNumber(1);
    AudioProcessor::GetInstance()->SetOcclusionLevel(level);
    return 0;
}

int LuaInterface::Lua_SetEnabled(lua_State* L)
{
    bool enabled = g_Lua->GetBool(1);
    AudioProcessor::GetInstance()->SetEnabled(enabled);
    return 0;
}

int LuaInterface::Lua_SetStrength(lua_State* L)
{
    float strength = g_Lua->GetNumber(1);
    AudioProcessor::GetInstance()->SetStrength(strength);
    return 0;
}

int LuaInterface::Lua_GetOcclusion(lua_State* L)
{
    g_Lua->PushNumber(AudioProcessor::GetInstance()->GetOcclusionLevel());
    return 1;
}

int LuaInterface::Lua_GetEnabled(lua_State* L)
{
    g_Lua->PushBool(AudioProcessor::GetInstance()->IsEnabled());
    return 1;
}

int LuaInterface::Lua_GetStrength(lua_State* L)
{
    g_Lua->PushNumber(AudioProcessor::GetInstance()->GetStrength());
    return 1;
}

int LuaInterface::Lua_GetVersion(lua_State* L)
{
    g_Lua->PushString(IMMERSIVE_VOICE_CHAT_VERSION);
    return 1;
}

int LuaInterface::Lua_GetStatus(lua_State* L)
{
    g_Lua->CreateTable();

    g_Lua->PushBool(AudioProcessor::GetInstance() != nullptr);
    g_Lua->SetField(-2, "initialized");

    if (AudioProcessor::GetInstance())
    {
        g_Lua->PushNumber(AudioProcessor::GetInstance()->GetOcclusionLevel());
        g_Lua->SetField(-2, "occlusion");

        g_Lua->PushBool(AudioProcessor::GetInstance()->IsEnabled());
        g_Lua->SetField(-2, "enabled");

        g_Lua->PushNumber(AudioProcessor::GetInstance()->GetStrength());
        g_Lua->SetField(-2, "strength");
    }

    g_Lua->PushString(IMMERSIVE_VOICE_CHAT_VERSION);
    g_Lua->SetField(-2, "version");

    return 1;
}

int LuaInterface::Lua_SetPlayerOcclusion(lua_State* L)
{
    const char* name = g_Lua->GetString(1);
    float level = (float)g_Lua->GetNumber(2);
    float distance = (float)g_Lua->GetNumber(3);
    float x = (float)g_Lua->GetNumber(4);
    float y = (float)g_Lua->GetNumber(5);
    float z = (float)g_Lua->GetNumber(6);
    float vx = (float)g_Lua->GetNumber(7);
    float vy = (float)g_Lua->GetNumber(8);
    float vz = (float)g_Lua->GetNumber(9);
    float indoor = (float)g_Lua->GetNumber(10);
    float room = (float)g_Lua->GetNumber(11);
    uint32_t underwater = (uint32_t)g_Lua->GetNumber(12);
    uint32_t voiceMode = (uint32_t)g_Lua->GetNumber(13);
    uint32_t isRadio = (uint32_t)g_Lua->GetNumber(14);
    if (name)
    {
        VO_SetPlayerOcclusion(name, level, distance, x, y, z, vx, vy, vz, indoor, room, underwater, voiceMode, isRadio);
    }
    return 0;
}

int LuaInterface::Lua_SetListenerPosition(lua_State* L)
{
    float x = (float)g_Lua->GetNumber(1);
    float y = (float)g_Lua->GetNumber(2);
    float z = (float)g_Lua->GetNumber(3);
    float yaw = (float)g_Lua->GetNumber(4);
    float pitch = (float)g_Lua->GetNumber(5);
    float roll = (float)g_Lua->GetNumber(6);
    float indoor = (float)g_Lua->GetNumber(7);
    float room = (float)g_Lua->GetNumber(8);
    float surfaceAbsorb = (float)g_Lua->GetNumber(9);
    uint32_t underwater = (uint32_t)g_Lua->GetNumber(10);
    VO_SetListenerPosition(x, y, z, yaw, pitch, roll, indoor, room, surfaceAbsorb, underwater);
    return 0;
}

int LuaInterface::Lua_SetPlayerOcclusions(lua_State* L)
{
    VO_ClearPlayerOcclusion();

    if (g_Lua->IsType(1, GarrysMod::Lua::Type::TABLE))
    {
        g_Lua->Push(1);
        g_Lua->PushNil();

        while (g_Lua->Next(-2))
        {
            if (g_Lua->IsType(-2, GarrysMod::Lua::Type::STRING))
            {
                const char* name = g_Lua->GetString(-2);
                float level = 0.0f;
                float distance = 0.0f;
                float px = 0.0f, py = 0.0f, pz = 0.0f;
                float vx = 0.0f, vy = 0.0f, vz = 0.0f;
                float indoor = 0.0f;
                float room = 0.0f;
                uint32_t underwater = 0;
                uint32_t voiceMode = 1;
                uint32_t isRadio = 0;

                if (g_Lua->IsType(-1, GarrysMod::Lua::Type::TABLE))
                {
                    g_Lua->Push(-1);

                    g_Lua->PushNumber(1);
                    g_Lua->GetTable(-2);
                    level = (float)g_Lua->GetNumber(-1);
                    g_Lua->Pop(1);

                    g_Lua->PushNumber(2);
                    g_Lua->GetTable(-2);
                    distance = (float)g_Lua->GetNumber(-1);
                    g_Lua->Pop(1);

                    g_Lua->PushNumber(3);
                    g_Lua->GetTable(-2);
                    px = (float)g_Lua->GetNumber(-1);
                    g_Lua->Pop(1);

                    g_Lua->PushNumber(4);
                    g_Lua->GetTable(-2);
                    py = (float)g_Lua->GetNumber(-1);
                    g_Lua->Pop(1);

                    g_Lua->PushNumber(5);
                    g_Lua->GetTable(-2);
                    pz = (float)g_Lua->GetNumber(-1);
                    g_Lua->Pop(1);

                    g_Lua->PushNumber(6);
                    g_Lua->GetTable(-2);
                    vx = (float)g_Lua->GetNumber(-1);
                    g_Lua->Pop(1);

                    g_Lua->PushNumber(7);
                    g_Lua->GetTable(-2);
                    vy = (float)g_Lua->GetNumber(-1);
                    g_Lua->Pop(1);

                    g_Lua->PushNumber(8);
                    g_Lua->GetTable(-2);
                    vz = (float)g_Lua->GetNumber(-1);
                    g_Lua->Pop(1);

                    g_Lua->PushNumber(9);
                    g_Lua->GetTable(-2);
                    indoor = (float)g_Lua->GetNumber(-1);
                    g_Lua->Pop(1);

                    g_Lua->PushNumber(10);
                    g_Lua->GetTable(-2);
                    room = (float)g_Lua->GetNumber(-1);
                    g_Lua->Pop(1);

                    g_Lua->PushNumber(11);
                    g_Lua->GetTable(-2);
                    underwater = (uint32_t)g_Lua->GetNumber(-1);
                    g_Lua->Pop(1);

                    g_Lua->PushNumber(12);
                    g_Lua->GetTable(-2);
                    voiceMode = (uint32_t)g_Lua->GetNumber(-1);
                    g_Lua->Pop(1);

                    g_Lua->PushNumber(13);
                    g_Lua->GetTable(-2);
                    isRadio = (uint32_t)g_Lua->GetNumber(-1);
                    g_Lua->Pop(1);

                    g_Lua->Pop(1);
                }
                else
                {
                    level = (float)g_Lua->GetNumber(-1);
                }

                VO_SetPlayerOcclusion(name, level, distance, px, py, pz, vx, vy, vz, indoor, room, underwater, voiceMode, isRadio);
            }
            g_Lua->Pop(1);
        }
        g_Lua->Pop(1);
    }
    return 0;
}

int LuaInterface::Lua_ClearPlayers(lua_State* L)
{
    VO_ClearPlayerOcclusion();
    return 0;
}

}
