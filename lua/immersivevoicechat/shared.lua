-- Immersive Voice Chat Shared Utilities
-- Common functions used by both client and server

ImmersiveVoiceChat.Utils = ImmersiveVoiceChat.Utils or {}

-- Calculate distance between two positions
function ImmersiveVoiceChat.Utils.GetDistance(pos1, pos2)
    return pos1:Distance(pos2)
end

-- Calculate squared distance (faster, no sqrt)
function ImmersiveVoiceChat.Utils.GetDistanceSqr(pos1, pos2)
    return pos1:DistToSqr(pos2)
end

-- Clamp value between min and max
function ImmersiveVoiceChat.Utils.Clamp(val, min, max)
    return math.Clamp(val, min, max)
end

-- Linear interpolation
function ImmersiveVoiceChat.Utils.Lerp(t, a, b)
    return Lerp(t, a, b)
end

-- Check if point is inside a box (approximate)
function ImmersiveVoiceChat.Utils.IsPointInBox(point, boxMin, boxMax)
    return point.x >= boxMin.x and point.x <= boxMax.x and
           point.y >= boxMin.y and point.y <= boxMax.y and
           point.z >= boxMin.z and point.z <= boxMax.z
end

-- Get head position (approximate eye level)
function ImmersiveVoiceChat.Utils.GetHeadPosition(ply)
    if not IsValid(ply) then return nil end
    local pos = ply:GetPos()
    return pos + Vector(0, 0, ImmersiveVoiceChat.Config.HeadHeight)
end

-- Check if two players are on the same team
function ImmersiveVoiceChat.Utils.SameTeam(ply1, ply2)
    if not IsValid(ply1) or not IsValid(ply2) then return false end
    
    -- If teams are disabled, consider everyone on same team
    if not GAMEMODE or not GAMEMODE.Team then return true end
    
    return ply1:Team() == ply2:Team()
end

-- Debug print helper
function ImmersiveVoiceChat.Utils.DebugPrint(...)
    if ImmersiveVoiceChat.Config and ImmersiveVoiceChat.Config.DebugMode then
        print("[ImmersiveVoiceChat Debug]", ...)
    end
end

-- Format player name for debug output
function ImmersiveVoiceChat.Utils.PlayerName(ply)
    if not IsValid(ply) then return "NULL" end
    return ply:Nick() .. " (" .. ply:SteamID() .. ")"
end

-- Get occlusion level description
function ImmersiveVoiceChat.Utils.GetOcclusionDescription(level)
    if level <= 0 then
        return "Clear"
    elseif level < 0.3 then
        return "Slightly Muffled"
    elseif level < 0.6 then
        return "Moderately Muffled"
    elseif level < 0.9 then
        return "Heavily Muffled"
    else
        return "Nearly Silent"
    end
end

-- Table to net-friendly format
function ImmersiveVoiceChat.Utils.TableToNet(tbl)
    net.WriteUInt(table.Count(tbl), 16)
    for k, v in pairs(tbl) do
        net.WriteString(tostring(k))
        net.WriteString(tostring(v))
    end
end

-- Net-friendly format to table
function ImmersiveVoiceChat.Utils.TableFromNet()
    local tbl = {}
    local count = net.ReadUInt(16)
    for i = 1, count do
        local k = net.ReadString()
        local v = net.ReadString()
        tbl[k] = v
    end
    return tbl
end
