-- Voice Occlusion Client Module Interface
-- Handles loading and interfacing with the binary module

VoiceOcclusion.Client.ModuleLoaded = false
VoiceOcclusion.Client.ModuleError = nil

function VoiceOcclusion.Client:LoadModule()
    if self.ModuleLoaded then
        return true
    end

    -- List all files in lua/bin/ to debug
    local files = file.Find("lua/bin/*voiceocclusion*", "LUA")
    print("[VoiceOcclusion] Searching for module files...")
    for _, f in ipairs(files) do
        print("[VoiceOcclusion] Found: " .. f)
    end

    -- Try each possible module name
    local namesToTry = {
        "voiceocclusion",
        "voiceocclusion_win32",
        "voiceocclusion_win64",
    }

    for _, name in ipairs(namesToTry) do
        print("[VoiceOcclusion] Trying require: " .. name)
        local success, result = pcall(require, name)

        if success and result ~= false then
            self.ModuleLoaded = true
            self.ModuleError = nil

            if voiceocclusion then
                print("[VoiceOcclusion] Module API found")
                if voiceocclusion.Initialize then
                    voiceocclusion.Initialize()
                end
            else
                print("[VoiceOcclusion] Module loaded but voiceocclusion table not found")
            end

            net.Start("vo_module_status")
                net.WriteBit(1)
            net.SendToServer()

            print("[VoiceOcclusion] Binary module loaded successfully via: " .. name)
            return true
        else
            print("[VoiceOcclusion] Failed: " .. tostring(result))
        end
    end

    -- Nothing worked
    self.ModuleLoaded = false
    self.ModuleError = "No matching binary module found"

    net.Start("vo_module_status")
        net.WriteBit(0)
    net.SendToServer()

    print("[VoiceOcclusion] Binary module not found, using fallback mode")
    return false
end

function VoiceOcclusion.Client:UnloadModule()
    if not self.ModuleLoaded then
        return
    end

    if voiceocclusion and voiceocclusion.Cleanup then
        voiceocclusion.Cleanup()
    end

    self.ModuleLoaded = false

    net.Start("vo_module_status")
        net.WriteBit(0)
    net.SendToServer()

    print("[VoiceOcclusion] Binary module unloaded")
end

function VoiceOcclusion.Client:GetModuleStatus()
    return {
        loaded = self.ModuleLoaded,
        error = self.ModuleError,
        hasAPI = voiceocclusion ~= nil
    }
end

function VoiceOcclusion.Client:SetOcclusion(level)
    if not self.ModuleLoaded or not voiceocclusion then
        return false
    end
    if voiceocclusion.SetOcclusion then
        voiceocclusion.SetOcclusion(level)
        return true
    end
    return false
end

function VoiceOcclusion.Client:SetEnabled(enabled)
    if not self.ModuleLoaded or not voiceocclusion then
        return false
    end
    if voiceocclusion.SetEnabled then
        voiceocclusion.SetEnabled(enabled)
        return true
    end
    return false
end

function VoiceOcclusion.Client:SetStrength(strength)
    if not self.ModuleLoaded or not voiceocclusion then
        return false
    end
    if voiceocclusion.SetStrength then
        voiceocclusion.SetStrength(strength)
        return true
    end
    return false
end

hook.Add("InitPostEntity", "VoiceOcclusion_LoadModule", function()
    timer.Simple(2, function()
        VoiceOcclusion.Client:LoadModule()
    end)
end)

concommand.Add("vo_loadmodule", function()
    VoiceOcclusion.Client:LoadModule()
end)

concommand.Add("vo_unloadmodule", function()
    VoiceOcclusion.Client:UnloadModule()
end)

concommand.Add("vo_modulestatus", function()
    local status = VoiceOcclusion.Client:GetModuleStatus()
    print("=== Voice Occlusion Module Status ===")
    print("Loaded: " .. tostring(status.loaded))
    print("Has API: " .. tostring(status.hasAPI))
    if status.error then
        print("Error: " .. status.error)
    end
end)
