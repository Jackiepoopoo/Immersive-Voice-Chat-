-- Voice Occlusion System
-- Shared loader that initializes the addon on both client and server

VoiceOcclusion = VoiceOcclusion or {}
VoiceOcclusion.Version = "1.0.0"

-- Load shared config first
include("voiceocclusion/config.lua")

if SERVER then
    AddCSLuaFile("voiceocclusion/config.lua")
    AddCSLuaFile("voiceocclusion/shared.lua")
    AddCSLuaFile("voiceocclusion/client/main.lua")
    AddCSLuaFile("voiceocclusion/client/cl_module.lua")
    
    include("voiceocclusion/shared.lua")
    include("voiceocclusion/server/main.lua")
    include("voiceocclusion/server/hooks.lua")
    
    -- Register net strings
    util.AddNetworkString("vo_occlusion_update")
    util.AddNetworkString("vo_config_sync")
    util.AddNetworkString("vo_request_sync")
    util.AddNetworkString("vo_module_status")
    util.AddNetworkString("vo_voice_mode")
    
    print("[VoiceOcclusion] Server-side loaded (v" .. VoiceOcclusion.Version .. ")")
end

if CLIENT then
    include("voiceocclusion/shared.lua")
    include("voiceocclusion/client/main.lua")
    include("voiceocclusion/client/cl_module.lua")
    
    print("[VoiceOcclusion] Client-side loaded (v" .. VoiceOcclusion.Version .. ")")
end
