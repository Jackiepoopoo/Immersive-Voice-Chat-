-- Voice Occlusion Server-Side Logic
-- Core occlusion detection and client communication

VoiceOcclusion.Server = VoiceOcclusion.Server or {}
VoiceOcclusion.Server.PlayerState = {}
VoiceOcclusion.Server.PlayerVoiceMode = {}
VoiceOcclusion.Server.LastCheck = 0
VoiceOcclusion.Server.ChecksThisTick = 0

-- Indoor detection cache: key = position bucket, value = {indoor, roomSize, time}
local indoorCache = {}

-- Velocity tracking: previous positions per player per tick
local prevPositions = {}
local prevTickTime = 0

-- Performance stats
VoiceOcclusion.Server.Stats = {
    tracesThisTick = 0,
    totalTraces = 0,
    cacheHits = 0,
    cacheMisses = 0,
    avgTickMs = 0,
    lastTickMs = 0,
}

local function getIndoorCacheKey(pos)
    local bucket = 128
    return math.floor(pos.x / bucket) .. "_" .. math.floor(pos.y / bucket) .. "_" .. math.floor(pos.z / bucket)
end

-- Detect if a position is indoors, returns indoorAmount and avgRoomSize
function VoiceOcclusion.Server:DetectIndoor(pos)
    if not pos then return 0, 0 end

    local curTime = CurTime()
    local key = getIndoorCacheKey(pos)
    local cached = indoorCache[key]
    if cached and (curTime - cached.time) < VoiceOcclusion.Config.IndoorCacheInterval then
        VoiceOcclusion.Server.Stats.cacheHits = VoiceOcclusion.Server.Stats.cacheHits + 1
        return cached.indoor, cached.roomSize
    end
    VoiceOcclusion.Server.Stats.cacheMisses = VoiceOcclusion.Server.Stats.cacheMisses + 1

    local directions = {
        Vector(1, 0, 0),
        Vector(-1, 0, 0),
        Vector(0, 1, 0),
        Vector(0, -1, 0),
        Vector(0, 0, 1),
        Vector(0, 0, -1),
    }

    local hits = 0
    local totalDist = 0
    local traceLen = 300

    for _, dir in ipairs(directions) do
        local tr = util.TraceLine({
            start = pos,
            endpos = pos + dir * traceLen,
            mask = VoiceOcclusion.Config.TraceMask
        })
        if tr.Hit and tr.HitWorld then
            hits = hits + 1
            totalDist = totalDist + tr.HitPos:Distance(pos)
        end
    end

    local indoor = hits / #directions
    local avgRoomSize = 0
    if hits > 0 then
        avgRoomSize = totalDist / hits
    end

    indoorCache[key] = { indoor = indoor, roomSize = avgRoomSize, time = curTime }
    return indoor, avgRoomSize
end

-- Calculate occlusion between two players
function VoiceOcclusion.Server:CalculateOcclusion(speaker, listener)
    if not IsValid(speaker) or not IsValid(listener) then
        return nil, nil
    end

    local speakerPos = VoiceOcclusion.Utils.GetHeadPosition(speaker)
    local listenerPos = VoiceOcclusion.Utils.GetHeadPosition(listener)

    if not speakerPos or not listenerPos then
        return nil, nil
    end

    local dist = VoiceOcclusion.Utils.GetDistance(speakerPos, listenerPos)
    if dist > VoiceOcclusion.Config.MaxDistance then
        return 1, dist, speakerPos
    end

    if dist < 80 then
        return 0, dist, speakerPos
    end

    if VoiceOcclusion.Config.SkipFriendlyFire and
       VoiceOcclusion.Utils.SameTeam(speaker, listener) then
        return VoiceOcclusion.Config.MinOcclusion, dist, speakerPos
    end

    -- Adaptive trace count based on distance
    local numTraces, coneAngle
    if dist < VoiceOcclusion.Config.CloseRange then
        numTraces = 12
        coneAngle = 25
    elseif dist < VoiceOcclusion.Config.MediumRange then
        numTraces = 7
        coneAngle = 15
    else
        numTraces = 4
        coneAngle = 10
    end

    local dir = (listenerPos - speakerPos):GetNormalized()

    -- Predefined 3D offsets: sphere-like distribution, trimmed per distance tier
    local traceOffsets = {
        {0, 0},
        {0, 15},
        {0, -15},
        {12, 0},
        {-12, 0},
        {12, 10},
        {12, -10},
        {-12, 10},
        {-12, -10},
        {25, 0},
        {-25, 0},
        {0, 20},
    }

    local hits = 0
    local glassHits = 0
    local doorHits = 0

    for i = 1, numTraces do
        local offset = traceOffsets[i] or {0, 0}
        local pitchSpread = offset[1]
        local yawSpread = offset[2]

        local trDir = dir:Angle()
        trDir:RotateAroundAxis(trDir:Right(), pitchSpread)
        trDir:RotateAroundAxis(trDir:Up(), yawSpread)

        local tr = util.TraceLine({
            start = speakerPos,
            endpos = speakerPos + trDir:Forward() * dist,
            filter = {speaker, listener},
            mask = VoiceOcclusion.Config.TraceMask
        })

        VoiceOcclusion.Server.Stats.tracesThisTick = VoiceOcclusion.Server.Stats.tracesThisTick + 1

        if tr.Hit then
            local isGlass = false
            local isDoor = false

            if IsValid(tr.Entity) then
                local mat = tr.Entity:GetMaterialType()
                if mat == MAT_GLASS then isGlass = true end
                local class = tr.Entity:GetClass()
                if string.find(class, "door") then isDoor = true end
            end

            if isGlass then
                glassHits = glassHits + 1
            elseif isDoor then
                doorHits = doorHits + 1
            else
                hits = hits + 1
            end
        end
    end

    if hits == 0 and glassHits == 0 and doorHits == 0 then
        return VoiceOcclusion.Config.MinOcclusion, dist, speakerPos
    end

    local blockage = hits / numTraces
    local occlusion = VoiceOcclusion.Config.WallPenalty * blockage

    local glassRatio = glassHits / numTraces
    occlusion = occlusion + VoiceOcclusion.Config.GlassPenalty * glassRatio

    local doorRatio = doorHits / numTraces
    occlusion = occlusion + VoiceOcclusion.Config.DoorPenalty * doorRatio

    -- Extra occlusion for thick walls (only when a solid wall was hit)
    if hits > 0 then
        local trCenter = util.TraceLine({
            start = speakerPos,
            endpos = listenerPos,
            filter = {speaker, listener},
            mask = VoiceOcclusion.Config.TraceMask
        })

        if trCenter.Hit then
            local trExit = util.TraceLine({
                start = trCenter.HitPos + trCenter.HitNormal * 1,
                endpos = listenerPos,
                filter = {speaker, listener},
                mask = VoiceOcclusion.Config.TraceMask
            })

            local wallThickness = 1
            if trExit.Hit then
                wallThickness = trCenter.HitPos:Distance(trExit.HitPos) / 100
            end

            if wallThickness > 2 then
                occlusion = occlusion + (wallThickness - 2) * VoiceOcclusion.Config.ThickWallBonus
            end
        end
    end

    occlusion = VoiceOcclusion.Utils.Clamp(
        occlusion,
        VoiceOcclusion.Config.MinOcclusion,
        VoiceOcclusion.Config.MaxOcclusion
    )

    -- Apply voice mode occlusion multiplier
    local mode = VoiceOcclusion.Server.PlayerVoiceMode[speaker:SteamID64()] or 1
    local modeData = VoiceOcclusion.Config.VoiceModes[mode] or VoiceOcclusion.Config.VoiceModes[1]
    occlusion = math.Clamp(occlusion * modeData.occlusionMult, VoiceOcclusion.Config.MinOcclusion, VoiceOcclusion.Config.MaxOcclusion)

    if VoiceOcclusion.Config.DrawDebugTraces then
        local color = Color(255, 0, 0, 100)
        if occlusion < 0.5 then color = Color(255, 255, 0, 100) end
        if occlusion == 0 then color = Color(0, 255, 0, 100) end
        debugoverlay.Line(speakerPos, listenerPos, 0.3, color, false)
    end

    return occlusion, dist, speakerPos
end

-- Calculate velocity for a player (units/sec)
local function GetPlayerVelocity(ply)
    if not IsValid(ply) then return 0, 0, 0 end
    local sid = ply:SteamID64()
    local curPos = ply:GetPos()
    local curTime = CurTime()
    local dt = curTime - prevTickTime

    if dt < 0.01 or not prevPositions[sid] then
        prevPositions[sid] = curPos
        return 0, 0, 0
    end

    local prev = prevPositions[sid]
    local vx = (curPos.x - prev.x) / dt
    local vy = (curPos.y - prev.y) / dt
    local vz = (curPos.z - prev.z) / dt
    prevPositions[sid] = curPos
    return vx, vy, vz
end

-- Detect if a player is underwater
local function IsUnderwater(ply)
    if not IsValid(ply) then return false end
    local pos = VoiceOcclusion.Utils.GetHeadPosition(ply) or ply:GetPos()
    return bit.band(util.PointContents(pos), CONTENTS_WATER) == CONTENTS_WATER
end

-- Send occlusion data to a client (with delta compression)
function VoiceOcclusion.Server:SendOcclusionToClient(speaker, listener, occlusion, dist, speakerPos, indoor, roomSize)
    if not IsValid(speaker) or not IsValid(listener) then
        return
    end

    if not speakerPos then
        speakerPos = VoiceOcclusion.Utils.GetHeadPosition(speaker)
        if not speakerPos then return end
    end

    local speakerID = speaker:SteamID64()
    local listenerID = listener:SteamID64()

    VoiceOcclusion.Server.PlayerState[listenerID] =
        VoiceOcclusion.Server.PlayerState[listenerID] or {}

    -- Delta compression: only send if occlusion changed significantly
    local prevOcc = VoiceOcclusion.Server.PlayerState[listenerID][speakerID]
    if prevOcc ~= nil and math.abs(occlusion - prevOcc) < VoiceOcclusion.Config.DeltaThreshold then
        return
    end

    VoiceOcclusion.Server.PlayerState[listenerID][speakerID] = occlusion

    -- Calculate velocity
    local vx, vy, vz = GetPlayerVelocity(speaker)

    -- Detect underwater
    local underwater = IsUnderwater(speaker) and 1 or 0

    -- Get speaker's voice mode
    local voiceMode = VoiceOcclusion.Server.PlayerVoiceMode[speaker:SteamID64()] or 1

    net.Start("vo_occlusion_update")
        net.WriteEntity(speaker)
        net.WriteFloat(occlusion)
        net.WriteFloat(dist)
        net.WriteVector(speakerPos)
        net.WriteFloat(indoor or 0)
        net.WriteFloat(roomSize or 0)
        net.WriteFloat(vx)
        net.WriteFloat(vy)
        net.WriteFloat(vz)
        net.WriteBit(underwater)
        net.WriteUInt(voiceMode, 2)
    net.Send(listener)
end

-- Process a single tick of occlusion checks
function VoiceOcclusion.Server:ProcessTick()
    local curTime = CurTime()
    local tickStart = SysTime()

    if curTime - VoiceOcclusion.Server.LastCheck < VoiceOcclusion.Config.TraceInterval then
        return
    end

    VoiceOcclusion.Server.LastCheck = curTime
    VoiceOcclusion.Server.ChecksThisTick = 0
    VoiceOcclusion.Server.Stats.tracesThisTick = 0

    -- Update velocity tick timing
    if prevTickTime == 0 then prevTickTime = curTime end
    prevTickTime = curTime

    local players = player.GetAll()
    local numPlayers = #players

    local pendingSends = {}

    for i = 1, numPlayers do
        for j = i + 1, numPlayers do
            local speaker = players[i]
            local listener = players[j]

            if VoiceOcclusion.Server.ChecksThisTick >=
               VoiceOcclusion.Config.MaxChecksPerTick then
                goto done
            end

            VoiceOcclusion.Server.ChecksThisTick =
                VoiceOcclusion.Server.ChecksThisTick + 1

            local occAtoB, distAtoB, posA = self:CalculateOcclusion(speaker, listener)
            if occAtoB ~= nil then
                local indoorA, roomA = self:DetectIndoor(posA)
                pendingSends[#pendingSends + 1] = {
                    speaker = speaker, listener = listener,
                    occ = occAtoB, dist = distAtoB or 0, pos = posA,
                    indoor = indoorA, roomSize = roomA
                }
            end

            local occBtoA, distBtoA, posB = self:CalculateOcclusion(listener, speaker)
            if occBtoA ~= nil then
                local indoorB, roomB = self:DetectIndoor(posB)
                pendingSends[#pendingSends + 1] = {
                    speaker = listener, listener = speaker,
                    occ = occBtoA, dist = distBtoA or 0, pos = posB,
                    indoor = indoorB, roomSize = roomB
                }
            end
        end
    end

    ::done::

    local grouped = {}
    for _, send in ipairs(pendingSends) do
        local lid = send.listener:SteamID64()
        grouped[lid] = grouped[lid] or {}
        grouped[lid][#grouped[lid] + 1] = send
    end

    for _, sends in pairs(grouped) do
        for _, send in ipairs(sends) do
            self:SendOcclusionToClient(send.speaker, send.listener, send.occ, send.dist, send.pos, send.indoor, send.roomSize)
        end
    end

    -- Update performance stats
    local elapsed = (SysTime() - tickStart) * 1000
    VoiceOcclusion.Server.Stats.lastTickMs = elapsed
    VoiceOcclusion.Server.Stats.totalTraces = VoiceOcclusion.Server.Stats.totalTraces + VoiceOcclusion.Server.Stats.tracesThisTick
    VoiceOcclusion.Server.Stats.avgTickMs = VoiceOcclusion.Server.Stats.avgTickMs * 0.9 + elapsed * 0.1
end

-- Clean up player state when they disconnect
function VoiceOcclusion.Server:PlayerDisconnected(ply)
    local plyID = ply:SteamID64()
    VoiceOcclusion.Server.PlayerState[plyID] = nil
    VoiceOcclusion.Server.PlayerVoiceMode[plyID] = nil
    prevPositions[plyID] = nil

    for otherID, state in pairs(VoiceOcclusion.Server.PlayerState) do
        state[plyID] = nil
    end
end

-- Get occlusion data for a specific player pair (for API access)
function VoiceOcclusion.Server:GetOcclusion(speaker, listener)
    if not IsValid(speaker) or not IsValid(listener) then
        return nil
    end

    local speakerID = speaker:SteamID64()
    local listenerID = listener:SteamID64()

    if VoiceOcclusion.Server.PlayerState[listenerID] then
        return VoiceOcclusion.Server.PlayerState[listenerID][speakerID]
    end

    return nil
end

-- Console command to force sync all players
concommand.Add("vo_resync", function(ply, cmd, args)
    if not IsValid(ply) or ply:IsAdmin() then
        VoiceOcclusion.Server.PlayerState = {}
        indoorCache = {}
        print("[VoiceOcclusion] Player state cleared, will resync on next check")
    end
end)
