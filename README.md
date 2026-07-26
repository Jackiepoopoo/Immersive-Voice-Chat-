# Immersive Voice Chat for Garry's Mod

Adds realistic sound physics to voice chat. When walls or obstacles are between players, voice becomes muffled.

## Features

- **Real-time occlusion detection** - Server-side traceline checks detect walls between players
- **Audio processing** - Binary module applies low-pass filters for realistic muffling effects
- **Graceful fallback** - Works without the binary module using volume reduction
- **Configurable** - Adjustable occlusion strength, distances, and effect parameters
- **Performance optimized** - Efficient traceline batching and caching

## Installation

### Workshop

Subscribe to the Steam Workshop item for the Lua addon and materials.

### Binary Modules (Required)

The binary module provides audio processing and Mumble integration. Download the zip and run `install.bat`:

1. Download `voiceocclusion.zip` from [Releases](https://github.com/Jackiepoopoo/Immersive-Voice-Chat-/releases)
2. Extract and run `install.bat`
3. Restart Garry's Mod (and Mumble if using it)

## Configuration

### Server Console Commands

| Command | Description |
|---------|-------------|
| `vo_maxdistance <value>` | Set maximum voice range (default: 1200) |
| `vo_traceinterval <value>` | Set traceline check interval (default: 0.3) |
| `vo_debug` | Toggle debug output |
| `vo_status` | Show addon status |
| `vo_config` | Show current configuration |

### Client Console Commands

| Command | Description |
|---------|-------------|
| `vo_settings` | Open settings panel |
| `vo_toggle` | Toggle occlusion on/off |
| `vo_loadmodule` | Load binary module |
| `vo_unloadmodule` | Unload binary module |
| `vo_modulestatus` | Show module status |

### Configuration File

Edit `lua/immersivevoicechat/config.lua` to change default settings.

## How It Works

1. **Detection** - Server runs tracelines between speaking players and listeners
2. **Calculation** - Occlusion level is calculated based on walls hit and distance
3. **Transmission** - Occlusion data is sent to client via net messages
4. **Processing** - Client applies audio effects (or volume fallback)

## Performance

- Tracelines are batched and throttled (default: every 0.3 seconds)
- Only checks players within maximum distance
- Net messages are only sent when occlusion changes significantly
- Configurable limits on checks per tick

## Building from Source

See `cpp/BUILD_INSTRUCTIONS.txt` for detailed build instructions.

### Requirements

- CMake 3.15+
- C++17 compiler
- Lua 5.1 headers
- gmod-module-base SDK (optional)

## Compatibility

- Works with all game modes
- Compatible with other voice addons
- No server-side entities required
- Client-side only processing

## License

MIT License

## Credits

- Garry's Mod community
- Valve Source SDK
- gmod-module-base
