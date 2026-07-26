-- Voice Occlusion Server Hooks
-- Integrates with Garry's Mod voice system

-- Main voice control hook
hook.Add("PlayerCanHearPlayersVoice", "VoiceOcclusion_HearCheck", function(listener, talker)
    if not VoiceOcclusion.Config then
        return true, true
    end
    
    -- Check distance first
    local listenerPos = VoiceOcclusion.Utils.GetHeadPosition(listener)
    local talkerPos = VoiceOcclusion.Utils.GetHeadPosition(talker)
    
    if not listenerPos or not talkerPos then
        return true, true
    end
    
    local dist = VoiceOcclusion.Utils.GetDistance(listenerPos, talkerPos)
    
    -- Out of range - don't hear at all (use voice mode adjusted distance)
    local mode = VoiceOcclusion.Server.PlayerVoiceMode[talker:SteamID64()] or 1
    local modeData = VoiceOcclusion.Config.VoiceModes[mode] or VoiceOcclusion.Config.VoiceModes[1]
    local adjustedMaxDist = VoiceOcclusion.Config.MaxDistance * modeData.maxDistMult
    
    if dist > adjustedMaxDist then
        return false
    end
    
    -- Calculate occlusion for 3D positioning
    local occlusion = VoiceOcclusion.Server:CalculateOcclusion(talker, listener)
    
    -- Fully occluded - check if volume fallback is enabled
    -- But NOT for distance-based occlusion: if beyond base MaxDistance, always block
    if occlusion and occlusion >= VoiceOcclusion.Config.MaxOcclusion then
        if dist <= VoiceOcclusion.Config.MaxDistance and VoiceOcclusion.Config.EnableVolumeFallback then
            -- Wall-based occlusion with fallback: hear but no 3D
            return true, false
        else
            -- Distance-based or fallback disabled: don't hear at all
            return false
        end
    end
    
    -- Partial or no occlusion - use 3D voice for distance falloff
    -- Binary module will handle the actual muffling on client side
    return true, true
end)

-- Handle player spawning - reset their state
hook.Add("PlayerSpawn", "VoiceOcclusion_PlayerSpawn", function(ply)
    if IsValid(ply) then
        local plyID = ply:SteamID64()
        VoiceOcclusion.Server.PlayerState[plyID] = {}
    end
end)

-- Handle player disconnect
hook.Add("PlayerDisconnected", "VoiceOcclusion_PlayerDisconnect", function(ply)
    if IsValid(ply) then
        VoiceOcclusion.Server:PlayerDisconnected(ply)
    end
end)

-- Receive voice mode from clients
net.Receive("vo_voice_mode", function(len, ply)
    if IsValid(ply) then
        local mode = net.ReadUInt(2)
        mode = math.Clamp(mode, 0, 2)
        VoiceOcclusion.Server.PlayerVoiceMode[ply:SteamID64()] = mode
        VoiceOcclusion.Utils.DebugPrint(
            VoiceOcclusion.Utils.PlayerName(ply) .. " voice mode: " .. mode
        )
    end
end)

-- Think hook for processing occlusion
hook.Add("Think", "VoiceOcclusion_Think", function()
    VoiceOcclusion.Server:ProcessTick()
end)

-- Request sync from client
net.Receive("vo_request_sync", function(len, ply)
    if IsValid(ply) then
        -- Send current config to client
        net.Start("vo_config_sync")
            net.WriteUInt(VoiceOcclusion.Config.MaxDistance, 16)
            net.WriteFloat(VoiceOcclusion.Config.FallbackMinVolume)
            net.WriteBit(VoiceOcclusion.Config.EnableVolumeFallback)
        net.Send(ply)
    end
end)

-- Client reporting module status
net.Receive("vo_module_status", function(len, ply)
    if IsValid(ply) then
        local hasModule = net.ReadBit() == 1
        VoiceOcclusion.Utils.DebugPrint(
            VoiceOcclusion.Utils.PlayerName(ply) .. 
            " module status: " .. tostring(hasModule)
        )
    end
end)

-- Admin commands
concommand.Add("vo_status", function(ply, cmd, args)
    if not IsValid(ply) or ply:IsAdmin() then
        print("=== Voice Occlusion Status ===")
        print("Version: " .. VoiceOcclusion.Version)
        print("Active Players: " .. #player.GetAll())
        
        local speakingCount = 0
        for _, ply in ipairs(player.GetAll()) do
            if ply:IsSpeaking() then
                speakingCount = speakingCount + 1
            end
        end
        print("Currently Speaking: " .. speakingCount)
        
        print("\nPlayer States:")
        for listenerID, states in pairs(VoiceOcclusion.Server.PlayerState) do
            for speakerID, occlusion in pairs(states) do
                print("  " .. listenerID .. " <- " .. speakerID .. ": " .. 
                      string.format("%.2f", occlusion))
            end
        end
        
        print("\nConfig:")
        print("  MaxDistance: " .. VoiceOcclusion.Config.MaxDistance)
        print("  TraceInterval: " .. VoiceOcclusion.Config.TraceInterval)
        print("  WallPenalty: " .. VoiceOcclusion.Config.WallPenalty)
        print("  EnableVolumeFallback: " .. tostring(VoiceOcclusion.Config.EnableVolumeFallback))
    end
end)

concommand.Add("vo_config", function(ply, cmd, args)
    if not IsValid(ply) or ply:IsAdmin() then
        print("=== Voice Occlusion Config ===")
        for k, v in pairs(VoiceOcclusion.Config) do
            print("  " .. k .. ": " .. tostring(v))
        end
    end
end)
