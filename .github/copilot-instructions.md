# Copilot Instructions for PotcVote SourceMod Plugin

## Repository Overview

This repository contains **PotcVote**, a SourcePawn plugin for SourceMod that implements a voting system for the Pirates of the Caribbean zombie escape map (`ze_potc_v4s_4fix`). The plugin allows players to vote for different difficulty stages (Classic, Extreme, Race Mode) and manages game state accordingly.

**Key Features:**
- Map-specific voting system for ze_potc_v4s_4fix
- Three difficulty stages with cooldown management
- Admin controls and automatic vote triggering
- Custom sound integration and entity manipulation
- Round-based vote scheduling

## Technical Environment

- **Language**: SourcePawn (.sp files)
- **Platform**: SourceMod 1.11+ (minimum required version)
- **Build Tool**: SourceKnight 0.2 (configured in `sourceknight.yaml`)
- **Dependencies**: 
  - SourceMod base includes (`sourcemod`, `sdkhooks`, `sdktools`, `cstrike`)
  - MultiColors plugin for chat formatting (`multicolors`)
  - Counter-Strike: Source/Global Offensive game support

## Project Structure

```
├── .github/
│   ├── workflows/ci.yml     # CI/CD pipeline for building and releases
│   └── copilot-instructions.md
├── addons/sourcemod/
│   └── scripting/
│       └── PotcVote.sp      # Main plugin source (421 lines)
├── sound/nide/              # Custom sound files for the plugin
├── sourceknight.yaml       # Build configuration
└── .gitignore              # Excludes build artifacts (.sourceknight/, *.smx)
```

## Plugin Commands & Configuration

### Available Commands
- `sm_potcvote` - Start a difficulty vote (admin command & server command)
- `sm_cancelcvote` - Cancel pending vote (server command)

### ConVars
- `sm_potcvote_delay` (default: 3.0) - Seconds before starting vote
- `sm_potcvote_percent` (default: 60) - Percentage needed to pass vote

### Internal Commands
The plugin executes `sm_stage <number>` when a vote succeeds, where:
- Stage 1 = Classic mode
- Stage 2 = Extreme mode  
- Stage 3 = Race mode

## Core Plugin Architecture

### Main Components
- **Vote Management**: Handles vote creation, counting, and results
- **Stage System**: Three predefined difficulty stages with cooldown logic
- **Entity Control**: Manipulates game entities based on vote outcomes
- **Round Integration**: Coordinates with game rounds and events
- **Map Verification**: Ensures plugin only runs on correct map

### Key Global Variables
- `g_bVoteFinished`: Tracks vote state
- `g_bOnCooldown[NUMBEROFSTAGES]`: Stage cooldown management  
- `g_StageList`: ArrayList for vote options
- `g_VoteMenu`: Native vote menu handle
- `g_sStageName[3]`: Stage name definitions ("Classic", "Extreme", "Race Mode")
- `g_Winnerstage`: Stores the winning stage index
- `g_cDelay`, `g_cPercent`: ConVars for timing and vote percentage

## SourcePawn Coding Standards

### Required Pragmas
```sourcepawn
#pragma semicolon 1
#pragma newdecls required
```

### Naming Conventions
- **Global variables**: Prefix with `g_` (e.g., `g_bVoteFinished`)
- **Functions**: PascalCase (e.g., `GenerateArray()`)
- **Local variables**: camelCase (e.g., `iCurrentStage`)
- **Constants**: UPPERCASE (e.g., `NUMBEROFSTAGES`)

### Memory Management
- Use `delete` for Handle cleanup (automatically handles null checks)
- Prefer `ArrayList`/`StringMap` over traditional arrays
- Always clean up timers and handles in `OnMapEnd()` or `OnPluginEnd()`

### Best Practices
- All database operations must be asynchronous
- Use `StringMap`/`ArrayList` methodmaps for modern API access
- Implement proper error handling for all API calls
- Use translation files for user messages (if implementing new text)
- Validate entity operations before execution

## Build System (SourceKnight)

### Configuration (`sourceknight.yaml`)
- **Project Name**: PotcVote
- **SourceMod Version**: 1.11.0-git6934
- **Output Directory**: `/addons/sourcemod/plugins`
- **Dependencies**: Automatically downloads SourceMod and MultiColors

### Build Commands
```bash
# If SourceKnight is available:
sourceknight build

# The CI uses maxime1907/action-sourceknight@v1
# Manual compilation requires SourceMod compiler (spcomp)
```

### CI/CD Pipeline
- **Trigger**: Push, PR, manual dispatch
- **Build**: Compiles plugin using SourceKnight action
- **Package**: Creates release artifacts with sound files
- **Release**: Auto-tags and releases on main/master branch

## Development Workflow

### Making Changes
1. **Code Changes**: Edit `addons/sourcemod/scripting/PotcVote.sp`
2. **Sound Files**: Add/modify files in `sound/nide/` directory
3. **Build Config**: Update `sourceknight.yaml` if dependencies change
4. **Testing**: Plugin requires `ze_potc_v4s_4fix` map for full functionality

### Common Tasks

#### Adding New Vote Options
1. Modify `NUMBEROFSTAGES` constant
2. Update `g_sStageName` array with new stage names
3. Extend `g_bOnCooldown` array handling
4. Update vote generation logic in `GenerateArray()`

#### Entity Manipulation
- Use `FindEntityByTargetname()` for entity lookups
- Validate entities with `IsValidEntity()` before operations
- Clean up created entities appropriately

#### Adding Commands
```sourcepawn
// Server commands (no client required)
RegServerCmd("sm_command", CallbackFunction);

// Admin commands  
RegAdminCmd("sm_command", CallbackFunction, ADMFLAG_CONVARS, "Description");

// Public function signature:
public Action CallbackFunction(int client, int argc) { return Plugin_Handled; }
```

#### Adding ConVars
```sourcepawn
ConVar g_cNewVar = CreateConVar("sm_potcvote_setting", "default", "Description", FCVAR_NOTIFY);
// Don't forget AutoExecConfig(true) in OnPluginStart()
```

### Debugging
- Plugin auto-unloads on wrong maps (see `VerifyMap()`)
- Use `PrintToChatAll()` or `CPrintToChatAll()` for debug output
- Check SourceMod logs for compilation and runtime errors
- Entity debugging: Monitor entity creation/destruction

## Map Integration

### Map Dependency
- **Required Map**: `ze_potc_v4s_4fix`
- **Auto-Unload**: Plugin unloads if wrong map detected
- **Sound Precaching**: Custom sound files precached for map

### Entity Targets
- `Difficulty_Counter`: Math counter for difficulty tracking
- `Level_Text`: Game text entity for level display
- `ext_nukesound`: Ambient sound entity for music
- Various map-specific entities manipulated based on vote results

## Performance Considerations

### Optimization Guidelines
- Minimize operations in frequently called functions (`OnEntityCreated`, `SDKHook` callbacks)
- Cache expensive lookups (entity references, calculations)
- Use efficient data structures (`ArrayList` vs arrays)
- Avoid string operations in hot code paths

### Memory Management
- Clean up all handles in `OnMapEnd()`
- Use `delete` for automatic null-safe cleanup
- Avoid memory leaks with proper ArrayList/StringMap lifecycle

## Version Control & Releases

### Versioning
- Plugin version in `myinfo` struct (currently "1.4.1")
- Use semantic versioning (MAJOR.MINOR.PATCH)
- Update version for any functional changes

### Git Workflow
- CI builds on all pushes/PRs
- Auto-release on main/master branch pushes
- Tags created automatically for releases

## Testing Considerations

### Test Environment Requirements
- Counter-Strike server with SourceMod 1.11+
- Map: `ze_potc_v4s_4fix`
- MultiColors plugin installed
- Sound files properly deployed

### Manual Testing Checklist
- Vote triggering (admin command and automatic)
- Vote counting and result application
- Entity manipulation verification
- Sound file playback
- Cooldown system functionality
- Map verification and auto-unload

## Common Issues & Solutions

### Build Issues
- **SourceKnight not available**: CI handles builds automatically
- **Missing dependencies**: Check `sourceknight.yaml` configuration
- **Compilation errors**: Verify SourcePawn syntax and includes

### Runtime Issues
- **Plugin not loading**: Check map name match in `VerifyMap()`
- **Entities not found**: Verify map version and entity names
- **Sound not playing**: Check file paths and precaching
- **Vote not starting**: Verify round state and cooldown status

## Security Considerations

- Input validation for all user-provided data
- SQL injection prevention (not applicable to this plugin)
- Admin permission checks for sensitive commands
- Entity validation before manipulation

## Contributing Guidelines

### Code Quality
- Follow existing code style and conventions
- Add comments for complex logic sections
- Test changes on appropriate map
- Verify memory management

### Pull Request Process
- CI must pass (build + basic validation)
- Changes should be minimal and focused
- Update plugin version if necessary
- Test on development server before submission