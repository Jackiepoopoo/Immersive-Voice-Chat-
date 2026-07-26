-- Immersive Voice Chat Client-Side Main Logic
-- Handles receiving occlusion data and applying effects

ImmersiveVoiceChat.Client = ImmersiveVoiceChat.Client or {}
ImmersiveVoiceChat.Client.Enabled = true
ImmersiveVoiceChat.Client.StoredOcclusion = {}
ImmersiveVoiceChat.Client.Config = {
    MaxDistance = 5000,
    FallbackMinVolume = 0.15,
    EnableVolumeFallback = true
}

-- VO UI Theme
local VO_UI = {
    bg = Color(22, 22, 28, 250),
    sidebar = Color(16, 16, 20, 255),
    accent = Color(88, 166, 255),
    text = Color(230, 230, 238),
    dimText = Color(130, 130, 145),
    hover = Color(255, 255, 255, 5),
    border = Color(255, 255, 255, 18),
    track = Color(38, 38, 46),
}

surface.CreateFont("VO_UI_Title", { font = "Segoe UI", size = 22, weight = 700, antialias = true })
surface.CreateFont("VO_UI_Section", { font = "Segoe UI", size = 13, weight = 600, antialias = true })
surface.CreateFont("VO_UI_Label", { font = "Segoe UI", size = 16, weight = 400, antialias = true })
surface.CreateFont("VO_UI_Desc", { font = "Segoe UI", size = 13, weight = 400, antialias = true })
surface.CreateFont("VO_UI_Numeric", { font = "Consolas", size = 14, weight = 400, antialias = true })
surface.CreateFont("VO_UI_Tab", { font = "Segoe UI", size = 14, weight = 400, antialias = true })
surface.CreateFont("VO_UI_TabActive", { font = "Segoe UI", size = 14, weight = 700, antialias = true })

local function DrawFilledCircle(x, y, radius, color)
    draw.NoTexture()
    surface.SetDrawColor(color)
    local segs = 24
    local verts = {}
    for i = 0, segs do
        local a = math.rad((i / segs) * 360)
        verts[i + 1] = { x = x + math.cos(a) * radius, y = y + math.sin(a) * radius }
    end
    surface.DrawPoly(verts)
end

local function CreateSectionHeader(parent, text)
    local header = vgui.Create("DPanel", parent)
    header:Dock(TOP)
    header:DockMargin(10, 20, 10, 6)
    header:SetTall(24)
    header.Paint = function(self, w, h)
        draw.SimpleText(string.upper(text), "VO_UI_Section", 0, h / 2, VO_UI.dimText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    return header
end

local function CreatePillToggle(parent, label, description, getFunc, setFunc)
    local row = vgui.Create("DPanel", parent)
    row:Dock(TOP)
    row:DockMargin(6, 3, 6, 3)
    row:SetTall(50)
    row:SetMouseInputEnabled(true)
    local anim = getFunc() and 1 or 0
    local wasMouseDown = false

    row.Paint = function(self, w, h)
        if self:IsHovered() then draw.RoundedBox(6, 0, 0, w, h, VO_UI.hover) end
        draw.SimpleText(label, "VO_UI_Label", 12, description and 11 or h / 2, VO_UI.text, TEXT_ALIGN_LEFT, description and TEXT_ALIGN_TOP or TEXT_ALIGN_CENTER)
        if description then draw.SimpleText(description, "VO_UI_Desc", 12, 32, VO_UI.dimText, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP) end

        local pillW, pillH = 40, 22
        local pillX = w - pillW - 12
        local pillY = h / 2 - pillH / 2
        local r = Lerp(anim, 45, VO_UI.accent.r)
        local g = Lerp(anim, 45, VO_UI.accent.g)
        local b = Lerp(anim, 52, VO_UI.accent.b)
        draw.RoundedBox(pillH / 2, pillX, pillY, pillW, pillH, Color(r, g, b))

        local knobR = 7
        local knobX = Lerp(anim, pillX + knobR + 3, pillX + pillW - knobR - 3)
        DrawFilledCircle(knobX, pillY + pillH / 2, knobR, Color(255, 255, 255, 240))
    end

    row.Think = function(self)
        local target = getFunc() and 1 or 0
        anim = Lerp(FrameTime() * 14, anim, target)

        local mouseDown = input.IsMouseDown(MOUSE_LEFT)
        if mouseDown and not wasMouseDown and self:IsHovered() then
            setFunc(not getFunc())
        end
        wasMouseDown = mouseDown
    end
    return row
end

local function CreateThinSlider(parent, label, description, getFunc, setFunc, min, max, decimals)
    local row = vgui.Create("DPanel", parent)
    row:Dock(TOP)
    row:DockMargin(6, 5, 6, 5)
    row:SetTall(56)
    row:SetMouseInputEnabled(true)
    local trackH = 4
    local thumbR = 7
    local dragging = false
    local wasMouseDown = false
    local dragVal = nil

    local entry = vgui.Create("DTextEntry", row)
    entry:SetSize(80, 20)
    entry:SetFont("VO_UI_Numeric")
    entry:SetNumeric(true)
    entry:SetDrawBackground(false)
    entry:SetTextColor(VO_UI.dimText)
    entry:SetCursorColor(VO_UI.text)
    entry.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 35, 200))
        self:DrawTextEntryText(self:GetTextColor(), VO_UI.accent, VO_UI.text)
    end

    local function SyncEntry()
        entry:SetValue(string.format("%." .. decimals .. "f", getFunc()))
    end
    SyncEntry()

    local function ApplyEntry()
        local num = tonumber(entry:GetValue())
        if not num then SyncEntry() return end
        local step = 10 ^ -decimals
        num = math.Clamp(math.Round(math.Round(num / step) * step, decimals), min, max)
        setFunc(num)
        SyncEntry()
    end

    local wasEntryFocused = false

    entry.OnEnter = function(self) ApplyEntry() end

    entry.Think = function(self)
        local focused = self:HasFocus()
        if wasEntryFocused and not focused then
            ApplyEntry()
        end
        wasEntryFocused = focused
    end

    row.Paint = function(self, w, h)
        if self:IsHovered() or dragging then draw.RoundedBox(6, 0, 0, w, h, VO_UI.hover) end
        draw.SimpleText(label, "VO_UI_Label", 12, 5, VO_UI.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        if description then draw.SimpleText(description, "VO_UI_Desc", 12, 26, VO_UI.dimText, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP) end

        local val = dragVal or getFunc()

        local trackW = w - 24
        local trackX = 12
        local trackY = 44
        draw.RoundedBox(trackH / 2, trackX, trackY, trackW, trackH, VO_UI.track)

        local frac = math.Clamp((val - min) / (max - min), 0, 1)
        if frac > 0 then draw.RoundedBox(trackH / 2, trackX, trackY, trackW * frac, trackH, VO_UI.accent) end

        local thumbX = trackX + trackW * frac
        local thumbY = trackY + trackH / 2
        local tr = (self:IsHovered() or dragging) and thumbR + 1 or thumbR
        DrawFilledCircle(thumbX, thumbY, tr, VO_UI.text)
    end

    row.Think = function(self)
        entry:SetPos(self:GetWide() - 80 - 12, 5)
        local mouseDown = input.IsMouseDown(MOUSE_LEFT)

        if not dragging and mouseDown and not wasMouseDown and self:IsHovered() then
            dragging = true
        end

        if dragging and not mouseDown then
            dragging = false
            dragVal = nil
            SyncEntry()
        end

        if dragging then
            local mx = self:LocalCursorPos()
            local w = self:GetWide()
            local frac = math.Clamp((mx - 12) / (w - 24), 0, 1)
            local raw = min + frac * (max - min)
            local step = 10 ^ -decimals
            dragVal = math.Round(math.Round(raw / step) * step, decimals)
            setFunc(dragVal)
            SyncEntry()
        end

        wasMouseDown = mouseDown
    end
    return row
end

-- Client-side performance stats
ImmersiveVoiceChat.Client.Stats = {
    updatesReceived = 0,
    lastUpdateMs = 0,
}

-- HUD display settings
ImmersiveVoiceChat.Client.HUDEnabled = false
ImmersiveVoiceChat.Client.HUDTarget = nil  -- Entity to show occlusion for

-- Voice mode system
ImmersiveVoiceChat.Client.VoiceMode = 1  -- 0=Whisper, 1=Talk, 2=Yell
local modeChangeTime = 0
local MODE_FADE_TIME = 2.0
local MODE_NAMES = { [0] = "WHISPER", [1] = "TALK", [2] = "YELL" }
local MODE_COLORS = {
    [0] = Color(120, 180, 255),
    [1] = Color(200, 200, 200),
    [2] = Color(255, 100, 80),
}

local function SendVoiceModeToServer()
    net.Start("vo_voice_mode")
        net.WriteUInt(ImmersiveVoiceChat.Client.VoiceMode, 2)
    net.SendToServer()
end

local function SendVoiceModeToModule()
    if not ImmersiveVoiceChat.Client.ModuleLoaded or not immersivevoicechat then return end
    -- Re-push all player data with updated voiceMode
    local data = {}
    for sid, occ in pairs(ImmersiveVoiceChat.Client.StoredOcclusion) do
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) and p:SteamID64() == sid then
                local dist = ImmersiveVoiceChat.Client.StoredDistance[sid] or 0
                local pos = ImmersiveVoiceChat.Client.StoredPosition[sid]
                local ind = ImmersiveVoiceChat.Client.StoredIndoor[sid] or 0
                local room = ImmersiveVoiceChat.Client.StoredRoomSize[sid] or 0
                local vel = ImmersiveVoiceChat.Client.StoredVelocity[sid] or Vector(0,0,0)
                local uw = ImmersiveVoiceChat.Client.StoredUnderwater[sid] and 1 or 0
                local radio = ImmersiveVoiceChat.Client.StoredRadio and ImmersiveVoiceChat.Client.StoredRadio[sid] or 0
                local px, py, pz = 0, 0, 0
                if pos then px, py, pz = pos.x, pos.y, pos.z end
                data[p:Nick()] = {occ, dist, px, py, pz, vel.x, vel.y, vel.z, ind, room, uw, ImmersiveVoiceChat.Client.VoiceMode, radio}
                break
            end
        end
    end
    immersivevoicechat.SetPlayerOcclusions(data)
end

concommand.Add("vo_cyclemode", function()
    local cur = ImmersiveVoiceChat.Client.VoiceMode
    ImmersiveVoiceChat.Client.VoiceMode = (cur + 1) % 3
    modeChangeTime = CurTime()
    SendVoiceModeToServer()
    SendVoiceModeToModule()
end)

concommand.Add("vo_setmode", function(ply, cmd, args)
    local mode = tonumber(args[1])
    if mode and mode >= 0 and mode <= 2 then
        ImmersiveVoiceChat.Client.VoiceMode = mode
        modeChangeTime = CurTime()
        SendVoiceModeToServer()
        SendVoiceModeToModule()
    end
end)

-- Receive occlusion updates from server
net.Receive("vo_occlusion_update", function()
    local tickStart = SysTime()
    local speaker = net.ReadEntity()
    local occlusion = net.ReadFloat()
    local distance = net.ReadFloat()
    local speakerPos = net.ReadVector()
    local indoor = net.ReadFloat()
    local roomSize = net.ReadFloat()
    local vx = net.ReadFloat()
    local vy = net.ReadFloat()
    local vz = net.ReadFloat()
    local underwater = net.ReadBit() == 1
    local voiceMode = net.ReadUInt(2)
    local isRadio = net.ReadBit() == 1
    
    if isRadio then
        print("[Radio-CL] Received isRadio=1 from " .. (IsValid(speaker) and speaker:Nick() or "???"))
    end
    
    if IsValid(speaker) then
        local steamID = speaker:SteamID64()
        ImmersiveVoiceChat.Client.StoredOcclusion[steamID] = occlusion
        ImmersiveVoiceChat.Client.StoredDistance = ImmersiveVoiceChat.Client.StoredDistance or {}
        ImmersiveVoiceChat.Client.StoredDistance[steamID] = distance
        ImmersiveVoiceChat.Client.StoredPosition = ImmersiveVoiceChat.Client.StoredPosition or {}
        ImmersiveVoiceChat.Client.StoredPosition[steamID] = speakerPos
        ImmersiveVoiceChat.Client.StoredIndoor = ImmersiveVoiceChat.Client.StoredIndoor or {}
        ImmersiveVoiceChat.Client.StoredIndoor[steamID] = indoor
        ImmersiveVoiceChat.Client.StoredRoomSize = ImmersiveVoiceChat.Client.StoredRoomSize or {}
        ImmersiveVoiceChat.Client.StoredRoomSize[steamID] = roomSize
        ImmersiveVoiceChat.Client.StoredVelocity = ImmersiveVoiceChat.Client.StoredVelocity or {}
        ImmersiveVoiceChat.Client.StoredVelocity[steamID] = Vector(vx, vy, vz)
        ImmersiveVoiceChat.Client.StoredUnderwater = ImmersiveVoiceChat.Client.StoredUnderwater or {}
        ImmersiveVoiceChat.Client.StoredUnderwater[steamID] = underwater
        ImmersiveVoiceChat.Client.StoredVoiceMode = ImmersiveVoiceChat.Client.StoredVoiceMode or {}
        ImmersiveVoiceChat.Client.StoredVoiceMode[steamID] = voiceMode
        ImmersiveVoiceChat.Client.StoredRadio = ImmersiveVoiceChat.Client.StoredRadio or {}
        ImmersiveVoiceChat.Client.StoredRadio[steamID] = isRadio and 1 or 0
        
        -- Push all occlusion data to binary module for Mumble shared memory
        if ImmersiveVoiceChat.Client.ModuleLoaded and immersivevoicechat then
            local data = {}
            for sid, occ in pairs(ImmersiveVoiceChat.Client.StoredOcclusion) do
                for _, p in ipairs(player.GetAll()) do
                    if IsValid(p) and p:SteamID64() == sid then
                        local dist = ImmersiveVoiceChat.Client.StoredDistance[sid] or 0
                        local pos = ImmersiveVoiceChat.Client.StoredPosition[sid]
                        local ind = ImmersiveVoiceChat.Client.StoredIndoor[sid] or 0
                        local room = ImmersiveVoiceChat.Client.StoredRoomSize[sid] or 0
                        local vel = ImmersiveVoiceChat.Client.StoredVelocity[sid] or Vector(0,0,0)
                        local uw = ImmersiveVoiceChat.Client.StoredUnderwater[sid] and 1 or 0
                        local vmode = ImmersiveVoiceChat.Client.StoredVoiceMode[sid] or 1
                        local radio = ImmersiveVoiceChat.Client.StoredRadio and ImmersiveVoiceChat.Client.StoredRadio[sid] or 0
                        if radio == 1 then
                            print("[Radio-CL] Pushing to module: " .. p:Nick() .. " radio=" .. radio)
                        end
                        local px, py, pz = 0, 0, 0
                        if pos then px, py, pz = pos.x, pos.y, pos.z end
                        data[p:Nick()] = {occ, dist, px, py, pz, vel.x, vel.y, vel.z, ind, room, uw, vmode, radio}
                        break
                    end
                end
            end
            immersivevoicechat.SetPlayerOcclusions(data)
            
            -- Set listener position for 3D audio
            local lp = LocalPlayer():GetPos()
            local la = LocalPlayer():GetAngles()
            local listenerIndoor, listenerRoom = ImmersiveVoiceChat.Client:DetectIndoorLocal()
            local surfaceAbsorb = ImmersiveVoiceChat.Client:DetectSurfaceAbsorb()
            local listenerUnderwater = bit.band(util.PointContents(lp + Vector(0, 0, 64)), CONTENTS_WATER) == CONTENTS_WATER and 1 or 0
            immersivevoicechat.SetListenerPosition(lp.x, lp.y, lp.z, la.y, la.p, la.r, listenerIndoor, listenerRoom, surfaceAbsorb, listenerUnderwater)
        end
    end
    
    -- Update stats
    ImmersiveVoiceChat.Client.Stats.updatesReceived = ImmersiveVoiceChat.Client.Stats.updatesReceived + 1
    ImmersiveVoiceChat.Client.Stats.lastUpdateMs = (SysTime() - tickStart) * 1000
end)

-- Receive config sync from server
net.Receive("vo_config_sync", function()
    ImmersiveVoiceChat.Client.Config.MaxDistance = net.ReadUInt(16)
    ImmersiveVoiceChat.Client.Config.FallbackMinVolume = net.ReadFloat()
    ImmersiveVoiceChat.Client.Config.EnableVolumeFallback = net.ReadBit() == 1
    
    ImmersiveVoiceChat.Utils.DebugPrint("Config synced from server")
end)

-- Get stored occlusion for a player
function ImmersiveVoiceChat.Client:GetOcclusion(ply)
    if not IsValid(ply) then return 0 end
    
    local steamID = ply:SteamID64()
    return self.StoredOcclusion[steamID] or 0
end

-- Volume fallback for players without binary module
hook.Add("EntityEmitSound", "ImmersiveVoiceChat_Fallback", function(data)
    -- Only process if module is not loaded
    if ImmersiveVoiceChat.Client.ModuleLoaded then
        return
    end
    
    if not ImmersiveVoiceChat.Client.Config.EnableVolumeFallback then
        return
    end
    
    -- Check if this is a player voice sound
    if data.Entity and data.Entity:IsPlayer() then
        local occlusion = ImmersiveVoiceChat.Client:GetOcclusion(data.Entity)
        
        if occlusion > 0 then
            -- Calculate reduced volume
            local minVol = ImmersiveVoiceChat.Client.Config.FallbackMinVolume
            local volumeMultiplier = 1 - (occlusion * (1 - minVol))
            
            data.Volume = data.Volume * volumeMultiplier
            
            ImmersiveVoiceChat.Utils.DebugPrint(
                "Fallback: " .. ImmersiveVoiceChat.Utils.PlayerName(data.Entity) .. 
                " volume=" .. string.format("%.2f", data.Volume)
            )
            
            return true
        end
    end
end)

-- Request config sync when joining
hook.Add("InitPostEntity", "ImmersiveVoiceChat_RequestSync", function()
    timer.Simple(1, function()
        net.Start("vo_request_sync")
        net.SendToServer()
        SendVoiceModeToServer()
    end)
end)

-- Voice mode keybind: bind any key to vo_cyclemode in console
-- Example: bind n vo_cyclemode

-- Console commands
concommand.Add("vo_client_status", function()
    print("=== Immersive Voice Chat Client Status ===")
    print("Module Loaded: " .. tostring(ImmersiveVoiceChat.Client.ModuleLoaded))
    print("Enabled: " .. tostring(ImmersiveVoiceChat.Client.Enabled))
    print("Stored Occlusion Entries: " .. table.Count(ImmersiveVoiceChat.Client.StoredOcclusion))
    
    print("\nCurrent Occlusions:")
    for steamID, occlusion in pairs(ImmersiveVoiceChat.Client.StoredOcclusion) do
        print("  " .. steamID .. ": " .. string.format("%.2f", occlusion))
    end
    
    print("\nConfig:")
    print("  MaxDistance: " .. ImmersiveVoiceChat.Client.Config.MaxDistance)
    print("  FallbackMinVolume: " .. ImmersiveVoiceChat.Client.Config.FallbackMinVolume)
    print("  EnableVolumeFallback: " .. tostring(ImmersiveVoiceChat.Client.Config.EnableVolumeFallback))
end)

concommand.Add("vo_client_clear", function()
    ImmersiveVoiceChat.Client.StoredOcclusion = {}
    print("[ImmersiveVoiceChat] Client occlusion data cleared")
end)

function ImmersiveVoiceChat.Client:DetectIndoorLocal()
    local lp = LocalPlayer()
    if not IsValid(lp) then return 0, 0 end
    local pos = lp:GetPos() + Vector(0, 0, 64)
    local directions = {
        Vector(1, 0, 0), Vector(-1, 0, 0),
        Vector(0, 1, 0), Vector(0, -1, 0),
        Vector(0, 0, 1), Vector(0, 0, -1),
    }
    local hits = 0
    local totalDist = 0
    for _, dir in ipairs(directions) do
        local tr = util.TraceLine({
            start = pos,
            endpos = pos + dir * 300,
            mask = MASK_SOLID_BRUSHONLY
        })
        if tr.Hit and tr.HitWorld then
            hits = hits + 1
            totalDist = totalDist + tr.HitPos:Distance(pos)
        end
    end
    local avgRoom = 0
    if hits > 0 then avgRoom = totalDist / hits end
    return hits / #directions, avgRoom
end

-- Detect surface material at listener's feet for reverb character
-- Returns 0-1 where 0 = reflective (concrete/tile), 1 = absorptive (carpet/dirt)
function ImmersiveVoiceChat.Client:DetectSurfaceAbsorb()
    local lp = LocalPlayer()
    if not IsValid(lp) then return 0.5 end
    local pos = lp:GetPos()
    local tr = util.TraceLine({
        start = pos,
        endpos = pos + Vector(0, 0, -32),
        mask = MASK_SOLID_BRUSHONLY
    })
    if not tr.Hit then return 0.5 end
    local mat = tr.MatType
    -- Hard/reflective surfaces
    if mat == MAT_CONCRETE or mat == MAT_TILE or mat == MAT_METAL or mat == MAT_COMPUTER or mat == MAT_GLASS then
        return 0.1
    end
    -- Mid-range surfaces
    if mat == MAT_WOOD or mat == MAT_PLASTIC or mat == MAT_SAND or mat == MAT_SLOSH then
        return 0.4
    end
    -- Soft/absorptive surfaces
    if mat == MAT_FOLIAGE or mat == MAT_GRASS or mat == MAT_DIRT or mat == MAT_FLESH then
        return 0.8
    end
    -- Default
    return 0.5
end

-- Clean up disconnected player data
timer.Create("ImmersiveVoiceChat_Cleanup", 5, 0, function()
    for steamID, _ in pairs(ImmersiveVoiceChat.Client.StoredOcclusion) do
        local found = false
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) and p:SteamID64() == steamID then
                found = true
                break
            end
        end
        if not found then
            ImmersiveVoiceChat.Client.StoredOcclusion[steamID] = nil
            if ImmersiveVoiceChat.Client.StoredDistance then ImmersiveVoiceChat.Client.StoredDistance[steamID] = nil end
            if ImmersiveVoiceChat.Client.StoredPosition then ImmersiveVoiceChat.Client.StoredPosition[steamID] = nil end
            if ImmersiveVoiceChat.Client.StoredIndoor then ImmersiveVoiceChat.Client.StoredIndoor[steamID] = nil end
            if ImmersiveVoiceChat.Client.StoredRoomSize then ImmersiveVoiceChat.Client.StoredRoomSize[steamID] = nil end
            if ImmersiveVoiceChat.Client.StoredVelocity then ImmersiveVoiceChat.Client.StoredVelocity[steamID] = nil end
            if ImmersiveVoiceChat.Client.StoredUnderwater then ImmersiveVoiceChat.Client.StoredUnderwater[steamID] = nil end
            if ImmersiveVoiceChat.Client.StoredVoiceMode then ImmersiveVoiceChat.Client.StoredVoiceMode[steamID] = nil end
            if ImmersiveVoiceChat.Client.StoredRadio then ImmersiveVoiceChat.Client.StoredRadio[steamID] = nil end
        end
    end
end)

-- Heartbeat: periodically push stored data to shared memory to prevent Mumble staleness
local function PushAllDataToModule()
    if not ImmersiveVoiceChat.Client.ModuleLoaded or not immersivevoicechat then return end
    if not ImmersiveVoiceChat.Client.StoredOcclusion or table.Count(ImmersiveVoiceChat.Client.StoredOcclusion) == 0 then return end

    local data = {}
    for sid, occ in pairs(ImmersiveVoiceChat.Client.StoredOcclusion) do
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) and p:SteamID64() == sid then
                local dist = ImmersiveVoiceChat.Client.StoredDistance and ImmersiveVoiceChat.Client.StoredDistance[sid] or 0
                local pos = ImmersiveVoiceChat.Client.StoredPosition and ImmersiveVoiceChat.Client.StoredPosition[sid]
                local ind = ImmersiveVoiceChat.Client.StoredIndoor and ImmersiveVoiceChat.Client.StoredIndoor[sid] or 0
                local room = ImmersiveVoiceChat.Client.StoredRoomSize and ImmersiveVoiceChat.Client.StoredRoomSize[sid] or 0
                local vel = ImmersiveVoiceChat.Client.StoredVelocity and ImmersiveVoiceChat.Client.StoredVelocity[sid] or Vector(0,0,0)
                local uw = ImmersiveVoiceChat.Client.StoredUnderwater and ImmersiveVoiceChat.Client.StoredUnderwater[sid] and 1 or 0
                local vmode = ImmersiveVoiceChat.Client.StoredVoiceMode and ImmersiveVoiceChat.Client.StoredVoiceMode[sid] or 1
                local radio = ImmersiveVoiceChat.Client.StoredRadio and ImmersiveVoiceChat.Client.StoredRadio[sid] or 0
                local px, py, pz = 0, 0, 0
                if pos then px, py, pz = pos.x, pos.y, pos.z end
                data[p:Nick()] = {occ, dist, px, py, pz, vel.x, vel.y, vel.z, ind, room, uw, vmode, radio}
                break
            end
        end
    end
    immersivevoicechat.SetPlayerOcclusions(data)

    local lp = LocalPlayer()
    if IsValid(lp) then
        local lpp = lp:GetPos()
        local la = lp:GetAngles()
        local listenerIndoor, listenerRoom = ImmersiveVoiceChat.Client:DetectIndoorLocal()
        local surfaceAbsorb = ImmersiveVoiceChat.Client:DetectSurfaceAbsorb()
        local listenerUnderwater = bit.band(util.PointContents(lpp + Vector(0, 0, 64)), CONTENTS_WATER) == CONTENTS_WATER and 1 or 0
        immersivevoicechat.SetListenerPosition(lpp.x, lpp.y, lpp.z, la.y, la.p, la.r, listenerIndoor, listenerRoom, surfaceAbsorb, listenerUnderwater)
    end
end

timer.Create("ImmersiveVoiceChat_Heartbeat", 0.5, 0, function()
    PushAllDataToModule()
end)

-- HUD Indicator: shows occlusion level for the player you're looking at
local function DrawOcclusionHUD()
    if not ImmersiveVoiceChat.Client.HUDEnabled then return end
    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    -- Find the player you're looking at
    local tr = lp:GetEyeTrace()
    local target = nil
    if IsValid(tr.Entity) and tr.Entity:IsPlayer() and tr.Entity ~= lp then
        target = tr.Entity
    end

    if not target then
        -- Fallback: show closest speaking player
        local bestDist = math.huge
        for steamID, occ in pairs(ImmersiveVoiceChat.Client.StoredOcclusion) do
            for _, p in ipairs(player.GetAll()) do
                if IsValid(p) and p:SteamID64() == steamID then
                    local d = lp:GetPos():Distance(p:GetPos())
                    if d < bestDist then
                        bestDist = d
                        target = p
                    end
                    break
                end
            end
        end
    end

    if not target then return end

    local steamID = target:SteamID64()
    local occ = ImmersiveVoiceChat.Client.StoredOcclusion[steamID] or 0
    local dist = ImmersiveVoiceChat.Client.StoredDistance and ImmersiveVoiceChat.Client.StoredDistance[steamID] or 0

    local scrW, scrH = ScrW(), ScrH()
    local boxW, boxH = 260, 80
    local x, y = scrW / 2 - boxW / 2, scrH - boxH - 20

    -- Background
    draw.RoundedBox(8, x, y, boxW, boxH, Color(20, 20, 20, 200))

    -- Name
    draw.SimpleText(target:Nick(), "DermaDefaultBold", x + 10, y + 8, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    -- Occlusion bar
    local barX, barY = x + 10, y + 28
    local barW, barH = boxW - 20, 16
    draw.RoundedBox(4, barX, barY, barW, barH, Color(40, 40, 40))

    local fillW = barW * math.Clamp(1 - occ, 0, 1)
    local barColor = Color(0, 200, 80)
    if occ > 0.5 then barColor = Color(255, 200, 0) end
    if occ > 0.8 then barColor = Color(255, 60, 60) end
    draw.RoundedBox(4, barX, barY, fillW, barH, barColor)

    draw.SimpleText(string.format("Occlusion: %.0f%%", occ * 100), "DermaDefault", x + 10, y + 50, Color(200, 200, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText(string.format("Dist: %.0f", dist), "DermaDefault", x + boxW - 10, y + 50, Color(150, 150, 150), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
end
hook.Add("HUDPaint", "ImmersiveVoiceChat_HUD", DrawOcclusionHUD)

-- Console commands for HUD
concommand.Add("vo_hud", function()
    ImmersiveVoiceChat.Client.HUDEnabled = not ImmersiveVoiceChat.Client.HUDEnabled
    print("[ImmersiveVoiceChat] HUD: " .. tostring(ImmersiveVoiceChat.Client.HUDEnabled))
end)

-- Performance profiler
local vo_profiler = CreateConVar("vo_profiler", "0", FCVAR_ARCHIVE, "Show Immersive Voice Chat performance profiler")

local function DrawProfiler()
    if not vo_profiler:GetBool() then return end
    local cli = ImmersiveVoiceChat.Client.Stats or {}

    local lines = {
        "=== Immersive Voice Chat Profiler ===",
        string.format("Client updates:  %d (last %.2f ms)", cli.updatesReceived or 0, cli.lastUpdateMs or 0),
        "Module: " .. tostring(ImmersiveVoiceChat.Client.ModuleLoaded),
        "Stored entries:  " .. table.Count(ImmersiveVoiceChat.Client.StoredOcclusion),
    }

    local x, y = 10, 10
    surface.SetDrawColor(20, 20, 20, 200)
    surface.DrawRect(x, y, 320, #lines * 18 + 8)

    for i, line in ipairs(lines) do
        draw.SimpleText(line, "DermaDefault", x + 8, y + 4 + (i - 1) * 18, Color(0, 255, 180), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
end
hook.Add("HUDPaint", "ImmersiveVoiceChat_Profiler", DrawProfiler)

-- Voice mode icons
local MODE_ICONS = {
    [0] = Material("immersivevoicechat/whisper.png", "smooth mips unlitgeneric"),
    [1] = Material("immersivevoicechat/talk.png", "smooth mips unlitgeneric"),
    [2] = Material("immersivevoicechat/yell.png", "smooth mips unlitgeneric"),
}

-- Voice mode HUD indicator (fades out after cycling)
local function DrawVoiceModeHUD()
    local elapsed = CurTime() - modeChangeTime
    if elapsed > MODE_FADE_TIME then return end

    local alpha = math.Clamp(1 - (elapsed / MODE_FADE_TIME), 0, 1)
    local mode = ImmersiveVoiceChat.Client.VoiceMode
    local icon = MODE_ICONS[mode]
    if not icon then return end

    local scrW, scrH = ScrW(), ScrH()
    local size = 64
    local iconAlpha = math.Round(alpha * 255)

    surface.SetDrawColor(255, 255, 255, iconAlpha)
    surface.SetMaterial(icon)
    surface.DrawTexturedRect(scrW / 2 - size / 2, scrH / 2 + 50, size, size)
end
hook.Add("HUDPaint", "ImmersiveVoiceChat_VoiceMode", DrawVoiceModeHUD)

function ImmersiveVoiceChat.Client:OpenSettingsMenu()
    if IsValid(ImmersiveVoiceChat.Client.SettingsFrame) then
        ImmersiveVoiceChat.Client.SettingsFrame:Remove()
    end

    local frameW, frameH = 620, 520
    local sidebarW = 150

    local frame = vgui.Create("DFrame")
    frame:SetSize(frameW, frameH)
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(true)
    frame:MakePopup()
    frame.Paint = function(self, w, h)
        draw.RoundedBox(10, 0, 0, w, h, VO_UI.border)
        draw.RoundedBox(10, 1, 1, w - 2, h - 2, VO_UI.bg)
    end
    ImmersiveVoiceChat.Client.SettingsFrame = frame

    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetSize(28, 28)
    closeBtn:SetPos(frameW - 34, 8)
    closeBtn:SetText("")
    closeBtn.Paint = function(self, w, h)
        local col = self:IsHovered() and Color(255, 70, 70) or VO_UI.dimText
        draw.SimpleText("×", "VO_UI_Title", w / 2, h / 2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    closeBtn.DoClick = function() frame:Remove() end

    local titleLabel = vgui.Create("DPanel", frame)
    titleLabel:SetPos(16, 8)
    titleLabel:SetSize(200, 28)
    titleLabel.Paint = function(self, w, h)
        draw.SimpleText("Immersive Voice Chat", "VO_UI_Title", 0, 4, VO_UI.text)
    end

    local sidebar = vgui.Create("DPanel", frame)
    sidebar:SetPos(0, 44)
    sidebar:SetSize(sidebarW, frameH - 44)
    sidebar:DockPadding(0, 4, 0, 4)
    sidebar.Paint = function(self, w, h)
        draw.RoundedBoxEx(10, 0, 0, w, h, VO_UI.sidebar, false, false, true, false)
        surface.SetDrawColor(VO_UI.border)
        surface.DrawLine(w - 1, 0, w - 1, h - 10)
    end

    local contentContainer = vgui.Create("DPanel", frame)
    contentContainer:SetPos(sidebarW, 44)
    contentContainer:SetSize(frameW - sidebarW, frameH - 44)
    contentContainer.Paint = function(self, w, h)
        draw.RoundedBoxEx(10, 0, 0, w, h, VO_UI.bg, false, false, false, true)
    end

    local categories = {
        { name = "GENERAL" },
        { name = "AUDIO" },
        { name = "OCCLUSION" },
        { name = "DISPLAY" },
    }

    local activeTab = 1
    local contentPanels = {}

    -- Build each tab's scroll panel
    for i, cat in ipairs(categories) do
        local scroll = vgui.Create("DPanel", contentContainer)
        scroll:Dock(FILL)
        scroll:DockMargin(0, 4, 0, 0)
        scroll:SetVisible(i == 1)
        scroll.Paint = function() end
        contentPanels[i] = scroll

        if cat.name == "GENERAL" then
            CreateSectionHeader(scroll, "Interface")
            CreatePillToggle(scroll, "HUD Indicator", "Show occlusion level on-screen",
                function() return ImmersiveVoiceChat.Client.HUDEnabled end,
                function(v) ImmersiveVoiceChat.Client.HUDEnabled = v end)

            CreateSectionHeader(scroll, "Debug")
            CreatePillToggle(scroll, "Debug Mode", "Enable server debug output",
                function() return ImmersiveVoiceChat.Config.DebugMode end,
                function(v) ImmersiveVoiceChat.Config.DebugMode = v end)
            CreatePillToggle(scroll, "Draw Traces", "Visualize trace lines (sv_cheats 1)",
                function() return ImmersiveVoiceChat.Config.DrawDebugTraces end,
                function(v) ImmersiveVoiceChat.Config.DrawDebugTraces = v end)

        elseif cat.name == "AUDIO" then
            CreateSectionHeader(scroll, "Voice Mode")
            CreateThinSlider(scroll, "Whisper Distance", "Max voice range multiplier while whispering",
                function() return ImmersiveVoiceChat.Config.VoiceModes[0].maxDistMult end,
                function(v) ImmersiveVoiceChat.Config.VoiceModes[0].maxDistMult = v; RunConsoleCommand("vo_whisper_dist", tostring(v)) end,
                0.1, 1.0, 2)
            CreateThinSlider(scroll, "Whisper Occlusion", "Wall muffling multiplier while whispering",
                function() return ImmersiveVoiceChat.Config.VoiceModes[0].occlusionMult end,
                function(v) ImmersiveVoiceChat.Config.VoiceModes[0].occlusionMult = v; RunConsoleCommand("vo_whisper_occ", tostring(v)) end,
                0.1, 3.0, 2)
            CreateThinSlider(scroll, "Yell Distance", "Max voice range multiplier while yelling",
                function() return ImmersiveVoiceChat.Config.VoiceModes[2].maxDistMult end,
                function(v) ImmersiveVoiceChat.Config.VoiceModes[2].maxDistMult = v; RunConsoleCommand("vo_yell_dist", tostring(v)) end,
                1.0, 5.0, 2)
            CreateThinSlider(scroll, "Yell Occlusion", "Wall muffling multiplier while yelling",
                function() return ImmersiveVoiceChat.Config.VoiceModes[2].occlusionMult end,
                function(v) ImmersiveVoiceChat.Config.VoiceModes[2].occlusionMult = v; RunConsoleCommand("vo_yell_occ", tostring(v)) end,
                0.1, 2.0, 2)

            CreateSectionHeader(scroll, "Distance")
            CreateThinSlider(scroll, "Max Distance", "Maximum voice range in units",
                function() return ImmersiveVoiceChat.Config.MaxDistance end,
                function(v) ImmersiveVoiceChat.Config.MaxDistance = v; RunConsoleCommand("vo_maxdistance", tostring(v)) end,
                100, 5000, 0)
            CreateThinSlider(scroll, "Trace Interval", "Occlusion check frequency (seconds)",
                function() return ImmersiveVoiceChat.Config.TraceInterval end,
                function(v) ImmersiveVoiceChat.Config.TraceInterval = v; RunConsoleCommand("vo_traceinterval", tostring(v)) end,
                0.1, 2.0, 2)

        elseif cat.name == "OCCLUSION" then
            CreateSectionHeader(scroll, "Wall Effects")
            CreateThinSlider(scroll, "Wall Penalty", "Occlusion added per wall hit",
                function() return ImmersiveVoiceChat.Config.WallPenalty end,
                function(v) ImmersiveVoiceChat.Config.WallPenalty = v; RunConsoleCommand("vo_wallpenalty", tostring(v)) end,
                0, 1, 2)
            CreateThinSlider(scroll, "Glass Penalty", "Occlusion added for glass",
                function() return ImmersiveVoiceChat.Config.GlassPenalty end,
                function(v) ImmersiveVoiceChat.Config.GlassPenalty = v; RunConsoleCommand("vo_glasspenalty", tostring(v)) end,
                0, 0.5, 2)
            CreateThinSlider(scroll, "Thick Wall Bonus", "Extra occlusion for thick walls",
                function() return ImmersiveVoiceChat.Config.ThickWallBonus end,
                function(v) ImmersiveVoiceChat.Config.ThickWallBonus = v; RunConsoleCommand("vo_thickwallbonus", tostring(v)) end,
                0, 0.5, 2)

        elseif cat.name == "DISPLAY" then
            CreateSectionHeader(scroll, "Profiling")
            CreatePillToggle(scroll, "Profiler", "Show performance statistics overlay",
                function() return vo_profiler:GetBool() end,
                function(v) RunConsoleCommand("vo_profiler", v and "1" or "0") end)
        end
    end

    -- Sidebar tabs
    for i, cat in ipairs(categories) do
        local tab = vgui.Create("DPanel", sidebar)
        tab:Dock(TOP)
        tab:DockMargin(0, 2, 0, 2)
        tab:SetTall(40)
        tab:SetMouseInputEnabled(true)
        local idx = i

        tab.Paint = function(self, w, h)
            local isActive = (activeTab == idx)
            if isActive then
                draw.RoundedBox(h / 2, 4, 2, w - 8, h - 4, VO_UI.accent)
            elseif self:IsHovered() then
                draw.RoundedBox(h / 2, 4, 2, w - 8, h - 4, VO_UI.hover)
            end

            local font = isActive and "VO_UI_TabActive" or "VO_UI_Tab"
            local col = isActive and Color(255, 255, 255) or VO_UI.dimText
            draw.SimpleText(cat.name, font, 14, h / 2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        tab.OnMousePressed = function(self, mcode)
            if mcode ~= MOUSE_LEFT then return end
            activeTab = idx
            for j, panel in ipairs(contentPanels) do
                panel:SetVisible(j == idx)
            end
        end
    end
end

concommand.Add("vo_settings", function()
    ImmersiveVoiceChat.Client:OpenSettingsMenu()
end)

concommand.Add("vo_radio_diag", function()
    print("=== Radio Client Diagnostics ===")
    print("Module Loaded: " .. tostring(ImmersiveVoiceChat.Client.ModuleLoaded))
    print("immersivevoicechat global: " .. tostring(immersivevoicechat ~= nil))
    if immersivevoicechat and immersivevoicechat.GetStatus then
        local status = immersivevoicechat.GetStatus()
        print("Module status: " .. util.TableToJSON(status, true))
    end
    print("\nStoredRadio:")
    if ImmersiveVoiceChat.Client.StoredRadio then
        for sid, radio in pairs(ImmersiveVoiceChat.Client.StoredRadio) do
            local name = "unknown"
            for _, p in ipairs(player.GetAll()) do
                if IsValid(p) and p:SteamID64() == sid then
                    name = p:Nick()
                    break
                end
            end
            print("  " .. name .. " (" .. sid .. "): radio=" .. tostring(radio))
        end
    else
        print("  (none)")
    end
    print("\nStoredOcclusion:")
    for sid, occ in pairs(ImmersiveVoiceChat.Client.StoredOcclusion) do
        local name = "unknown"
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) and p:SteamID64() == sid then
                name = p:Nick()
                break
            end
        end
        print("  " .. name .. ": occ=" .. string.format("%.2f", occ))
    end
end)
