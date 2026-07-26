-- Immersive Voice Chat Client Module Interface
-- Handles loading and interfacing with the binary module

ImmersiveVoiceChat.Client.ModuleLoaded = false
ImmersiveVoiceChat.Client.ModuleError = nil

function ImmersiveVoiceChat.Client:LoadModule()
    if self.ModuleLoaded then
        return true
    end

    -- List all files in lua/bin/ to debug
    local files = file.Find("lua/bin/*immersivevoicechat*", "LUA")
    print("[ImmersiveVoiceChat] Searching for module files...")
    for _, f in ipairs(files) do
        print("[ImmersiveVoiceChat] Found: " .. f)
    end

    -- Try each possible module name
    local namesToTry = {
        "immersivevoicechat",
        "immersivevoicechat_win32",
        "immersivevoicechat_win64",
    }

    for _, name in ipairs(namesToTry) do
        print("[ImmersiveVoiceChat] Trying require: " .. name)
        local success, result = pcall(require, name)

        if success and result ~= false then
            self.ModuleLoaded = true
            self.ModuleError = nil

            if immersivevoicechat then
                print("[ImmersiveVoiceChat] Module API found")
                if immersivevoicechat.Initialize then
                    immersivevoicechat.Initialize()
                end
            else
                print("[ImmersiveVoiceChat] Module loaded but immersivevoicechat table not found")
            end

            net.Start("vo_module_status")
                net.WriteBit(1)
            net.SendToServer()

            print("[ImmersiveVoiceChat] Binary module loaded successfully via: " .. name)
            return true
        else
            print("[ImmersiveVoiceChat] Failed: " .. tostring(result))
        end
    end

    -- Nothing worked
    self.ModuleLoaded = false
    self.ModuleError = "No matching binary module found"

    net.Start("vo_module_status")
        net.WriteBit(0)
    net.SendToServer()

    print("[ImmersiveVoiceChat] Binary module not found, using fallback mode")
    return false
end

function ImmersiveVoiceChat.Client:UnloadModule()
    if not self.ModuleLoaded then
        return
    end

    if immersivevoicechat and immersivevoicechat.Cleanup then
        immersivevoicechat.Cleanup()
    end

    self.ModuleLoaded = false

    net.Start("vo_module_status")
        net.WriteBit(0)
    net.SendToServer()

    print("[ImmersiveVoiceChat] Binary module unloaded")
end

function ImmersiveVoiceChat.Client:GetModuleStatus()
    return {
        loaded = self.ModuleLoaded,
        error = self.ModuleError,
        hasAPI = immersivevoicechat ~= nil
    }
end

function ImmersiveVoiceChat.Client:SetOcclusion(level)
    if not self.ModuleLoaded or not immersivevoicechat then
        return false
    end
    if immersivevoicechat.SetOcclusion then
        immersivevoicechat.SetOcclusion(level)
        return true
    end
    return false
end

function ImmersiveVoiceChat.Client:SetEnabled(enabled)
    if not self.ModuleLoaded or not immersivevoicechat then
        return false
    end
    if immersivevoicechat.SetEnabled then
        immersivevoicechat.SetEnabled(enabled)
        return true
    end
    return false
end

function ImmersiveVoiceChat.Client:SetStrength(strength)
    if not self.ModuleLoaded or not immersivevoicechat then
        return false
    end
    if immersivevoicechat.SetStrength then
        immersivevoicechat.SetStrength(strength)
        return true
    end
    return false
end

hook.Add("InitPostEntity", "ImmersiveVoiceChat_LoadModule", function()
    timer.Simple(2, function()
        ImmersiveVoiceChat.Client:LoadModule()
    end)
end)

concommand.Add("vo_loadmodule", function()
    ImmersiveVoiceChat.Client:LoadModule()
end)

concommand.Add("vo_unloadmodule", function()
    ImmersiveVoiceChat.Client:UnloadModule()
end)

concommand.Add("vo_modulestatus", function()
    local status = ImmersiveVoiceChat.Client:GetModuleStatus()
    print("=== Immersive Voice Chat Module Status ===")
    print("Loaded: " .. tostring(status.loaded))
    print("Has API: " .. tostring(status.hasAPI))
    if status.error then
        print("Error: " .. status.error)
    end
end)
