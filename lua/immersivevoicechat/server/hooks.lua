-- Immersive Voice Chat Server Hooks
-- Integrates with Garry's Mod voice system

-- Check if listener is holding weapon_radio on the same channel as the speaker's radio
local function ListenerHasRadioOnChannel(listener, channel)
    if not IsValid(listener) then return false end
    local listenerID = listener:SteamID64()
    local listenerChannel = ImmersiveVoiceChat.Server.PlayerRadioChannel[listenerID]
    if listenerChannel and listenerChannel == channel then
        return true
    end
    return false
end

-- Main voice control hook
hook.Add("PlayerCanHearPlayersVoice", "ImmersiveVoiceChat_HearCheck", function(listener, talker)
    if not ImmersiveVoiceChat.Config then
        return true, true
    end
    
    local talkerID = talker:SteamID64()
    local radioData = ImmersiveVoiceChat.Server.PlayerRadio[talkerID]
    local speakerOnRadio = radioData and radioData.active

    -- Check distance first
    local listenerPos = ImmersiveVoiceChat.Utils.GetHeadPosition(listener)
    local talkerPos = ImmersiveVoiceChat.Utils.GetHeadPosition(talker)
    
    if not listenerPos or not talkerPos then
        return true, true
    end
    
    local dist = ImmersiveVoiceChat.Utils.GetDistance(listenerPos, talkerPos)
    
    -- Out of range - don't hear at all (use voice mode adjusted distance)
    local mode = ImmersiveVoiceChat.Server.PlayerVoiceMode[talkerID] or 1
    local modeData = ImmersiveVoiceChat.Config.VoiceModes[mode] or ImmersiveVoiceChat.Config.VoiceModes[1]
    local adjustedMaxDist = ImmersiveVoiceChat.Config.MaxDistance * modeData.maxDistMult

    -- Radio bypass: if speaker is transmitting on radio and listener has radio on same channel
    if speakerOnRadio and ListenerHasRadioOnChannel(listener, radioData.channel) then
        return true, true
    end

    if dist > adjustedMaxDist then
        return false
    end
    
    -- Calculate occlusion for 3D positioning
    local occlusion = ImmersiveVoiceChat.Server:CalculateOcclusion(talker, listener)
    
    -- Fully occluded - check if volume fallback is enabled
    -- But NOT for distance-based occlusion: if beyond mode-adjusted MaxDistance, always block
    if occlusion and occlusion >= ImmersiveVoiceChat.Config.MaxOcclusion then
        if dist <= adjustedMaxDist and ImmersiveVoiceChat.Config.EnableVolumeFallback then
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
hook.Add("PlayerSpawn", "ImmersiveVoiceChat_PlayerSpawn", function(ply)
    if IsValid(ply) then
        local plyID = ply:SteamID64()
        ImmersiveVoiceChat.Server.PlayerState[plyID] = {}
    end
end)

-- Handle player disconnect
hook.Add("PlayerDisconnected", "ImmersiveVoiceChat_PlayerDisconnect", function(ply)
    if IsValid(ply) then
        ImmersiveVoiceChat.Server:PlayerDisconnected(ply)
    end
end)

-- Receive voice mode from clients
net.Receive("vo_voice_mode", function(len, ply)
    if IsValid(ply) then
        local mode = net.ReadUInt(2)
        mode = math.Clamp(mode, 0, 2)
        ImmersiveVoiceChat.Server.PlayerVoiceMode[ply:SteamID64()] = mode
        ImmersiveVoiceChat.Utils.DebugPrint(
            ImmersiveVoiceChat.Utils.PlayerName(ply) .. " voice mode: " .. mode
        )
    end
end)

-- Receive radio transmit state from clients
net.Receive("vo_radio_transmit", function(len, ply)
    if IsValid(ply) then
        local active = net.ReadBool()
        local channel = math.Clamp(net.ReadUInt(4), 1, ImmersiveVoiceChat.Config.RadioMaxChannels or 9)
        local plyID = ply:SteamID64()
        ImmersiveVoiceChat.Server.PlayerRadio[plyID] = ImmersiveVoiceChat.Server.PlayerRadio[plyID] or {}
        ImmersiveVoiceChat.Server.PlayerRadio[plyID].active = active
        ImmersiveVoiceChat.Server.PlayerRadio[plyID].channel = channel
        -- Also sync the channel to PlayerRadioChannel
        ImmersiveVoiceChat.Server.PlayerRadioChannel[plyID] = channel
        print("[ImmersiveVoiceChat] " .. ply:Nick() .. " radio " .. (active and "TX ch" .. channel or "OFF"))
    end
end)

-- Receive radio channel when player scrolls (even when not transmitting)
net.Receive("vo_radio_channel", function(len, ply)
    if IsValid(ply) then
        local channel = math.Clamp(net.ReadUInt(4), 1, ImmersiveVoiceChat.Config.RadioMaxChannels or 9)
        ImmersiveVoiceChat.Server.PlayerRadioChannel[ply:SteamID64()] = channel
    end
end)

-- Think hook for processing occlusion
hook.Add("Think", "ImmersiveVoiceChat_Think", function()
    ImmersiveVoiceChat.Server:ProcessTick()
end)

-- Request sync from client
net.Receive("vo_request_sync", function(len, ply)
    if IsValid(ply) then
        -- Send current config to client
        net.Start("vo_config_sync")
            net.WriteUInt(ImmersiveVoiceChat.Config.MaxDistance, 16)
            net.WriteFloat(ImmersiveVoiceChat.Config.FallbackMinVolume)
            net.WriteBit(ImmersiveVoiceChat.Config.EnableVolumeFallback)
        net.Send(ply)
    end
end)

-- Client reporting module status
net.Receive("vo_module_status", function(len, ply)
    if IsValid(ply) then
        local hasModule = net.ReadBit() == 1
        ImmersiveVoiceChat.Utils.DebugPrint(
            ImmersiveVoiceChat.Utils.PlayerName(ply) .. 
            " module status: " .. tostring(hasModule)
        )
    end
end)

-- Admin commands
concommand.Add("vo_status", function(ply, cmd, args)
    if not IsValid(ply) or ply:IsAdmin() then
        print("=== Immersive Voice Chat Status ===")
        print("Version: " .. ImmersiveVoiceChat.Version)
        print("Active Players: " .. #player.GetAll())
        
        local speakingCount = 0
        for _, ply in ipairs(player.GetAll()) do
            if ply:IsSpeaking() then
                speakingCount = speakingCount + 1
            end
        end
        print("Currently Speaking: " .. speakingCount)
        
        print("\nPlayer States:")
        for listenerID, states in pairs(ImmersiveVoiceChat.Server.PlayerState) do
            for speakerID, occlusion in pairs(states) do
                print("  " .. listenerID .. " <- " .. speakerID .. ": " .. 
                      string.format("%.2f", occlusion))
            end
        end
        
        print("\nConfig:")
        print("  MaxDistance: " .. ImmersiveVoiceChat.Config.MaxDistance)
        print("  TraceInterval: " .. ImmersiveVoiceChat.Config.TraceInterval)
        print("  WallPenalty: " .. ImmersiveVoiceChat.Config.WallPenalty)
        print("  EnableVolumeFallback: " .. tostring(ImmersiveVoiceChat.Config.EnableVolumeFallback))
    end
end)

concommand.Add("vo_config", function(ply, cmd, args)
    if not IsValid(ply) or ply:IsAdmin() then
        print("=== Immersive Voice Chat Config ===")
        for k, v in pairs(ImmersiveVoiceChat.Config) do
            print("  " .. k .. ": " .. tostring(v))
        end
    end
end)

concommand.Add("vo_radio", function(ply, cmd, args)
    if not IsValid(ply) or ply:IsAdmin() then
        print("=== Radio State ===")
        for plyID, radio in pairs(ImmersiveVoiceChat.Server.PlayerRadio) do
            local owner = "unknown"
            for _, p in ipairs(player.GetAll()) do
                if IsValid(p) and p:SteamID64() == plyID then
                    owner = p:Nick()
                    break
                end
            end
            print("  " .. owner .. ": active=" .. tostring(radio.active) .. " ch=" .. tostring(radio.channel))
        end
        if table.Count(ImmersiveVoiceChat.Server.PlayerRadio) == 0 then
            print("  (no radio transmit data)")
        end

        print("\n=== Weapon Channels ===")
        for plyID, ch in pairs(ImmersiveVoiceChat.Server.PlayerRadioChannel) do
            local owner = "unknown"
            for _, p in ipairs(player.GetAll()) do
                if IsValid(p) and p:SteamID64() == plyID then
                    owner = p:Nick()
                    break
                end
            end
            print("  " .. owner .. ": ch=" .. tostring(ch))
        end

        print("\n=== Held Weapons ===")
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) then
                local wep = p:GetActiveWeapon()
                local wepClass = IsValid(wep) and wep:GetClass() or "none"
                print("  " .. p:Nick() .. ": " .. wepClass)
            end
        end
    end
end)
