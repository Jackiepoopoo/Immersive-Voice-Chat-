-- Immersive Voice Chat
-- Shared loader that initializes the addon on both client and server

ImmersiveVoiceChat = ImmersiveVoiceChat or {}
ImmersiveVoiceChat.Version = "1.0.0"

-- Load shared config first
include("immersivevoicechat/config.lua")

if SERVER then
    AddCSLuaFile("immersivevoicechat/config.lua")
    AddCSLuaFile("immersivevoicechat/shared.lua")
    AddCSLuaFile("immersivevoicechat/client/main.lua")
    AddCSLuaFile("immersivevoicechat/client/cl_module.lua")
    AddCSLuaFile("weapons/weapon_radio/shared.lua")
    AddCSLuaFile("weapons/weapon_radio/cl_init.lua")
    
    include("immersivevoicechat/shared.lua")
    include("immersivevoicechat/server/main.lua")
    include("immersivevoicechat/server/hooks.lua")
    
    -- Register net strings
    util.AddNetworkString("vo_occlusion_update")
    util.AddNetworkString("vo_config_sync")
    util.AddNetworkString("vo_request_sync")
    util.AddNetworkString("vo_module_status")
    util.AddNetworkString("vo_voice_mode")
    util.AddNetworkString("vo_radio_transmit")
    
    print("[ImmersiveVoiceChat] Server-side loaded (v" .. ImmersiveVoiceChat.Version .. ")")
end

if CLIENT then
    include("immersivevoicechat/shared.lua")
    include("immersivevoicechat/client/main.lua")
    include("immersivevoicechat/client/cl_module.lua")
    
    print("[ImmersiveVoiceChat] Client-side loaded (v" .. ImmersiveVoiceChat.Version .. ")")
end
