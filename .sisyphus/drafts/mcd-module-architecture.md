# Draft: MCD Module Architecture & Development Plan

## Project Vision (from user)
- **Name**: MCD (Modern Cloud Deployment)
- **Goal**: Modern PowerShell framework for deploying Windows from the cloud
- **Philosophy**: Best of both worlds - OSDCloud (flexibility, cloud-native) + FFU (speed, reliability)
- **Target Audience**: 
  - Simple users (easy to use)
  - IT technicians (mass deployment, ultra-flexible)
- **Open source**: Yes, easily maintainable

## Requirements (confirmed)

### Public Commands (entry points)
- **2 public functions only** (for now):
  1. Workspace entry point (runs on full Windows)
  2. WinPE entry point (runs in WinPE environment)

### Private Function Organization (confirmed structure)
```
source/Private/
├── Core/                    # Common functions (Workspace + WinPE)
├── Workspace/
│   └── <subfolders>/        # Workspace-specific functions
└── WinPE/
    └── <subfolders>/        # WinPE-specific functions
```

## Research Findings

### OSDCloud Patterns (from analysis)
**Strengths:**
- Mature workspace/template/USB media workflow
- Rich WinPE customization (drivers, modules, scripts)
- Multiple entry points (CLI, GUI, scripted)
- Global hashtable state management ($Global:OSDCloud)
- Extensive cloud image sourcing (Feature Updates, ESD)
- Offline USB caching capabilities
- JSON-based configuration persistence (workspace.json, template.json)

**Architecture:**
- Public/Private split with extensive helper functions
- Step-based execution (Private/osdcloud-steps/)
- ADK integration for WinPE building
- Robocopy-based media operations
- Transcript logging throughout

**Workspace flow:**
1. Template creation (ADK-based WinPE)
2. Workspace population (from template/ISO/USB)
3. WinPE customization (Edit-OSDCloudWinPE)
4. Media output (ISO/USB)

**WinPE flow:**
1. Boot + wpeinit
2. Initialize-OSDCloudStartnet (network, wifi)
3. Start-OSDCloud/GUI/CLI
4. Invoke-OSDCloud (main orchestration)
5. Apply image + drivers + config

### FFU Project Patterns (from analysis)
**Strengths:**
- FFU format = block-level imaging (faster than WIM)
- VM-based image building (Hyper-V)
- App/driver pre-installation via sysprep
- JSON config file support
- Clean separation: Build vs Deploy vs Capture
- Simpler, more focused scripts

**Architecture:**
- Script-based (not a PS module)
- Single working directory (FFUDevelopmentPath)
- Separate scripts: BuildFFUVM.ps1, Create-PEMedia.ps1, ApplyFFU.ps1, CaptureFFU.ps1
- USB: 2-partition layout (FAT32 boot + NTFS deploy)

**Key differentiator:**
- FFU captures ENTIRE disk (partitions included)
- Apply is just `dism /apply-ffu` - very fast
- Ideal for "golden image" scenarios

### Key Design Decisions Needed

1. **Image format preference**: WIM-based (like OSDCloud) vs FFU-based?
2. **State management**: Global hashtables vs Class-based vs Parameter passing?
3. **Configuration format**: JSON, PSD1, or YAML?
4. **ADK handling**: Bundled detection/install or require pre-installed?
5. **USB layout**: Single or dual partition?
6. **GUI approach**: XAML (WPF) like OSDCloud or CLI-only initially?
7. **Driver strategy**: Cloud packs, local folders, or both?
8. **Offline capabilities**: How important is offline deployment?

## Technical Decisions

### Image Format: WIM-based (Confirmed)
- **Rationale**: Flexible, can apply to different disk sizes, cloud-native (download ESD/WIM)
- **Like OSDCloud**: Download Windows images from Microsoft, apply to local disk
- **Note**: FFU support could be added later as an advanced feature

### State Management: Class-based objects (Confirmed)
- **Rationale**: Type-safe, cleaner code, better IntelliSense, maintainable
- **Classes to create**:
  - `MCDConfig` - Main configuration class
  - `MCDWorkspace` - Workspace state and paths
  - `MCDWinPE` - WinPE runtime state
  - (More TBD based on requirements)
- **Consideration**: Classes work in WinPE PowerShell (5.1)

### ADK Handling: Auto-install ADK (Confirmed)
- **Rationale**: Best user experience, reduces friction for new users
- **Implementation**: 
  - Detect if ADK + WinPE add-on installed
  - If missing, download and silently install
  - Similar to FFU's `Get-ADKURL` approach (scrape Microsoft page for current URLs)
- **Consideration**: Silent install uses `/quiet` + feature IDs

### Public Function Naming: Start-MCD* pattern (Confirmed)
- **Entry points**:
  - `Start-MCDWorkspace` - Workspace operations (full Windows)
  - `Start-MCDWinPE` - WinPE runtime (deployment environment)
- **Clear, consistent, easy to remember**

### GUI Support: Full GUI (WPF) (Confirmed)
- **Rationale**: Rich user experience like OSDCloudGUI
- **Implementation**: XAML-based WPF windows
- **Location**: `source/Xaml/` (already in build.yaml CopyPaths)
- **Consideration**: GUI usable in both Workspace and WinPE? (WinPE has limited WPF support)

### Driver Strategy: Cloud Driver Packs (Confirmed)
- **Primary source**: Download OEM driver packs from cloud (Dell, HP, Lenovo, Microsoft)
- **Like OSDCloud**: Automatic driver pack detection based on hardware
- **Implementation**: Functions to download and cache driver packs
- **Future**: Could add local folder support as override option

### Offline/Caching Strategy: Smart USB Caching (Confirmed)
- **Approach**: Online by default + intelligent USB caching
- **Behavior**:
  1. First deployment: Download from cloud, save to USB cache
  2. Subsequent deployments: Reuse cached content if present
  3. No re-download if sources already exist on USB
- **Benefits**: Fast field deployments, bandwidth-efficient
- **Implementation**: Check USB for cached images/drivers before downloading
- **Like OSDCloud**: `Find-OSDCloudFile` pattern - search local before cloud

### USB Layout: Dual Partition (Confirmed)
- **Structure**:
  - Partition 1: FAT32 (~2GB) - WinPE boot files (label: "WinPE" or "MCD")
  - Partition 2: NTFS (remaining) - Cached content, large images (label: "MCDData")
- **Rationale**: FAT32 for UEFI boot compatibility, NTFS for large file support (>4GB)
- **Like OSDCloud/FFU**: Both use this dual-partition approach

### Windows Editions: Client Only - Windows 10/11 (Confirmed)
- **Supported**: Windows 10, Windows 11 (Home, Pro, Enterprise, Education)
- **Not supported**: Windows Server (could be added later)
- **Rationale**: Focus on most common use case, reduce testing matrix

### Autopilot/Provisioning: Full Support (Confirmed)
- **Features**:
  - Autopilot JSON file injection
  - PPKG (Provisioning Package) support
  - Intune registration preparation
  - Computer naming (templates, CSV, serial-based)
- **Implementation**: Stage files to `C:\Windows\Provisioning\Autopilot`
- **Like OSDCloud**: Full Autopilot integration

### Localization: Full Multi-Language (Confirmed)
- **WinPE**: Support for adding language packs to WinPE image
- **Target OS**: Language selection during deployment
- **UI**: Module strings localized (en-US as base, add others)
- **Implementation**: 
  - `source/en-US/` for base strings
  - Additional `source/<lang>/` folders as needed
- **Like OSDCloud**: `-Language` and `-SetAllIntl` patterns

### Module Dependencies: Self-Contained (Confirmed)
- **No external module dependencies**
- **Rationale**: 
  - Easier installation (single module)
  - Works offline in WinPE
  - No version conflicts
  - More maintainable
- **Include**: All necessary utilities bundled in Private functions

### Recommended Folder Structure (Pending User Confirmation)

Based on OSDCloud/FFU analysis, here's the optimal structure:

```
source/Private/
├── Core/                    # Shared utilities (Workspace + WinPE)
│   ├── Logging.ps1          # Write-MCDLog, transcript management
│   ├── Config.ps1           # JSON config read/write
│   ├── Validation.ps1       # Block-StandardUser, Test-Prerequisites
│   ├── Network.ps1          # Test-WebConnection, download helpers
│   └── Disk.ps1              # Disk detection, partition helpers
│
├── Workspace/               # Full Windows operations
│   ├── ADK/                 # ADK detection, installation, paths
│   ├── Template/            # WinPE template creation
│   ├── WinPE/               # WinPE image customization (mount, inject, etc.)
│   ├── Media/               # ISO and USB creation
│   ├── Drivers/             # Driver pack download and management
│   └── Config/              # Workspace configuration management
│
└── WinPE/                   # WinPE runtime operations
    ├── Initialize/          # Startup, network, prerequisites
    ├── GUI/                 # WPF GUI logic for WinPE
    ├── Image/               # Windows image download, selection, apply
    ├── Drivers/             # Driver injection (offline to target OS)
    ├── Provisioning/        # Autopilot, PPKG, computer naming
    └── Cleanup/             # Post-deployment cleanup
```

**Why this structure?**
- **Core/**: Functions used in both environments (DRY principle)
- **Workspace/**: Organized by "what you're building" (ADK, Template, Media, etc.)
- **WinPE/**: Organized by "deployment workflow phases" (Initialize → Deploy → Cleanup)

### Folder Structure: Approved with note (Confirmed)
- User approved the recommended structure
- **Note**: WPF GUI will exist for BOTH Workspace AND WinPE
- GUI location: `source/Xaml/` (already configured in build.yaml)

### Working Directories (Confirmed)

**Workspace (Full Windows):**
- Working directory: `%ProgramData%\MCD\`
- Templates: `%ProgramData%\MCD\Templates\`
- Workspaces: `%ProgramData%\MCD\Workspaces\`
- Logs: `%ProgramData%\MCD\Logs\`
- Cache: `%ProgramData%\MCD\Cache\`

**WinPE Runtime:**
- Working directory: `X:\MCD\` (WinPE RAM disk)
- Logs during deployment: `X:\MCD\Logs\`
- **Before reboot**: Copy logs to `C:\Temp\MCD\` on target OS

### Logging Strategy (Confirmed)

**Uniform logging interface** but different storage:

**Workspace logging:**
- Global log file: `%ProgramData%\MCD\Logs\MCD-<timestamp>.log`
- Single file for entire session
- Transcript included

**WinPE logging:**
- Per-step log files for each deployment phase:
  - `X:\MCD\Logs\01-Initialize.log`
  - `X:\MCD\Logs\02-Wizard.log` (GUI selections)
  - `X:\MCD\Logs\03-Format.log` (disk operations)
  - `X:\MCD\Logs\04-Image.log` (Windows image apply)
  - `X:\MCD\Logs\05-Drivers.log` (driver injection)
  - `X:\MCD\Logs\06-Provisioning.log` (Autopilot/PPKG)
  - `X:\MCD\Logs\07-Cleanup.log` (final steps)
- **Before reboot**: All logs copied to `C:\Temp\MCD\`
- Benefit: Easy to identify which step failed

### Error Handling: Situational (Confirmed)
- Critical operations (disk format): Stop on error
- Non-critical operations (driver pack download): Warn and continue
- Implementation: Each function decides based on context

### WinPE Step Names: Dynamic (Confirmed)
- Base steps: Initialize, Wizard, Format, Image, Drivers, Provisioning, Cleanup
- **Dynamic**: Steps can be added/removed based on deployment configuration
- Log naming: `XX-<StepName>.log` where XX is order number
- Step registry in config allows flexibility

### USB Cache Location (Recommendation)

**Recommended: USB:\MCD\<content-type>\**

```
USB NTFS Partition (Label: MCDData)
├── MCD\
│   ├── Images\         # Windows WIM/ESD files
│   ├── Drivers\        # Driver packs (.cab, folders)
│   ├── Autopilot\      # Autopilot JSON files
│   ├── PPKG\           # Provisioning packages
│   ├── Scripts\        # Custom deployment scripts
│   └── Logs\           # Copied from X:\ after deployment
```

**Why this structure:**
- Clear organization by content type
- Easy to find and manage files
- Matches the logical workflow
- Not too deep (easy to navigate)

### Multiple Workspaces: Supported (Confirmed)
- **Like OSDCloud**: Named workspaces/templates
- **Structure**:
  - `%ProgramData%\MCD\Workspaces\<WorkspaceName>\`
  - `%ProgramData%\MCD\mcd.json` - stores active workspace path
- **Commands will support**:
  - `Get-MCDWorkspace` - Get current workspace
  - `Set-MCDWorkspace -Name <name>` - Switch workspace
  - `New-MCDWorkspace -Name <name>` - Create new workspace

### USB Cache Structure: Approved (Confirmed)
- Structure as proposed in draft
- USB:\MCD\{Images, Drivers, Autopilot, PPKG, Scripts, Logs}

### Initial Scope: MVP - Both Environments (Confirmed)
- Build BOTH Workspace AND WinPE foundations
- Minimal but complete end-to-end flow
- Goal: User can go from nothing to deployed Windows

### Testing Strategy (Recommendation)

**Recommended: TDD for Core + Tests-After for UI**

| Component | Approach | Reason |
|-----------|----------|--------|
| **Core functions** | TDD | Critical logic, reused everywhere |
| **Workspace functions** | TDD | Complex operations, need safety net |
| **WinPE functions** | Tests-After | Harder to test (needs WinPE env) |
| **GUI (WPF)** | Manual testing | UI testing is complex in PowerShell |

**Practical approach:**
- Core/ and Workspace/ functions: Write Pester tests first
- WinPE/ functions: Mock-based tests after implementation
- GUI: Manual verification (could add later)

**Why TDD for Core:**
- Config parsing, logging, disk operations = bugs are expensive
- Tests as documentation
- Refactoring safety
- Repo already has 85% coverage threshold

### Testing Approach: Mixed (Confirmed)
- TDD for Core + Workspace functions
- Tests-After for WinPE functions
- Manual for GUI

### MVP Feature Set: Basic Flow Only (Confirmed)

**MUST-HAVE (MVP):**
1. ADK auto-installation
2. Minimal WinPE template creation
3. USB creation (dual partition)
4. GUI wizard (WPF) for both Workspace and WinPE
5. Disk formatting
6. Windows image apply (WIM from cloud)
7. Basic driver injection (from USB cache)

**NICE-TO-HAVE (Post-MVP):**
- Full Autopilot integration
- Cloud driver packs (Dell, HP, Lenovo)
- Multi-language support
- Advanced provisioning
- Named workspaces
- Offline caching intelligence

### Class Design (Recommendation)

Based on the architecture, here's the optimal class design:

```powershell
# Core configuration - used everywhere
class MCDConfig {
    [string]$Version
    [string]$WorkspacePath
    [hashtable]$Defaults
    [hashtable]$Logging
    
    static [MCDConfig]Load([string]$Path) { ... }
    [void]Save([string]$Path) { ... }
}

# Workspace state - full Windows operations
class MCDWorkspace {
    [string]$Name
    [string]$Path
    [string]$TemplatePath
    [string]$MediaPath
    [MCDConfig]$Config
    
    [void]Initialize() { ... }
    [bool]Validate() { ... }
}

# WinPE deployment state - runtime in WinPE
class MCDDeployment {
    [string]$SessionId          # Unique deployment ID
    [string]$WorkingPath        # X:\MCD\
    [string]$TargetDisk         # PhysicalDrive number
    [string]$ImagePath          # WIM/ESD path
    [hashtable]$Steps           # Step status tracking
    [MCDConfig]$Config
    
    [void]LogStep([string]$StepName, [string]$Message) { ... }
    [void]CopyLogsToTarget() { ... }  # Before reboot
}

# Media builder - USB/ISO creation
class MCDMediaBuilder {
    [MCDWorkspace]$Workspace
    [string]$OutputPath
    
    [void]CreateUSB([string]$DiskNumber) { ... }
    [void]CreateISO([string]$OutputPath) { ... }
}
```

**Why 4 classes:**
- **MCDConfig**: Shared config, JSON serializable
- **MCDWorkspace**: Workspace-specific state, used by Workspace functions
- **MCDDeployment**: Runtime state in WinPE, tracks deployment progress
- **MCDMediaBuilder**: Media creation operations, consumes workspace

### Class Design: 4 Classes Approved (Confirmed)
- MCDConfig, MCDWorkspace, MCDDeployment, MCDMediaBuilder

### Windows Image Source: Both (Confirmed)
- Option 1: Download Windows ESD from Microsoft (like OSDCloud)
- Option 2: User provides their own ISO/WIM file
- GUI will offer both choices

---

## DETAILED SPECIFICATIONS

### Workspace Configuration Options (To Be Clarified)

The Workspace GUI/wizard needs to configure what options are available during WinPE deployment.

**Potential configuration areas:**
1. **Wizard options**: Which choices are shown to user during deployment
2. **Wallpaper/branding**: Custom background for WinPE
3. **Language restrictions**: Limit available OS languages
4. **OS restrictions**: Limit available Windows editions/versions
5. **WinPE languages**: Which language(s) to inject into WinPE image
6. **WinPE drivers**: Which drivers to inject into WinPE
7. **Driver packs for deployment**: Available driver packs for target OS
8. **Autopilot profiles**: Pre-configured Autopilot JSON files
9. **Provisioning packages**: Pre-configured PPKGs

### WinPE Flow (Detailed - User Provided)

```
┌─────────────────────────────────────────────────────────────────┐
│                        WinPE BOOT                                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  1. CONNECTIVITY CHECK                                           │
│     - Check internet connectivity                                │
│     - If no internet → Show WiFi connection GUI (WPF)           │
│     - XAML: Connectivity.xaml (dedicated)                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  2. MODULE UPDATE                                                │
│     - Try: Download latest MCD from PowerShell Gallery          │
│     - Fallback: Use module from USB key                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  3. WIZARD                                                       │
│     - Computer language selection                                │
│     - OS edition/version selection                               │
│     - Driver pack selection                                      │
│     - Other deployment options                                   │
│     - XAML: Wizard.xaml (dedicated)                             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  4. DEPLOYMENT PROGRESS                                          │
│     - TSBackground-style progress display                       │
│     - Shows: Computer name, network info, elapsed time          │
│     - Shows: Current step, progress bar, step X of Y            │
│     - XAML: MainWindow.xaml (already exists)                    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  5. COMPLETION                                                   │
│     SUCCESS:                                                     │
│     - Show success screen                                       │
│     - Auto-reboot in X seconds                                  │
│     - XAML: Success.xaml (dedicated)                            │
│                                                                  │
│     ERROR:                                                       │
│     - Show error screen with message                            │
│     - XAML: Error.xaml (dedicated)                              │
└─────────────────────────────────────────────────────────────────┘
```

### WinPE XAML Files (Confirmed)
1. `Connectivity.xaml` - WiFi/network connection GUI
2. `Wizard.xaml` - Deployment options wizard
3. `MainWindow.xaml` - Progress display (TSBackground-style) ✓ EXISTS
4. `Success.xaml` - Success screen with countdown
5. `Error.xaml` - Error screen with message

### Workspace Configuration Storage (Confirmed)

**One config file per workspace:**
```
%ProgramData%\MCD\
├── mcd.json                    # Global: active workspace, global settings
└── Workspaces\
    ├── Default\
    │   ├── workspace.json      # This workspace's config
    │   ├── Media\
    │   └── ...
    ├── SiteMarseille\
    │   ├── workspace.json      # Different config for this workspace
    │   ├── Media\
    │   └── ...
    └── FactoryFloor\
        ├── workspace.json
        └── ...
```

**workspace.json structure (per workspace):**
```json
{
  "name": "SiteMarseille",
  "created": "2026-01-24T10:00:00Z",
  "branding": {
    "backgroundType": "image",          // "color" or "image"
    "backgroundColor": "#0078D4",       // if type=color
    "backgroundImage": "background.png", // if type=image (relative path)
    "title": "Task Sequence : DEPLOY Windows 11 - Site Marseille"
  },
  "winpe": {
    "languages": ["en-US", "fr-FR"],    // Languages injected into WinPE
    "drivers": ["path/to/driver1", ...] // WinPE drivers
  },
  "wizard": {
    "languages": null,                   // null = all, array = whitelist
    "editions": null,                    // null = all, array = whitelist
    "driverPacks": null,                 // null = all, array = whitelist
    "computerNameTemplate": "{SERIAL}",  // Naming pattern
    "autopilotProfiles": [],             // Available Autopilot JSONs
    "ppkgFiles": []                      // Available PPKGs
  },
  "deployment": {
    "defaultLanguage": "fr-FR",
    "defaultEdition": "Windows 11 Pro",
    "autoRebootDelay": 10                // seconds
  }
}
```

### Branding Options (Confirmed)
- **Solid color**: Hex color code (#0078D4)
- **Custom image**: PNG/JPG file in workspace folder
- Both options available, configured in workspace.json

### Language/Edition Selection Logic (Confirmed)
- **Default behavior**: Show ALL available options
- **If configured**: Whitelist restricts available choices
- **Pattern**: `null` = show all, `["en-US", "fr-FR"]` = only show these
- Applies to: Languages, Editions, Driver Packs

### Driver Pack Selection in Wizard (Confirmed)
- **Auto-detection**: Hardware is detected, matching pack pre-selected
- **Override**: User can choose different pack from dropdown (like OSDCloud)
- **List**: Available packs based on workspace config (or all if not restricted)

### WinPE Driver Injection (Confirmed - Admin Configurable)

**Comparison:**
| Approach | OSDCloud | FFU | MCD (Recommended) |
|----------|----------|-----|-------------------|
| Cloud packs | ✓ (Dell, HP WinPE packs) | ✗ | ✓ Optional |
| Local folder | ✓ | ✓ (PEDrivers\) | ✓ |
| HWID-based | ✓ (MS Update Catalog) | ✗ | Future |

**MCD approach:**
- **Default**: Minimal generic drivers (network + storage) - ensures boot on most hardware
- **Configurable**: Admin can add:
  - Local driver folders: `Workspace\PEDrivers\`
  - Cloud packs: Download OEM WinPE packs
- **workspace.json**: `winpe.drivers` array specifies what to inject

### Computer Naming (Confirmed - All Options)
1. **Serial-based**: `{SERIAL}` → "ABC123XYZ"
2. **Template-based**: `{PREFIX}-{SERIAL}` → "PC-ABC123XYZ"
3. **Manual entry**: User types name in wizard
4. **CSV mapping**: Serial → Name lookup (like FFU)

**Available variables for templates:**
- `{SERIAL}` - BIOS serial number
- `{PREFIX}` - Configured prefix
- `{RANDOM}` - Random string
- `{DATE}` - Date stamp
- `{MAKE}` - Manufacturer
- `{MODEL}` - Model name

### WinPE Drivers Approach: Approved (Confirmed)
- Minimal generic default + local folder + optional cloud packs

### Workspace GUI Layout (Confirmed)

**Dual Mode: Basic + Advanced**

**Basic Mode (Simple users):**
- Pre-configured sensible defaults
- Minimal choices: OS, Language, Create USB
- One-click deployment media creation
- Hide complex options

**Advanced Mode (IT Technicians):**
- Full access to all configuration
- Branding, driver management, language restrictions
- WinPE customization, Autopilot setup
- Template management, export/import

**Recommended Layout: Dashboard with Mode Toggle**
```
┌─────────────────────────────────────────────────────────────────┐
│  MCD Workspace                              [Basic ▼] [Advanced]│
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │   Create    │  │   Manage    │  │   Build     │              │
│  │  Workspace  │  │   Drivers   │  │   Media     │              │
│  └─────────────┘  └─────────────┘  └─────────────┘              │
│                                                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │  Configure  │  │  Autopilot  │  │   WinPE     │   (Advanced) │
│  │   Wizard    │  │   Setup     │  │   Settings  │              │
│  └─────────────┘  └─────────────┘  └─────────────┘              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

- **Basic mode**: Shows only essential tiles (Create Workspace, Build Media)
- **Advanced mode**: Shows all tiles including Drivers, Autopilot, WinPE Settings

### Workspace GUI Layout: Dashboard Approved (Confirmed)
- Dashboard style with Basic/Advanced toggle

### Disk Partitioning (Confirmed)

**Default: Standard GPT layout**
```
Partition 1: EFI System (100 MB, FAT32)
Partition 2: MSR (16 MB, no filesystem)
Partition 3: Windows OS (remaining - recovery size)
Partition 4: Recovery (optional, ~1 GB, contains WinRE)
```

**Advanced: Configurable**
- Custom partition sizes
- Skip recovery partition
- Extra data partitions

### Recovery Partition (Confirmed)
- **Configurable**: Default = create, can be disabled
- Setting in workspace.json: `deployment.createRecoveryPartition: true/false`

### BitLocker (Confirmed)
- **Standard GPT layout is already BitLocker-ready**
- No special preparation needed
- BitLocker enablement via Autopilot/Intune policy (not MCD's job)
- Same approach as OSDCloud and FFU

### Post-Deployment Scripts (Confirmed)
- **Optional/Configurable**
- Workspace can define scripts to run after Windows apply
- Scripts stored in: `Workspace\Scripts\`
- Stages: SetupComplete, FirstLogon (like OSDCloud)
- Setting: `deployment.scripts.enabled: true/false`

### Windows Updates (Confirmed)
- **Configurable per workspace**
- Options:
  - `none`: Just apply image, reboot
  - `stage`: Download updates, apply during deployment
  - `defer`: Let Windows Update handle after OOBE
- Default: `defer` (simplest, relies on normal Windows Update)

### Multiple Disk Support (Confirmed)
- **Auto-detect + selection**
- Default: Use first suitable disk
- Wizard: If multiple disks detected, show selection dropdown
- Skip: External drives (USB) excluded from selection

### Boot Media Creation (Workspace)

**USB Creation:**
1. **Dual partition layout** (confirmed earlier):
   - FAT32 (~2GB): WinPE boot files (label: "WinPE" or "MCD")
   - NTFS (remaining): Cache, drivers, images (label: "MCDData")

2. **USB creation workflow in Workspace GUI:**
   - Select USB drive from dropdown
   - Confirm (destructive operation!)
   - Format and partition
   - Copy WinPE media from workspace
   - Copy cached content (optional)

3. **Update existing USB:**
   - Update WinPE boot files only
   - Update cached content only
   - Full refresh

**ISO Creation:**
- Create bootable ISO from workspace
- For testing in VMs or burning to DVD
- Output: `Workspace\Media\MCD.iso`

**Both outputs use the same WinPE image from workspace.**

### USB Update Strategy (Recommendation: Smart Update)

**Default: Smart/Incremental Update**
- Only copy changed files (fast)
- Preserves cached content on USB (images, drivers user added)
- Uses robocopy with `/XO` (exclude older) or hash comparison

**Full Refresh option available:**
- Wipes and recreates partitions
- For when USB is corrupted or needs clean slate

**UI in Workspace:**
- "Update USB" button (smart update)
- "Rebuild USB" button in Advanced mode (full refresh)

### Boot Mode Support (Confirmed)

**UEFI + Secure Boot only**
- Modern approach (Windows 10/11 requirement for new devices)
- WinPE from ADK is already Secure Boot signed
- No Legacy BIOS support (simplifies code, most modern PCs are UEFI)
- USB partition: FAT32 for EFI compatibility

### USB Update - OSDCloud vs FFU Comparison

| Aspect | OSDCloud | FFU | MCD (Recommended) |
|--------|----------|-----|-------------------|
| Method | Robocopy sync | Full recreate | Robocopy sync |
| WinPE partition | Mirror (`/MIR`) | Full wipe | Mirror |
| Data partition | Additive copy | Full wipe | Additive copy |
| Preserves user content | ✓ | ✗ | ✓ |
| Multiple USBs | ✓ | ✓ | ✓ (future) |

**MCD approach: Follow OSDCloud pattern**
- Smarter, faster, preserves user data
- Full refresh only as explicit advanced option

### Network Share Support (Confirmed)
- **Both USB and network share**
- USB: Primary deployment method
- Network: Alternative source for images/drivers
- WinPE can connect to SMB share if configured
- Setting: `deployment.networkShare: "\\\\server\\share"`

---

## Scope Boundaries (MVP)

### INCLUDE (Must Have for MVP)
1. **Classes**: MCDConfig, MCDWorkspace, MCDDeployment, MCDMediaBuilder
2. **Core functions**: Logging, Config, Validation, Network, Disk
3. **ADK**: Auto-detection and installation
4. **Workspace GUI**: Dashboard with Basic/Advanced mode (WPF)
5. **WinPE template**: Create customized WinPE image
6. **USB creation**: Dual partition, smart update
7. **ISO creation**: For VMs and testing
8. **WinPE boot flow**: Connectivity → Module update → Wizard → Deploy → Complete
9. **WinPE GUIs**: Connectivity, Wizard, Progress (MainWindow), Success, Error
10. **Disk formatting**: Standard GPT layout
11. **Windows image apply**: From cloud (ESD) or local (WIM)
12. **Basic driver injection**: From USB cache
13. **Computer naming**: Template-based and manual

### EXCLUDE (Post-MVP / Future)
1. ~~Full Autopilot integration~~ (future)
2. ~~Cloud driver packs (Dell, HP, Lenovo)~~ (future)
3. ~~Multi-language WinPE~~ (future - start with en-US)
4. ~~Windows Update staging~~ (future)
5. ~~Network share deployment~~ (post-MVP)
6. ~~Custom post-deployment scripts~~ (post-MVP)
7. ~~Named workspace templates~~ (single workspace for MVP)
8. ~~Legacy BIOS support~~ (UEFI only)
9. ~~Windows Server support~~ (client only)

---

## Interview Complete - Ready for Plan Generation

### Config File Format: JSON (Confirmed)
- **Rationale**: Human-readable, widely supported, easy tooling
- **Files to create**:
  - `mcd.json` - Main config in workspace
  - Possibly per-device or per-deployment configs

## Scope Boundaries
- **INCLUDE**: (TBD)
- **EXCLUDE**: (TBD)

## Open Questions
(To be asked during interview)
