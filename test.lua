-- Immersive Voice Chat Test Script
-- Run this in Garry's Mod to verify the addon loads correctly

print("=== Immersive Voice Chat Test ===")

-- Check if addon is loaded
if ImmersiveVoiceChat then
    print("✓ ImmersiveVoiceChat global exists")
    print("  Version: " .. (ImmersiveVoiceChat.Version or "unknown"))
else
    print("✗ ImmersiveVoiceChat global not found")
    print("  Make sure the addon is installed correctly")
    return
end

-- Check config
if ImmersiveVoiceChat.Config then
    print("✓ Configuration loaded")
    print("  MaxDistance: " .. ImmersiveVoiceChat.Config.MaxDistance)
    print("  TraceInterval: " .. ImmersiveVoiceChat.Config.TraceInterval)
else
    print("✗ Configuration not found")
end

-- Check server-side
if SERVER then
    if ImmersiveVoiceChat.Server then
        print("✓ Server-side module loaded")
    else
        print("✗ Server-side module not found")
    end
end

-- Check client-side
if CLIENT then
    if ImmersiveVoiceChat.Client then
        print("✓ Client-side module loaded")
        print("  Module loaded: " .. tostring(ImmersiveVoiceChat.Client.ModuleLoaded))
    else
        print("✗ Client-side module not found")
    end
    
    -- Test binary module
    if immersivevoicechat then
        print("✓ Binary module available")
        local status = immersivevoicechat.GetStatus()
        print("  Version: " .. (status.version or "unknown"))
        print("  Initialized: " .. tostring(status.initialized))
    else
        print("! Binary module not loaded (using fallback mode)")
    end
end

-- Check utilities
if ImmersiveVoiceChat.Utils then
    print("✓ Utilities loaded")
else
    print("✗ Utilities not found")
end

print("\n=== Test Complete ===")

if CLIENT then
    print("\nConsole commands:")
    print("  vo_settings - Open settings panel")
    print("  vo_toggle - Toggle occlusion")
    print("  vo_client_status - Show client status")
    print("  vo_loadmodule - Load binary module")
end

if SERVER then
    print("\nConsole commands:")
    print("  vo_status - Show addon status")
    print("  vo_config - Show configuration")
    print("  vo_debug - Toggle debug mode")
    print("  vo_resync - Force resync all players")
end
