-- Immersive Voice Chat Configuration
-- Default settings that can be overridden by server operators

ImmersiveVoiceChat.Config = {
    -- Occlusion detection
    MaxDistance = 1200,              -- Maximum voice range in Source units
    TraceInterval = 0.1,            -- How often to run tracelines (seconds)
    TraceMask = MASK_SOLID_BRUSHONLY, -- Trace mask for wall detection
    
    -- Proximity (distance-based volume)
    ProximityMinDist = 100,          -- Distance where volume starts fading (game units)
    ProximityMaxDist = 2000,         -- Distance where voice is silent
    
    -- Effect parameters
    MinOcclusion = 0.0,             -- Minimum occlusion value (clear line of sight)
    MaxOcclusion = 1.0,             -- Maximum occlusion value (fully blocked)
    WallPenalty = 0.65,             -- Base occlusion added per wall hit
    ThickWallBonus = 0.1,           -- Extra occlusion per unit of wall thickness beyond 2
    GlassPenalty = 0.15,            -- Occlusion added when trace hits glass (partial transparency)
    DoorPenalty = 0.05,             -- Occlusion added for closed doors (slight seal effect)
    
    -- Volume fallback (for players without binary module)
    EnableVolumeFallback = true,    -- Enable volume reduction for players without module
    FallbackMinVolume = 0.15,       -- Minimum volume when fully occluded (0-1)
    
    -- Advanced settings
    UsePhysicsTrace = false,        -- Use physics traces vs visibility traces
    HeadHeight = 64,               -- Height above player origin for trace (eye level)
    
    -- Performance
    MaxChecksPerTick = 50,          -- Maximum occlusion checks per server tick
    SkipFriendlyFire = false,       -- Skip occlusion checks for same-team players
    CloseRange = 300,               -- Full traces up to this distance
    MediumRange = 600,              -- Reduced traces up to this distance
    FarRange = 1200,                -- Minimal traces up to this distance
    IndoorCacheRadius = 128,        -- Reuse indoor result if player moved less than this
    IndoorCacheInterval = 1.0,      -- Re-evaluate indoor this often at minimum (seconds)
    DeltaThreshold = 0.02,          -- Only send updates when occlusion changes by more than this
    
    -- Debug
    DebugMode = false,              -- Enable debug output
    DrawDebugTraces = false,        -- Draw trace lines in-game (sv_cheats required)
    
    -- Radio / Walkie Talkie
    RadioMaxChannels = 9,           -- Number of radio channels
    RadioBandpassLow = 300,         -- Bandpass filter low cutoff (Hz)
    RadioBandpassHigh = 3000,       -- Bandpass filter high cutoff (Hz)
    RadioNoiseAmount = 0.12,        -- White noise mix amount (0-1)
    RadioSquelchClickDur = 0.06,    -- Squelch click duration (seconds)
    RadioReverbAmount = 0.15,       -- Room reverb simulation (0-1)
    
    -- Voice modes (0=Whisper, 1=Talk, 2=Yell)
    VoiceModes = {
        [0] = { -- Whisper
            maxDistMult = 0.33,
            occlusionMult = 1.3,
            volume = 0.5,
            cutoffMult = 0.4,
        },
        [1] = { -- Talk
            maxDistMult = 1.0,
            occlusionMult = 1.0,
            volume = 1.0,
            cutoffMult = 1.0,
        },
        [2] = { -- Yell
            maxDistMult = 2.0,
            occlusionMult = 0.7,
            volume = 1.4,
            cutoffMult = 2.5,
        },
    },
}

-- Console commands for configuration
if SERVER then
    concommand.Add("vo_maxdistance", function(ply, cmd, args)
        if not IsValid(ply) or ply:IsAdmin() then
            local val = tonumber(args[1])
            if val then
                ImmersiveVoiceChat.Config.MaxDistance = math.Clamp(val, 100, 5000)
                print("[ImmersiveVoiceChat] MaxDistance set to: " .. ImmersiveVoiceChat.Config.MaxDistance)
            end
        end
    end)
    
    concommand.Add("vo_traceinterval", function(ply, cmd, args)
        if not IsValid(ply) or ply:IsAdmin() then
            local val = tonumber(args[1])
            if val then
                ImmersiveVoiceChat.Config.TraceInterval = math.Clamp(val, 0.1, 2.0)
                print("[ImmersiveVoiceChat] TraceInterval set to: " .. ImmersiveVoiceChat.Config.TraceInterval)
            end
        end
    end)
    
    concommand.Add("vo_proximitymin", function(ply, cmd, args)
        if not IsValid(ply) or ply:IsAdmin() then
            local val = tonumber(args[1])
            if val then
                ImmersiveVoiceChat.Config.ProximityMinDist = math.Clamp(val, 10, 500)
                print("[ImmersiveVoiceChat] ProximityMinDist set to: " .. ImmersiveVoiceChat.Config.ProximityMinDist)
            end
        end
    end)

    concommand.Add("vo_proximitymax", function(ply, cmd, args)
        if not IsValid(ply) or ply:IsAdmin() then
            local val = tonumber(args[1])
            if val then
                ImmersiveVoiceChat.Config.ProximityMaxDist = math.Clamp(val, 200, 5000)
                print("[ImmersiveVoiceChat] ProximityMaxDist set to: " .. ImmersiveVoiceChat.Config.ProximityMaxDist)
            end
        end
    end)

    concommand.Add("vo_wallpenalty", function(ply, cmd, args)
        if not IsValid(ply) or ply:IsAdmin() then
            local val = tonumber(args[1])
            if val then
                ImmersiveVoiceChat.Config.WallPenalty = math.Clamp(val, 0, 1)
                print("[ImmersiveVoiceChat] WallPenalty set to: " .. ImmersiveVoiceChat.Config.WallPenalty)
            end
        end
    end)

    concommand.Add("vo_glasspenalty", function(ply, cmd, args)
        if not IsValid(ply) or ply:IsAdmin() then
            local val = tonumber(args[1])
            if val then
                ImmersiveVoiceChat.Config.GlassPenalty = math.Clamp(val, 0, 0.5)
                print("[ImmersiveVoiceChat] GlassPenalty set to: " .. ImmersiveVoiceChat.Config.GlassPenalty)
            end
        end
    end)

    concommand.Add("vo_thickwallbonus", function(ply, cmd, args)
        if not IsValid(ply) or ply:IsAdmin() then
            local val = tonumber(args[1])
            if val then
                ImmersiveVoiceChat.Config.ThickWallBonus = math.Clamp(val, 0, 0.5)
                print("[ImmersiveVoiceChat] ThickWallBonus set to: " .. ImmersiveVoiceChat.Config.ThickWallBonus)
            end
        end
    end)

    concommand.Add("vo_debug", function(ply, cmd, args)
        if not IsValid(ply) or ply:IsAdmin() then
            ImmersiveVoiceChat.Config.DebugMode = not ImmersiveVoiceChat.Config.DebugMode
            print("[ImmersiveVoiceChat] DebugMode: " .. tostring(ImmersiveVoiceChat.Config.DebugMode))
        end
    end)

    concommand.Add("vo_whisper_dist", function(ply, cmd, args)
        if not IsValid(ply) or ply:IsAdmin() then
            local val = tonumber(args[1])
            if val then
                ImmersiveVoiceChat.Config.VoiceModes[0].maxDistMult = math.Clamp(val, 0.1, 1.0)
                print("[ImmersiveVoiceChat] Whisper maxDistMult: " .. ImmersiveVoiceChat.Config.VoiceModes[0].maxDistMult)
            end
        end
    end)

    concommand.Add("vo_whisper_occ", function(ply, cmd, args)
        if not IsValid(ply) or ply:IsAdmin() then
            local val = tonumber(args[1])
            if val then
                ImmersiveVoiceChat.Config.VoiceModes[0].occlusionMult = math.Clamp(val, 0.1, 3.0)
                print("[ImmersiveVoiceChat] Whisper occlusionMult: " .. ImmersiveVoiceChat.Config.VoiceModes[0].occlusionMult)
            end
        end
    end)

    concommand.Add("vo_yell_dist", function(ply, cmd, args)
        if not IsValid(ply) or ply:IsAdmin() then
            local val = tonumber(args[1])
            if val then
                ImmersiveVoiceChat.Config.VoiceModes[2].maxDistMult = math.Clamp(val, 1.0, 5.0)
                print("[ImmersiveVoiceChat] Yell maxDistMult: " .. ImmersiveVoiceChat.Config.VoiceModes[2].maxDistMult)
            end
        end
    end)

    concommand.Add("vo_yell_occ", function(ply, cmd, args)
        if not IsValid(ply) or ply:IsAdmin() then
            local val = tonumber(args[1])
            if val then
                ImmersiveVoiceChat.Config.VoiceModes[2].occlusionMult = math.Clamp(val, 0.1, 2.0)
                print("[ImmersiveVoiceChat] Yell occlusionMult: " .. ImmersiveVoiceChat.Config.VoiceModes[2].occlusionMult)
            end
        end
    end)
end
