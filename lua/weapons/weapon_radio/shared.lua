SWEP.Base = "weapon_base"
SWEP.PrintName = "Radio"
SWEP.Author = "Immersive Voice Chat"
SWEP.Instructions = "Left Click: Transmit | Scroll: Change Channel"
SWEP.Category = "Immersive Voice Chat"

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.Weight = 5
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false

SWEP.Slot = 5
SWEP.SlotPos = 1
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false

SWEP.ViewModel = "models/weapons/v_pistol.mdl"
SWEP.WorldModel = "models/weapons/w_pistol.mdl"
SWEP.HoldType = "pistol"

SWEP.MaxChannels = 9

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:SetupDataTables()
    self:NetworkVar("Bool", 0, "Transmitting")
    self:NetworkVar("Int", 0, "Channel")
end

function SWEP:PrimaryAttack()
    if not IsFirstTimePredicted() then return end
    self:SetNextPrimaryFire(CurTime() + 0.1)
end

function SWEP:SecondaryAttack()
end

function SWEP:Reload()
end
