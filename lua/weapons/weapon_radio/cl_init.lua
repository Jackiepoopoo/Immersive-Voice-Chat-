include("shared.lua")

SWEP.PrintName = "Radio"
SWEP.SwayScale = 1.0

local channelColors = {
    Color(255, 100, 100),
    Color(100, 255, 100),
    Color(100, 100, 255),
    Color(255, 255, 100),
    Color(255, 100, 255),
    Color(100, 255, 255),
    Color(255, 180, 100),
    Color(180, 100, 255),
    Color(200, 200, 200),
}

local transmitNoise = 0
local targetNoise = 0

local clientChannel = 1

local function SyncChannelToServer(ch)
    net.Start("vo_radio_channel")
        net.WriteUInt(ch, 4)
    net.SendToServer()
end

function SWEP:Deploy()
    clientChannel = 1
    self:SetTransmitting(false)
    SyncChannelToServer(1)
end

function SWEP:Holster()
    if self:GetTransmitting() then
        self:StopTransmit()
    end
    return true
end

function SWEP:PrimaryAttack()
    if not IsFirstTimePredicted() then return end
    self:SetNextPrimaryFire(CurTime() + 0.1)
end

function SWEP:SecondaryAttack()
end

function SWEP:Reload()
end

function SWEP:Think()
    if not IsFirstTimePredicted() then return end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    if owner ~= LocalPlayer() then return end

    local wantsTransmit = owner:KeyDown(IN_ATTACK)

    if wantsTransmit and not self:GetTransmitting() then
        self:StartTransmit()
    elseif not wantsTransmit and self:GetTransmitting() then
        self:StopTransmit()
    end
end

function SWEP:StartTransmit()
    self:SetTransmitting(true)
    net.Start("vo_radio_transmit")
        net.WriteBool(true)
    net.SendToServer()
    targetNoise = 1.0
end

function SWEP:StopTransmit()
    self:SetTransmitting(false)
    net.Start("vo_radio_transmit")
        net.WriteBool(false)
    net.SendToServer()
    targetNoise = 0.0
end

function SWEP:ScrollUp()
    clientChannel = clientChannel + 1
    if clientChannel > self.MaxChannels then
        clientChannel = 1
    end
    SyncChannelToServer(clientChannel)
    surface.PlaySound("buttons/lightswitch2.wav")
end

function SWEP:ScrollDown()
    clientChannel = clientChannel - 1
    if clientChannel < 1 then
        clientChannel = self.MaxChannels
    end
    SyncChannelToServer(clientChannel)
    surface.PlaySound("buttons/lightswitch2.wav")
end

function SWEP:DoScroll(direction)
    if direction > 0 then
        self:ScrollUp()
    else
        self:ScrollDown()
    end
end

function SWEP:DrawHUD()
    local owner = self:GetOwner()
    if not IsValid(owner) or owner ~= LocalPlayer() then return end

    local scrW, scrH = ScrW(), ScrH()
    local panelW, panelH = 260, 120
    local panelX = scrW - panelW - 20
    local panelY = scrH - panelH - 20

    local col = channelColors[clientChannel] or color_white

    draw.RoundedBox(12, panelX, panelY, panelW, panelH, Color(20, 20, 20, 200))

    draw.SimpleText("CH " .. clientChannel, "DermaLarge", panelX + panelW / 2, panelY + 22, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    local transmitY = panelY + 55
    if self:GetTransmitting() then
        transmitNoise = Lerp(FrameTime() * 8, transmitNoise, targetNoise)
        local pulse = math.sin(CurTime() * 6) * 0.3 + 0.7
        local indicatorCol = Color(255, 50, 50, 255 * pulse)
        draw.RoundedBox(6, panelX + panelW / 2 - 40, transmitY, 80, 24, Color(60, 20, 20, 220))
        draw.SimpleText("TX", "DermaDefaultBold", panelX + panelW / 2, transmitY + 12, indicatorCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(255, 50, 50, 80 * pulse)
        for i = 1, 3 do
            surface.DrawOutlinedRect(panelX - i, panelY - i, panelW + i * 2, panelH + i * 2, 1)
        end
    else
        transmitNoise = Lerp(FrameTime() * 8, transmitNoise, targetNoise)
        draw.RoundedBox(6, panelX + panelW / 2 - 40, transmitY, 80, 24, Color(30, 30, 30, 200))
        draw.SimpleText("IDLE", "DermaDefaultBold", panelX + panelW / 2, transmitY + 12, Color(120, 120, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    draw.SimpleText("Scroll: Channel", "DermaDefault", panelX + panelW / 2, panelY + panelH - 14, Color(150, 150, 150, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function SWEP:DrawWorldModel()
    local owner = self:GetOwner()
    if not IsValid(owner) then
        self:DrawModel()
        return
    end

    local boneid = owner:LookupBone("ValveBiped.Bip01_R_Hand")
    if not boneid then
        self:DrawModel()
        return
    end

    local matrix = owner:GetBoneMatrix(boneid)
    if not matrix then
        self:DrawModel()
        return
    end

    local pos, ang = matrix:GetTranslation(), matrix:GetAngles()
    self:SetRenderOrigin(pos + ang:Forward() * 4 + ang:Right() * 2 + ang:Up() * -2)
    self:SetRenderAngles(Angle(ang.p, ang.y + 180, ang.r))
    self:SetupBones()
    self:DrawModel()
end

hook.Add("PlayerBindPress", "ImmersiveVoiceChat_RadioScroll", function(ply, bind, pressed)
    if not IsValid(ply) or ply ~= LocalPlayer() then return end
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) or wep:GetClass() ~= "weapon_radio" then return end

    if bind == "invnext" then
        wep:DoScroll(-1)
        return true
    elseif bind == "invprev" then
        wep:DoScroll(1)
        return true
    end
end)
