-- Immersive Voice Chat Server-Side Logic
-- Core occlusion detection and client communication

ImmersiveVoiceChat.Server = ImmersiveVoiceChat.Server or {}
ImmersiveVoiceChat.Server.PlayerState = {}
ImmersiveVoiceChat.Server.PlayerVoiceMode = {}
ImmersiveVoiceChat.Server.PlayerRadio = {} -- {steamID = {active=bool, channel=int}}
ImmersiveVoiceChat.Server.PlayerRadioChannel = {} -- {steamID = channel} — what channel each player's weapon is set to
ImmersiveVoiceChat.Server.LastCheck = 0
ImmersiveVoiceChat.Server.ChecksThisTick = 0

-- Indoor detection cache: key = position bucket, value = {indoor, roomSize, time}
local indoorCache = {}

-- Velocity tracking: previous positions per player per tick
local prevPositions = {}
local prevTickTime = 0

-- Performance stats
ImmersiveVoiceChat.Server.Stats = {
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
function ImmersiveVoiceChat.Server:DetectIndoor(pos)
    if not pos then return 0, 0 end

    local curTime = CurTime()
    local key = getIndoorCacheKey(pos)
    local cached = indoorCache[key]
    if cached and (curTime - cached.time) < ImmersiveVoiceChat.Config.IndoorCacheInterval then
        ImmersiveVoiceChat.Server.Stats.cacheHits = ImmersiveVoiceChat.Server.Stats.cacheHits + 1
        return cached.indoor, cached.roomSize
    end
    ImmersiveVoiceChat.Server.Stats.cacheMisses = ImmersiveVoiceChat.Server.Stats.cacheMisses + 1

    local directions = {
        Vector(1, 0, 0),
        Vector(-1, 0, 0),
        Vector(0, 1, 0),
        Vector(0, -1, 0),
        Vector(1, 1, 0):GetNormalized(),
        Vector(-1, 1, 0):GetNormalized(),
        Vector(1, -1, 0):GetNormalized(),
        Vector(-1, -1, 0):GetNormalized(),
        Vector(0, 0, 1),
        Vector(0, 0, -1),
    }

    local hits = 0
    local totalDist = 0
    local traceLen = 800

    for _, dir in ipairs(directions) do
        local tr = util.TraceLine({
            start = pos,
            endpos = pos + dir * traceLen,
            mask = ImmersiveVoiceChat.Config.TraceMask
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
function ImmersiveVoiceChat.Server:CalculateOcclusion(speaker, listener)
    if not IsValid(speaker) or not IsValid(listener) then
        return nil, nil
    end

    local speakerPos = ImmersiveVoiceChat.Utils.GetHeadPosition(speaker)
    local listenerPos = ImmersiveVoiceChat.Utils.GetHeadPosition(listener)

    if not speakerPos or not listenerPos then
        return nil, nil
    end

    local dist = ImmersiveVoiceChat.Utils.GetDistance(speakerPos, listenerPos)

    -- Use voice mode adjusted max distance
    local mode = ImmersiveVoiceChat.Server.PlayerVoiceMode[speaker:SteamID64()] or 1
    local modeData = ImmersiveVoiceChat.Config.VoiceModes[mode] or ImmersiveVoiceChat.Config.VoiceModes[1]
    local adjustedMaxDist = ImmersiveVoiceChat.Config.MaxDistance * modeData.maxDistMult

    if dist > adjustedMaxDist then
        return 1, dist, speakerPos
    end

    if dist < 80 then
        return 0, dist, speakerPos
    end

    if ImmersiveVoiceChat.Config.SkipFriendlyFire and
       ImmersiveVoiceChat.Utils.SameTeam(speaker, listener) then
        return ImmersiveVoiceChat.Config.MinOcclusion, dist, speakerPos
    end

    -- Adaptive trace count based on distance
    local numTraces, coneAngle
    if dist < ImmersiveVoiceChat.Config.CloseRange then
        numTraces = 12
        coneAngle = 25
    elseif dist < ImmersiveVoiceChat.Config.MediumRange then
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
            mask = ImmersiveVoiceChat.Config.TraceMask
        })

        ImmersiveVoiceChat.Server.Stats.tracesThisTick = ImmersiveVoiceChat.Server.Stats.tracesThisTick + 1

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
        return ImmersiveVoiceChat.Config.MinOcclusion, dist, speakerPos
    end

    local blockage = hits / numTraces
    local occlusion = ImmersiveVoiceChat.Config.WallPenalty * blockage

    local glassRatio = glassHits / numTraces
    occlusion = occlusion + ImmersiveVoiceChat.Config.GlassPenalty * glassRatio

    local doorRatio = doorHits / numTraces
    occlusion = occlusion + ImmersiveVoiceChat.Config.DoorPenalty * doorRatio

    -- Extra occlusion for thick walls (only when a solid wall was hit)
    if hits > 0 then
        local trCenter = util.TraceLine({
            start = speakerPos,
            endpos = listenerPos,
            filter = {speaker, listener},
            mask = ImmersiveVoiceChat.Config.TraceMask
        })

        if trCenter.Hit then
            local trExit = util.TraceLine({
                start = trCenter.HitPos + trCenter.HitNormal * 1,
                endpos = listenerPos,
                filter = {speaker, listener},
                mask = ImmersiveVoiceChat.Config.TraceMask
            })

            local wallThickness = 1
            if trExit.Hit then
                wallThickness = trCenter.HitPos:Distance(trExit.HitPos) / 100
            end

            if wallThickness > 2 then
                occlusion = occlusion + (wallThickness - 2) * ImmersiveVoiceChat.Config.ThickWallBonus
            end
        end
    end

    occlusion = ImmersiveVoiceChat.Utils.Clamp(
        occlusion,
        ImmersiveVoiceChat.Config.MinOcclusion,
        ImmersiveVoiceChat.Config.MaxOcclusion
    )

    -- Apply voice mode occlusion multiplier
    occlusion = math.Clamp(occlusion * modeData.occlusionMult, ImmersiveVoiceChat.Config.MinOcclusion, ImmersiveVoiceChat.Config.MaxOcclusion)

    if ImmersiveVoiceChat.Config.DrawDebugTraces then
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
    local pos = ImmersiveVoiceChat.Utils.GetHeadPosition(ply) or ply:GetPos()
    return bit.band(util.PointContents(pos), CONTENTS_WATER) == CONTENTS_WATER
end

-- Send occlusion data to a client (with delta compression)
function ImmersiveVoiceChat.Server:SendOcclusionToClient(speaker, listener, occlusion, dist, speakerPos, indoor, roomSize)
    if not IsValid(speaker) or not IsValid(listener) then
        return
    end

    if not speakerPos then
        speakerPos = ImmersiveVoiceChat.Utils.GetHeadPosition(speaker)
        if not speakerPos then return end
    end

    local speakerID = speaker:SteamID64()
    local listenerID = listener:SteamID64()

    ImmersiveVoiceChat.Server.PlayerState[listenerID] =
        ImmersiveVoiceChat.Server.PlayerState[listenerID] or {}

    -- Delta compression: only send if occlusion changed significantly
    local prevOcc = ImmersiveVoiceChat.Server.PlayerState[listenerID][speakerID]
    if prevOcc ~= nil and math.abs(occlusion - prevOcc) < ImmersiveVoiceChat.Config.DeltaThreshold then
        -- Even if occlusion didn't change, still update position/velocity periodically
        -- so 3D panning stays accurate
        local posKey = listenerID .. "_" .. speakerID
        ImmersiveVoiceChat.Server.LastPositionSend = ImmersiveVoiceChat.Server.LastPositionSend or {}
        local lastSend = ImmersiveVoiceChat.Server.LastPositionSend[posKey] or 0
        if CurTime() - lastSend < 0.2 then
            return
        end
        ImmersiveVoiceChat.Server.LastPositionSend[posKey] = CurTime()
    end

    ImmersiveVoiceChat.Server.PlayerState[listenerID][speakerID] = occlusion

    -- Calculate velocity
    local vx, vy, vz = GetPlayerVelocity(speaker)

    -- Detect underwater
    local underwater = IsUnderwater(speaker) and 1 or 0

    -- Get speaker's voice mode
    local voiceMode = ImmersiveVoiceChat.Server.PlayerVoiceMode[speaker:SteamID64()] or 1

    -- Get radio state
    local radioData = ImmersiveVoiceChat.Server.PlayerRadio[speaker:SteamID64()]
    local isRadio = radioData and radioData.active and 1 or 0

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
        net.WriteBit(isRadio)
    net.Send(listener)
end

-- Process a single tick of occlusion checks
function ImmersiveVoiceChat.Server:ProcessTick()
    local curTime = CurTime()
    local tickStart = SysTime()

    if curTime - ImmersiveVoiceChat.Server.LastCheck < ImmersiveVoiceChat.Config.TraceInterval then
        return
    end

    ImmersiveVoiceChat.Server.LastCheck = curTime
    ImmersiveVoiceChat.Server.ChecksThisTick = 0
    ImmersiveVoiceChat.Server.Stats.tracesThisTick = 0

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

            if ImmersiveVoiceChat.Server.ChecksThisTick >=
               ImmersiveVoiceChat.Config.MaxChecksPerTick then
                goto done
            end

            ImmersiveVoiceChat.Server.ChecksThisTick =
                ImmersiveVoiceChat.Server.ChecksThisTick + 1

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
    ImmersiveVoiceChat.Server.Stats.lastTickMs = elapsed
    ImmersiveVoiceChat.Server.Stats.totalTraces = ImmersiveVoiceChat.Server.Stats.totalTraces + ImmersiveVoiceChat.Server.Stats.tracesThisTick
    ImmersiveVoiceChat.Server.Stats.avgTickMs = ImmersiveVoiceChat.Server.Stats.avgTickMs * 0.9 + elapsed * 0.1
end

-- Clean up player state when they disconnect
function ImmersiveVoiceChat.Server:PlayerDisconnected(ply)
    local plyID = ply:SteamID64()
    ImmersiveVoiceChat.Server.PlayerState[plyID] = nil
    ImmersiveVoiceChat.Server.PlayerVoiceMode[plyID] = nil
    ImmersiveVoiceChat.Server.PlayerRadio[plyID] = nil
    ImmersiveVoiceChat.Server.PlayerRadioChannel[plyID] = nil
    prevPositions[plyID] = nil

    for otherID, state in pairs(ImmersiveVoiceChat.Server.PlayerState) do
        state[plyID] = nil
    end
end

-- Get occlusion data for a specific player pair (for API access)
function ImmersiveVoiceChat.Server:GetOcclusion(speaker, listener)
    if not IsValid(speaker) or not IsValid(listener) then
        return nil
    end

    local speakerID = speaker:SteamID64()
    local listenerID = listener:SteamID64()

    if ImmersiveVoiceChat.Server.PlayerState[listenerID] then
        return ImmersiveVoiceChat.Server.PlayerState[listenerID][speakerID]
    end

    return nil
end

-- Console command to force sync all players
concommand.Add("vo_resync", function(ply, cmd, args)
    if not IsValid(ply) or ply:IsAdmin() then
        ImmersiveVoiceChat.Server.PlayerState = {}
        indoorCache = {}
        print("[ImmersiveVoiceChat] Player state cleared, will resync on next check")
    end
end)
