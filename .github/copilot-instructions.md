# Copilot Instructions for sm-plugin-Laser

## Repository Overview

This repository contains a SourceMod plugin called "Laser" that creates dynamic laser projectiles for Source engine games. The plugin allows administrators to spawn moving laser entities that can damage players and follow various movement patterns (aim-directed, linear, random patterns).

### Key Features
- Creates visual laser projectiles using Source engine entities
- Multiple movement modes: aim-directed, linear, random, and repeating patterns
- Collision detection with damage dealing
- Sound and visual effects with custom models and materials
- Timer-based lifecycle management
- Admin command interface

## Technical Environment

### Core Technologies
- **Language**: SourcePawn (SourceMod scripting language)
- **Platform**: SourceMod 1.11.0+ (Source engine games)
- **Build System**: SourceKnight (modern SourceMod build tool)
- **CI/CD**: GitHub Actions with automated building and releasing

### Dependencies
- SourceMod 1.11.0-git6917 (automatically managed by SourceKnight)
- MultiColors plugin for colored chat messages
- Source engine game server (CS:GO/CS2)

### File Structure
```
├── .github/workflows/ci.yml          # CI/CD pipeline
├── addons/sourcemod/scripting/       # SourcePawn source code
│   └── Laser.sp                      # Main plugin file
├── materials/models/nide/laser/      # Texture files (.vmt, .vtf)
├── models/nide/laser/                # 3D model files (.mdl, .phy, .vvd, .vtx)
├── sound/nide/                       # Sound effects (.wav)
└── sourceknight.yaml                 # Build configuration
```

## Build System (SourceKnight)

### Building the Plugin

**Primary Build Method (CI/CD):**
The repository uses SourceKnight via GitHub Actions for automated building. Local builds require the SourceKnight tool but installation may vary by environment.

**GitHub Actions Build:**
```yaml
- name: Build sourcemod plugin
  uses: maxime1907/action-sourceknight@v1
  with:
    cmd: build
```

**Local Development:**
For local development, you'll need:
1. SourceMod compiler (spcomp) from SourceMod development package
2. MultiColors include files from: https://github.com/srcdslab/sm-plugin-MultiColors
3. Manual compilation: `spcomp Laser.sp` (with proper include paths)

### Configuration (sourceknight.yaml)
- Automatically downloads SourceMod 1.11.0-git6917 compiler and includes
- Manages MultiColors dependency via Git clone
- Outputs compiled .smx files to `/addons/sourcemod/plugins`
- Packages models, materials, and sounds for distribution
- Target plugin: `Laser.sp` → `Laser.smx`

### GitHub Actions Workflow
- Automatically builds on push/PR to main/master branches
- Uses `maxime1907/action-sourceknight@v1` action for compilation
- Creates release packages with all assets (plugins + models + materials + sounds)
- Supports both tagged releases and latest snapshots
- Packages everything into tar.gz for easy deployment

## Code Structure and Patterns

### Main Plugin File: `Laser.sp`

#### Key Components
1. **Entity System**: Uses Source engine entities (func_tracktrain, path_track, prop_dynamic_override)
2. **Timer Management**: Handles laser lifecycle and repeating patterns
3. **Command Interface**: Admin commands for laser control
4. **Collision Detection**: SDKHooks for damage dealing
5. **Asset Management**: Precaching and download table management

#### Code Organization
```sourcepawn
// Configuration constants at top
#define PROP_MODEL "models/nide/laser/laser.mdl"
#define LASER_SPEED 1000.0

// Enums for type safety
enum LaserMode { STOP = -1, AIM = 0, LINEAR = 1, ... }

// Global state management
bool repeat = false;
Handle g_RepeatLaserTimer = null;

// Core functionality
- OnPluginStart(): Command registration and translations
- OnMapStart(): Asset precaching and download tables
- Command handlers: Laser spawning and control
- Timer callbacks: Lifecycle and pattern management
- Entity creation functions: CreateProp, CreateTrackTrain, CreatePath
- Utility functions: IsValidClient, FindEntityByTargetName
```

### Best Practices Followed
- Proper memory management with `delete` (no null checks needed)
- Timer cleanup in OnMapEnd and OnRoundEnd
- Entity cleanup with proper Kill inputs
- Use of entity targetting system for organized entity management
- Proper use of SDKHooks for collision detection
- Translation support for user messages

## Development Workflow

### Local Development
1. Clone repository
2. **Recommended**: Use GitHub Actions for building (push to branch triggers build)
3. **Alternative**: Manual setup:
   - Download SourceMod development package
   - Install MultiColors includes
   - Compile with: `spcomp -i/path/to/includes Laser.sp`
4. Deploy to test server: Copy built files to SourceMod installation

### Testing
- Deploy to development server with SourceMod 1.11+
- Test all laser modes via commands:
  - `sm_throwlaser <target> 0` (aim mode)
  - `sm_throwlaser <target> 1` (linear mode)  
  - `sm_throwlaser <target> 2` (linear random)
  - `sm_throwlaser <target> 3` (repeating random)
  - `sm_throwlaser_kill` (stop laser)
- Verify asset loading (models, materials, sounds download to clients)
- Test damage dealing and collision detection
- Verify timer cleanup and memory management (check for entity leaks)

### Code Quality Standards
- Use `#pragma semicolon 1` and `#pragma newdecls required`
- Follow camelCase for variables, PascalCase for functions
- Prefix globals with `g_`
- Use descriptive names for entities and constants
- Implement proper error handling for entity creation
- Use delete for Handle cleanup without null checks

## Asset Management

### Models and Materials
- Custom laser model: `models/nide/laser/laser.mdl` + supporting files
- Textures in `materials/models/nide/laser/`
- All files added to download table for client synchronization

### Sound Effects
- Laser sound: `sound/nide/laser.wav`
- Precached and added to download table

### Download Table Management
- All custom assets automatically added in OnMapStart()
- Ensures clients download required files
- Includes all model variations (.mdl, .phy, .vvd, .vtx files)

## Common Tasks

### Adding New Laser Modes
1. Extend `LaserMode` enum
2. Add case in `ThrowLaser()` switch statement
3. Update command help text in `Command_Laser()`

### Modifying Laser Behavior
- Adjust constants at top of file (speed, damage, timers)
- Modify entity creation in `CreateProp()` or `CreateTrackTrain()`
- Update collision detection in `Hook_PropHit()`

### Asset Updates
1. Replace files in materials/models/sound directories
2. Update `#define` statements if file names change
3. Update download table entries in `OnMapStart()`
4. Test asset loading on clean client

### Performance Considerations
- Entity cleanup is critical - always use proper Kill inputs
- Timer management prevents memory leaks
- Minimal entity creation per laser (3-4 entities total)
- Efficient entity finding with targetname system

## Debugging

### Common Issues
- **Entities not cleaning up**: Check KillLaser() implementation
- **Models not loading**: Verify download table and file paths
- **Timer leaks**: Ensure proper delete in OnMapEnd/OnRoundEnd
- **Collision not working**: Check SDKHook registration and entity properties

### Logging
- Use `LogError()` for entity creation failures
- Add debug prints to timer callbacks for troubleshooting
- Monitor entity count with `FindEntityByClassname()` loops

## Release Process

### Automated via GitHub Actions
1. **For regular development**: Push to main/master branch triggers automatic build
2. **For releases**: Create and push a version tag (e.g., `v1.3`)
3. CI builds plugin and packages assets automatically
4. Creates GitHub release with .tar.gz containing:
   - Compiled .smx plugin in `addons/sourcemod/plugins/`
   - All models, materials, and sounds in proper directory structure
   - Ready for extraction to SourceMod server root

### Manual Release (if needed)
1. **Build locally**: Set up SourceMod compiler and compile `Laser.sp`
2. **Package structure**: 
   ```
   addons/sourcemod/plugins/Laser.smx
   materials/models/nide/laser/*
   models/nide/laser/*  
   sound/nide/*
   ```
3. **Test**: Deploy on clean server installation to verify all assets load
4. **Release**: Create GitHub release with packaged files

## SourcePawn-Specific Guidelines

### Memory Management
- Use `delete handle` directly (null checks not needed in modern SourcePawn)
- Clean up timers in map/round end events: `g_RepeatLaserTimer = null;` after delete
- Kill entities with proper AcceptEntityInput calls: `AcceptEntityInput(entity, "Kill")`

### Entity Management
- Use meaningful targetnames for entity organization (e.g., `_throwinglaser_maxime1907`)
- Parent entities properly for synchronized movement: `SetVariantEntity()` + `AcceptEntityInput(ent, "SetParent")`
- Set appropriate spawn flags and properties for entity behavior
- Always validate entity creation return values before use

### API Usage
- Prefer methodmap syntax for new APIs
- Use async patterns for timers: `CreateTimer()` with proper callbacks
- Handle client validation with custom `IsValidClient()` utility
- Use proper team checking: `GetClientTeam(client) > CS_TEAM_NONE`
- Validate entity references: check against `INVALID_ENT_REFERENCE`

### Error Handling
- Check entity creation return values: `if (ent < 1) { LogError(); return -1; }`
- Validate client indices and states before operations
- Handle command argument parsing gracefully with `GetCmdArg()`
- Log errors with meaningful context using `LogError()`

### Entity Lifecycle Pattern
This plugin demonstrates a sophisticated entity management pattern:
1. **Creation**: Multiple related entities (prop, tracktrain, path_tracks)
2. **Linking**: Entities connected via targetnames and parenting
3. **Animation**: Movement controlled by Source engine's track system  
4. **Cleanup**: Coordinated destruction of all related entities

### Performance Patterns
- **Entity Caching**: Find entities by targetname rather than repeated searches
- **Timer Efficiency**: Use single repeating timer instead of multiple instances
- **Memory Cleanup**: Proper Handle deletion prevents memory leaks
- **Asset Management**: Precache all models/sounds in `OnMapStart()`

This plugin demonstrates excellent SourcePawn practices and serves as a good reference for Source engine entity manipulation, timer management, and asset handling.