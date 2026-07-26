-- Voice Occlusion Configuration
-- Default settings that can be overridden by server operators

VoiceOcclusion.Config = {
    -- Occlusion detection
    MaxDistance = 1200,              -- Maximum voice range in Source units
    TraceInterval = 0.3,            -- How often to run tracelines (seconds)
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
    DeltaThreshold = 0.05,          -- Only send updates when occlusion changes by more than this
    
    -- Debug
    DebugMode = false,              -- Enable debug output
    DrawDebugTraces = false,        -- Draw trace lines in-game (sv_cheats required)
    
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
                VoiceOcclusion.Config.MaxDistance = math.Clamp(val, 100, 5000)
                print("[VoiceOcclusion] MaxDistance set to: " .. VoiceOcclusion.Config.MaxDistance)
            end
        end
    end)
    
    concommand.Add("vo_traceinterval", function(ply, cmd, args)
        if not IsValid(ply) or ply:IsAdmin() then
            local val = tonumber(args[1])
            if val then
                VoiceOcclusion.Config.TraceInterval = math.Clamp(val, 0.1, 2.0)
                print("[VoiceOcclusion] TraceInterval set to: " .. VoiceOcclusion.Config.TraceInterval)
            end
        end
    end)
    
    concommand.Add("vo_proximitymin", function(ply, cmd, args)
        if not IsValid(ply) or ply:IsAdmin() then
            local val = tonumber(args[1])
            if val then
                VoiceOcclusion.Config.ProximityMinDist = math.Clamp(val, 10, 500)
                print("[VoiceOcclusion] ProximityMinDist set to: " .. VoiceOcclusion.Config.ProximityMinDist)
            end
        end
    end)

    concommand.Add("vo_proximitymax", function(ply, cmd, args)
        if not IsValid(ply) or ply:IsAdmin() then
            local val = tonumber(args[1])
            if val then
                VoiceOcclusion.Config.ProximityMaxDist = math.Clamp(val, 200, 5000)
                print("[VoiceOcclusion] ProximityMaxDist set to: " .. VoiceOcclusion.Config.ProximityMaxDist)
            end
        end
    end)

    concommand.Add("vo_wallpenalty", function(ply, cmd, args)
        if not IsValid(ply) or ply:IsAdmin() then
            local val = tonumber(args[1])
            if val then
                VoiceOcclusion.Config.WallPenalty = math.Clamp(val, 0, 1)
                print("[VoiceOcclusion] WallPenalty set to: " .. VoiceOcclusion.Config.WallPenalty)
            end
        end
    end)

    concommand.Add("vo_glasspenalty", function(ply, cmd, args)
        if not IsValid(ply) or ply:IsAdmin() then
            local val = tonumber(args[1])
            if val then
                VoiceOcclusion.Config.GlassPenalty = math.Clamp(val, 0, 0.5)
                print("[VoiceOcclusion] GlassPenalty set to: " .. VoiceOcclusion.Config.GlassPenalty)
            end
        end
    end)

    concommand.Add("vo_thickwallbonus", function(ply, cmd, args)
        if not IsValid(ply) or ply:IsAdmin() then
            local val = tonumber(args[1])
            if val then
                VoiceOcclusion.Config.ThickWallBonus = math.Clamp(val, 0, 0.5)
                print("[VoiceOcclusion] ThickWallBonus set to: " .. VoiceOcclusion.Config.ThickWallBonus)
            end
        end
    end)

    concommand.Add("vo_debug", function(ply, cmd, args)
        if not IsValid(ply) or ply:IsAdmin() then
            VoiceOcclusion.Config.DebugMode = not VoiceOcclusion.Config.DebugMode
            print("[VoiceOcclusion] DebugMode: " .. tostring(VoiceOcclusion.Config.DebugMode))
        end
    end)

    concommand.Add("vo_whisper_dist", function(ply, cmd, args)
        if not IsValid(ply) or ply:IsAdmin() then
            local val = tonumber(args[1])
            if val then
                VoiceOcclusion.Config.VoiceModes[0].maxDistMult = math.Clamp(val, 0.1, 1.0)
                print("[VoiceOcclusion] Whisper maxDistMult: " .. VoiceOcclusion.Config.VoiceModes[0].maxDistMult)
            end
        end
    end)

    concommand.Add("vo_whisper_occ", function(ply, cmd, args)
        if not IsValid(ply) or ply:IsAdmin() then
            local val = tonumber(args[1])
            if val then
                VoiceOcclusion.Config.VoiceModes[0].occlusionMult = math.Clamp(val, 0.1, 3.0)
                print("[VoiceOcclusion] Whisper occlusionMult: " .. VoiceOcclusion.Config.VoiceModes[0].occlusionMult)
            end
        end
    end)

    concommand.Add("vo_yell_dist", function(ply, cmd, args)
        if not IsValid(ply) or ply:IsAdmin() then
            local val = tonumber(args[1])
            if val then
                VoiceOcclusion.Config.VoiceModes[2].maxDistMult = math.Clamp(val, 1.0, 5.0)
                print("[VoiceOcclusion] Yell maxDistMult: " .. VoiceOcclusion.Config.VoiceModes[2].maxDistMult)
            end
        end
    end)

    concommand.Add("vo_yell_occ", function(ply, cmd, args)
        if not IsValid(ply) or ply:IsAdmin() then
            local val = tonumber(args[1])
            if val then
                VoiceOcclusion.Config.VoiceModes[2].occlusionMult = math.Clamp(val, 0.1, 2.0)
                print("[VoiceOcclusion] Yell occlusionMult: " .. VoiceOcclusion.Config.VoiceModes[2].occlusionMult)
            end
        end
    end)
end
