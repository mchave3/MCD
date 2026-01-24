# MCD MVP - Modern Cloud Deployment Module

## Context

### Original Request
User wants to develop MCD (Modern Cloud Deployment), a PowerShell module that combines the best aspects of OSDCloud (flexibility, cloud-native) and FFU (simplicity). The module deploys Windows 10/11 from the cloud with a modern WPF GUI for both workspace configuration and WinPE deployment.

### Interview Summary
**Key Discussions**:
- Architecture: 2 public entry points, class-based state management, self-contained module
- Workspace: Dashboard GUI with Basic/Advanced mode, JSON config per workspace
- WinPE: 5-step flow with dedicated WPF screens for each phase
- Media: Dual-partition USB (FAT32 boot + NTFS data), smart caching
- Deployment: Standard GPT partitioning, WIM-based imaging, driver auto-detection

**Research Findings**:
- OSDCloud: Mature workspace/template workflow, global hashtables, robocopy-based media operations
- FFU: Simpler scripts, JSON config, VM-based building
- Current repo: Sampler build pipeline, 85% coverage threshold, existing placeholder functions

### Self-Gap Analysis (Metis unavailable)
**Identified Gaps Addressed**:
1. PowerShell version compatibility (5.1 required for WinPE) - will enforce in module manifest
2. WPF in WinPE limitations - documented, will test during implementation
3. ADK download URLs change over time - will scrape Microsoft page like FFU does
4. Error handling granularity - situational approach documented
5. Class persistence (JSON serialization) - will implement ToJson/FromJson methods

---

## Work Objectives

### Core Objective
Build the MVP foundation for MCD: a complete end-to-end Windows deployment workflow from workspace setup through WinPE deployment, with modern WPF interfaces for both environments.

### Concrete Deliverables
1. **4 PowerShell Classes**: MCDConfig, MCDWorkspace, MCDDeployment, MCDMediaBuilder
2. **Core Functions**: Logging, Config, Validation, Network, Disk utilities
3. **Workspace Functions**: ADK management, template creation, media building
4. **WinPE Functions**: Initialization, deployment, cleanup
5. **5 WPF Windows**: Workspace Dashboard, WinPE Connectivity, Wizard, Progress, Completion
6. **2 Public Entry Points**: Start-MCDWorkspace, Start-MCDWinPE
7. **Pester Tests**: TDD for Core/Workspace, Tests-After for WinPE

### Definition of Done
- [ ] `Import-Module MCD` succeeds without errors
- [ ] `Start-MCDWorkspace` launches WPF dashboard
- [ ] Workspace can create bootable USB with WinPE
- [ ] Booting USB shows WinPE flow through all screens
- [ ] Windows image applies successfully to target disk
- [ ] All tests pass: `./build.ps1 -Tasks test`
- [ ] Code coverage >= 85%

### Must Have
- ADK auto-detection and installation
- WinPE template creation from ADK
- USB and ISO media creation
- Complete WinPE boot flow (5 screens)
- Windows image apply (ESD from cloud or local WIM)
- Basic driver injection from USB cache
- Per-step logging in WinPE

### Must NOT Have (Guardrails)
- NO external module dependencies (self-contained)
- NO Legacy BIOS support (UEFI only)
- NO Windows Server support (client only)
- NO FFU format support in MVP (WIM only)
- NO cloud driver packs (Dell/HP/Lenovo) - post-MVP
- NO Autopilot integration - post-MVP
- NO multi-language WinPE - start with en-US only
- NO network share deployment - post-MVP
- AVOID global variables - use classes for state
- AVOID hardcoded paths - use config/parameters
- AVOID Write-Host - use proper logging functions

---

## Verification Strategy

### Test Decision
- **Infrastructure exists**: YES (Pester + Sampler pipeline)
- **User wants tests**: TDD for Core/Workspace, Tests-After for WinPE
- **Framework**: Pester (already configured)

### Test Approach by Component

| Component | Approach | Reason |
|-----------|----------|--------|
| Classes (source/Classes/) | TDD | Foundation, must be solid |
| Core functions | TDD | Reused everywhere, bugs expensive |
| Workspace functions | TDD | Complex operations, need safety net |
| WinPE functions | Tests-After | Harder to test (WinPE environment) |
| GUI (WPF) | Manual | UI testing complex in PowerShell |

### Manual Verification for GUI
- Use Playwright browser automation (NOT applicable - WPF not browser)
- Manual testing with real USB + VM (Hyper-V)
- Screenshots for documentation

---

## Task Flow

```
Phase 1: Foundation
  1 (Setup) → 2 (Classes) → 3 (Core Functions)
                              ↓
Phase 2: Workspace                     
  4 (ADK) → 5 (Template) → 6 (Media) → 7 (Workspace GUI)
                              ↓
Phase 3: WinPE
  8 (Initialize) → 9 (WinPE GUIs) → 10 (Image Apply) → 11 (Cleanup)
                              ↓
Phase 4: Integration
  12 (Public Entry Points) → 13 (Integration Testing) → 14 (Documentation)
```

## Parallelization

| Group | Tasks | Reason |
|-------|-------|--------|
| A | 4, 5 | ADK and Template can be developed in parallel after Core |
| B | 9a, 9b, 9c, 9d | Four WinPE GUIs are independent |

| Task | Depends On | Reason |
|------|------------|--------|
| 2 | 1 | Classes need folder structure |
| 3 | 2 | Core functions use classes |
| 4-7 | 3 | Workspace needs Core functions |
| 8-11 | 3 | WinPE needs Core functions |
| 12 | 7, 11 | Entry points need both environments |
| 13 | 12 | Integration tests need entry points |

---

## TODOs

### Phase 1: Foundation

- [ ] 1. Setup Project Structure

  **What to do**:
  - Create folder structure under `source/Private/`
  - Create Core/, Workspace/{ADK,Template,WinPE,Media,Drivers,Config}, WinPE/{Initialize,GUI,Image,Drivers,Provisioning,Cleanup}
  - Remove placeholder files (Get-Something.ps1, Get-PrivateFunction.ps1, class files)
  - Update module manifest (MCD.psd1) with PowerShellVersion = '5.1'

  **Must NOT do**:
  - Don't create actual function files yet (just folders)
  - Don't modify build.yaml

  **Parallelizable**: NO (first task)

  **References**:
  - `source/MCD.psd1:36` - PowerShellVersion currently '5.0', change to '5.1'
  - `source/Public/Get-Something.ps1` - Remove this placeholder
  - `source/Private/Get-PrivateFunction.ps1` - Remove this placeholder
  - `source/Classes/*.ps1` - Remove placeholder class files
  - `build.yaml:10-13` - CopyPaths includes en-US and Xaml (keep these)

  **Acceptance Criteria**:
  - [ ] Folder structure exists: `ls source/Private/Core`, `ls source/Private/Workspace/ADK`, etc.
  - [ ] Placeholder files removed
  - [ ] `./build.ps1 -Tasks build` succeeds
  - [ ] Module manifest has PowerShellVersion = '5.1'

  **Commit**: YES
  - Message: `chore(structure): setup MCD folder structure and clean placeholders`
  - Files: `source/Private/**`, `source/Public/**`, `source/Classes/**`, `source/MCD.psd1`
  - Pre-commit: `./build.ps1 -Tasks build`

---

- [ ] 2. Implement Core Classes

  **What to do**:
  - Create `source/Classes/MCDConfig.ps1` with properties and JSON serialization
  - Create `source/Classes/MCDWorkspace.ps1` with workspace state management
  - Create `source/Classes/MCDDeployment.ps1` with deployment runtime state
  - Create `source/Classes/MCDMediaBuilder.ps1` with media creation methods
  - Add proper class ordering (1., 2., 3., 4. prefix for load order)
  - Write Pester tests first (TDD)

  **Must NOT do**:
  - Don't implement complex logic yet (just structure + basic methods)
  - Don't add dependencies on functions that don't exist yet

  **Parallelizable**: NO (depends on 1)

  **References**:
  - Draft `workspace.json` structure in `.sisyphus/drafts/mcd-module-architecture.md` - JSON schema for MCDConfig
  - `source/Examples/OSD-master/OSD.json` - Example of JSON config structure
  - `source/Examples/FFU-main/FFUDevelopment/config/Sample_default.json` - FFU config example

  **Class Structure Reference** (from interview):
  ```powershell
  class MCDConfig {
      [string]$Version
      [string]$WorkspacePath
      [hashtable]$Defaults
      [hashtable]$Logging
      static [MCDConfig]Load([string]$Path) { }
      [void]Save([string]$Path) { }
  }
  
  class MCDWorkspace {
      [string]$Name
      [string]$Path
      [string]$TemplatePath
      [string]$MediaPath
      [MCDConfig]$Config
      [void]Initialize() { }
      [bool]Validate() { }
  }
  
  class MCDDeployment {
      [string]$SessionId
      [string]$WorkingPath
      [string]$TargetDisk
      [string]$ImagePath
      [hashtable]$Steps
      [MCDConfig]$Config
      [void]LogStep([string]$StepName, [string]$Message) { }
      [void]CopyLogsToTarget() { }
  }
  
  class MCDMediaBuilder {
      [MCDWorkspace]$Workspace
      [string]$OutputPath
      [void]CreateUSB([string]$DiskNumber) { }
      [void]CreateISO([string]$OutputPath) { }
  }
  ```

  **Acceptance Criteria**:
  - [ ] Test file created: `tests/Unit/Classes/MCDConfig.tests.ps1`
  - [ ] Test file created: `tests/Unit/Classes/MCDWorkspace.tests.ps1`
  - [ ] Test file created: `tests/Unit/Classes/MCDDeployment.tests.ps1`
  - [ ] Test file created: `tests/Unit/Classes/MCDMediaBuilder.tests.ps1`
  - [ ] `./build.ps1 -Tasks test -PesterPath tests/Unit/Classes` → PASS
  - [ ] Classes can be instantiated: `[MCDConfig]::new()` works

  **Commit**: YES
  - Message: `feat(classes): implement core MCD classes with JSON serialization`
  - Files: `source/Classes/*.ps1`, `tests/Unit/Classes/*.tests.ps1`
  - Pre-commit: `./build.ps1 -Tasks test -PesterPath tests/Unit/Classes`

---

- [ ] 3. Implement Core Functions

  **What to do**:
  - Create `source/Private/Core/Write-MCDLog.ps1` - Unified logging function
  - Create `source/Private/Core/Get-MCDConfig.ps1` - Load configuration
  - Create `source/Private/Core/Set-MCDConfig.ps1` - Save configuration
  - Create `source/Private/Core/Test-MCDPrerequisites.ps1` - Check requirements
  - Create `source/Private/Core/Test-MCDAdminRights.ps1` - Verify admin elevation
  - Create `source/Private/Core/Test-MCDNetwork.ps1` - Check internet connectivity
  - Create `source/Private/Core/Get-MCDDisk.ps1` - Enumerate disks
  - Write Pester tests first (TDD)

  **Must NOT do**:
  - Don't use Write-Host (use Write-Verbose, Write-Warning, Write-Output)
  - Don't hardcode paths (use parameters or config)

  **Parallelizable**: NO (depends on 2)

  **References**:
  - `source/Examples/OSD-master/Private/Block-*.ps1` - OSDCloud validation patterns
  - `source/Examples/OSD-master/Public/Functions/WebConnection.ps1` - Network testing pattern
  - Logging paths from interview:
    - Workspace: `$env:ProgramData\MCD\Logs\`
    - WinPE: `X:\MCD\Logs\`

  **Logging Function Signature**:
  ```powershell
  function Write-MCDLog {
      param(
          [string]$Message,
          [ValidateSet('Info','Warning','Error','Debug')]
          [string]$Level = 'Info',
          [string]$Step,          # For WinPE per-step logging
          [string]$LogPath        # Override default path
      )
  }
  ```

  **Acceptance Criteria**:
  - [ ] Test files created: `tests/Unit/Private/Core/*.tests.ps1`
  - [ ] `./build.ps1 -Tasks test -PesterPath tests/Unit/Private/Core` → PASS
  - [ ] `Write-MCDLog -Message "Test" -Level Info` creates log entry
  - [ ] `Test-MCDAdminRights` returns $true when elevated
  - [ ] `Test-MCDNetwork` returns $true when internet available

  **Commit**: YES
  - Message: `feat(core): implement core utility functions with logging and validation`
  - Files: `source/Private/Core/*.ps1`, `tests/Unit/Private/Core/*.tests.ps1`
  - Pre-commit: `./build.ps1 -Tasks test -PesterPath tests/Unit/Private/Core`

---

### Phase 2: Workspace

- [ ] 4. Implement ADK Management Functions

  **What to do**:
  - Create `source/Private/Workspace/ADK/Get-MCDADK.ps1` - Detect installed ADK
  - Create `source/Private/Workspace/ADK/Test-MCDADK.ps1` - Validate ADK installation
  - Create `source/Private/Workspace/ADK/Install-MCDADK.ps1` - Download and install ADK
  - Create `source/Private/Workspace/ADK/Get-MCDADKPaths.ps1` - Get ADK component paths
  - Write Pester tests (TDD)

  **Must NOT do**:
  - Don't hardcode ADK download URLs (scrape from Microsoft page)
  - Don't assume specific ADK version

  **Parallelizable**: YES (with 5)

  **References**:
  - `source/Examples/OSD-master/Public/Functions/WindowsAdk.ps1` - OSDCloud ADK detection
  - `source/Examples/FFU-main/FFUDevelopment/BuildFFUVM.ps1` - FFU's Get-ADKURL pattern (scrapes Microsoft page)
  - ADK install page: `https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install`
  - Silent install features: `OptionId.DeploymentTools`, `OptionId.WindowsPreinstallationEnvironment`

  **ADK Detection Pattern** (from OSDCloud):
  ```powershell
  # Registry paths to check
  $AdkRegPath = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Kits\Installed Roots'
  $AdkRoot = (Get-ItemProperty -Path $AdkRegPath -ErrorAction SilentlyContinue).KitsRoot10
  ```

  **Acceptance Criteria**:
  - [ ] Test files created: `tests/Unit/Private/Workspace/ADK/*.tests.ps1`
  - [ ] `./build.ps1 -Tasks test -PesterPath tests/Unit/Private/Workspace/ADK` → PASS
  - [ ] `Get-MCDADK` returns ADK info hashtable or $null if not installed
  - [ ] `Install-MCDADK` downloads and installs ADK silently (requires admin + internet)

  **Commit**: YES
  - Message: `feat(adk): implement ADK detection and auto-installation`
  - Files: `source/Private/Workspace/ADK/*.ps1`, `tests/Unit/Private/Workspace/ADK/*.tests.ps1`
  - Pre-commit: `./build.ps1 -Tasks test -PesterPath tests/Unit/Private/Workspace/ADK`

---

- [ ] 5. Implement WinPE Template Functions

  **What to do**:
  - Create `source/Private/Workspace/Template/New-MCDTemplate.ps1` - Create WinPE template from ADK
  - Create `source/Private/Workspace/Template/Get-MCDTemplate.ps1` - Get template info
  - Create `source/Private/Workspace/Template/Update-MCDTemplate.ps1` - Update existing template
  - Handle: copype, mount WIM, add optional components, inject drivers, dismount
  - Write Pester tests (TDD)

  **Must NOT do**:
  - Don't add multi-language support yet (en-US only for MVP)
  - Don't inject cloud driver packs (local only)

  **Parallelizable**: YES (with 4)

  **References**:
  - `source/Examples/OSD-master/Public/OSDCloudSetup/OSDCloudTemplate.ps1` - OSDCloud template creation
  - `source/Examples/FFU-main/FFUDevelopment/Create-PEMedia.ps1` - FFU WinPE creation
  - WinPE OCs to add: WMI, NetFX, Scripting, PowerShell, StorageWMI, DismCmdlets

  **Template Creation Flow**:
  1. Run `copype amd64 <tempPath>` via ADK's Deployment Tools
  2. Mount `boot.wim` using `Mount-WindowsImage`
  3. Add optional components from ADK WinPE OCs folder
  4. Inject drivers from `Workspace\PEDrivers\` if present
  5. Copy MCD module into WinPE (`X:\Program Files\WindowsPowerShell\Modules\MCD`)
  6. Set ExecutionPolicy to Bypass
  7. Dismount and save
  8. Save to `Workspace\Template\`

  **Acceptance Criteria**:
  - [ ] Test files created: `tests/Unit/Private/Workspace/Template/*.tests.ps1`
  - [ ] `./build.ps1 -Tasks test -PesterPath tests/Unit/Private/Workspace/Template` → PASS
  - [ ] `New-MCDTemplate -WorkspacePath <path>` creates WinPE template (requires ADK)
  - [ ] Template contains: `boot.wim` with PowerShell support

  **Commit**: YES
  - Message: `feat(template): implement WinPE template creation from ADK`
  - Files: `source/Private/Workspace/Template/*.ps1`, `tests/Unit/Private/Workspace/Template/*.tests.ps1`
  - Pre-commit: `./build.ps1 -Tasks test -PesterPath tests/Unit/Private/Workspace/Template`

---

- [ ] 6. Implement Media Creation Functions

  **What to do**:
  - Create `source/Private/Workspace/Media/New-MCDUSB.ps1` - Create bootable USB (dual partition)
  - Create `source/Private/Workspace/Media/Update-MCDUSB.ps1` - Smart update existing USB
  - Create `source/Private/Workspace/Media/New-MCDISO.ps1` - Create bootable ISO
  - Create `source/Private/Workspace/Media/Get-MCDUSBDrive.ps1` - Enumerate USB drives
  - Handle: partitioning, formatting, copying files, oscdimg
  - Write Pester tests (TDD)

  **Must NOT do**:
  - Don't support disks > 2TB (USB limitation)
  - Don't use Legacy BIOS boot files

  **Parallelizable**: NO (depends on 5 - needs template)

  **References**:
  - `source/Examples/OSD-master/Public/Functions/Disk.ps1` - New-BootableUSBDrive pattern
  - `source/Examples/OSD-master/Public/OSDCloudSetup/OSDCloudUSB.ps1` - Update-OSDCloudUSB pattern
  - `source/Examples/FFU-main/FFUDevelopment/USBImagingToolCreator.ps1` - FFU USB creation

  **USB Partition Layout** (from interview):
  ```
  Partition 1: FAT32 (~2GB) - Label "WinPE" or "MCD"
  Partition 2: NTFS (remaining) - Label "MCDData"
  ```

  **USB Cache Structure** (from interview):
  ```
  MCDData:\MCD\
  ├── Images\
  ├── Drivers\
  ├── Autopilot\
  ├── PPKG\
  ├── Scripts\
  └── Logs\
  ```

  **Acceptance Criteria**:
  - [ ] Test files created: `tests/Unit/Private/Workspace/Media/*.tests.ps1`
  - [ ] `./build.ps1 -Tasks test -PesterPath tests/Unit/Private/Workspace/Media` → PASS
  - [ ] `New-MCDUSB -DiskNumber 2 -WorkspacePath <path>` creates dual-partition USB
  - [ ] USB boots in Hyper-V (manual verification)

  **Commit**: YES
  - Message: `feat(media): implement USB and ISO creation with dual partition support`
  - Files: `source/Private/Workspace/Media/*.ps1`, `tests/Unit/Private/Workspace/Media/*.tests.ps1`
  - Pre-commit: `./build.ps1 -Tasks test -PesterPath tests/Unit/Private/Workspace/Media`

---

- [ ] 7. Implement Workspace GUI (WPF Dashboard)

  **What to do**:
  - Create `source/Xaml/Workspace/Dashboard.xaml` - Main dashboard layout
  - Create `source/Private/Workspace/GUI/Show-MCDWorkspaceDashboard.ps1` - Launch WPF window
  - Implement Basic/Advanced mode toggle
  - Wire up: Create Workspace, Build Media tiles
  - Add Advanced tiles: Drivers, Settings

  **Must NOT do**:
  - Don't implement all Advanced features (just the tiles/UI)
  - Don't add Autopilot/PPKG management yet

  **Parallelizable**: NO (depends on 4, 5, 6)

  **References**:
  - `source/Xaml/WinPE/MainWindow.xaml` - Existing XAML style reference
  - `source/Examples/OSD-master/Projects/OSDCloudGUI/MainWindow.ps1` - OSDCloud GUI pattern

  **Dashboard Layout** (from interview):
  ```
  ┌─────────────────────────────────────────────────────────────────┐
  │  MCD Workspace                              [Basic ▼] [Advanced]│
  ├─────────────────────────────────────────────────────────────────┤
  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
  │  │   Create    │  │   Manage    │  │   Build     │              │
  │  │  Workspace  │  │   Drivers   │  │   Media     │              │
  │  └─────────────┘  └─────────────┘  └─────────────┘              │
  └─────────────────────────────────────────────────────────────────┘
  ```

  **Acceptance Criteria**:
  - [ ] XAML file created: `source/Xaml/Workspace/Dashboard.xaml`
  - [ ] `Show-MCDWorkspaceDashboard` launches WPF window
  - [ ] Basic/Advanced toggle shows/hides tiles
  - [ ] "Build Media" tile opens USB/ISO selection dialog
  - [ ] Manual verification: Window renders correctly, buttons respond

  **Commit**: YES
  - Message: `feat(gui): implement Workspace dashboard with Basic/Advanced mode`
  - Files: `source/Xaml/Workspace/*.xaml`, `source/Private/Workspace/GUI/*.ps1`
  - Pre-commit: `./build.ps1 -Tasks build`

---

### Phase 3: WinPE

- [ ] 8. Implement WinPE Initialization Functions

  **What to do**:
  - Create `source/Private/WinPE/Initialize/Initialize-MCDWinPE.ps1` - Main WinPE startup
  - Create `source/Private/WinPE/Initialize/Test-MCDConnectivity.ps1` - Check network
  - Create `source/Private/WinPE/Initialize/Update-MCDModule.ps1` - Download latest from PSGallery
  - Create `source/Private/WinPE/Initialize/Get-MCDUSBContent.ps1` - Find USB data partition
  - Create startnet.cmd template that calls Initialize-MCDWinPE
  - Write Pester tests (mocked, since actual WinPE not available)

  **Must NOT do**:
  - Don't assume internet is always available (fallback to USB module)
  - Don't block on module update failure

  **Parallelizable**: NO (depends on 3)

  **References**:
  - `source/Examples/OSD-master/Public/OSDCloudTS/Initialize-OSDCloudStartnetUpdate.ps1` - OSDCloud startup
  - `source/Examples/FFU-main/FFUDevelopment/WinPEDeployFFUFiles/Windows/System32/startnet.cmd` - FFU startnet

  **Startnet.cmd Template**:
  ```cmd
  wpeinit
  powercfg /s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
  powershell -NoLogo -ExecutionPolicy Bypass -Command "Initialize-MCDWinPE"
  ```

  **Initialization Flow**:
  1. wpeinit runs (Windows PE init)
  2. Set high performance power plan
  3. Check network connectivity
  4. If no network → Show WiFi GUI
  5. Try update module from PSGallery
  6. Fallback to USB module if update fails
  7. Launch wizard GUI

  **Acceptance Criteria**:
  - [ ] Test files created: `tests/Unit/Private/WinPE/Initialize/*.tests.ps1`
  - [ ] `./build.ps1 -Tasks test -PesterPath tests/Unit/Private/WinPE/Initialize` → PASS
  - [ ] `Initialize-MCDWinPE` function exists and has proper flow
  - [ ] startnet.cmd template is included in WinPE image

  **Commit**: YES
  - Message: `feat(winpe): implement WinPE initialization and module update flow`
  - Files: `source/Private/WinPE/Initialize/*.ps1`, `tests/Unit/Private/WinPE/Initialize/*.tests.ps1`
  - Pre-commit: `./build.ps1 -Tasks test -PesterPath tests/Unit/Private/WinPE/Initialize`

---

- [ ] 9. Implement WinPE GUI Screens (4 screens)

  **What to do**:
  - 9a. Create `source/Xaml/WinPE/Connectivity.xaml` + `Show-MCDConnectivity.ps1` - WiFi connection
  - 9b. Create `source/Xaml/WinPE/Wizard.xaml` + `Show-MCDWizard.ps1` - Deployment options
  - 9c. Enhance existing `source/Xaml/WinPE/MainWindow.xaml` + `Show-MCDProgress.ps1` - Progress display
  - 9d. Create `source/Xaml/WinPE/Success.xaml` + `source/Xaml/WinPE/Error.xaml` + handlers

  **Must NOT do**:
  - Don't implement Autopilot selection (post-MVP)
  - Don't add cloud driver pack download (post-MVP)

  **Parallelizable**: YES (9a, 9b, 9c, 9d are independent)

  **References**:
  - `source/Xaml/WinPE/MainWindow.xaml` - Existing progress screen (TSBackground style)
  - `source/Examples/OSD-master/Projects/OSDCloudGUI/MainWindow.xaml` - OSDCloud GUI reference

  **Wizard Screen Elements** (from interview):
  - Computer name input (template or manual)
  - Language dropdown (with restrictions from config)
  - OS Edition dropdown (with restrictions from config)
  - Driver pack dropdown (auto-detected, manual override)
  - "Deploy" button

  **Progress Screen Updates**:
  - Dynamic step name display
  - Progress percentage
  - Current action text
  - Left panel: Computer name, IP, elapsed time

  **Acceptance Criteria**:
  - [ ] XAML files created: Connectivity.xaml, Wizard.xaml, Success.xaml, Error.xaml
  - [ ] All Show-MCD* functions launch their respective windows
  - [ ] Wizard returns selected options as hashtable
  - [ ] Progress updates step name and percentage
  - [ ] Success shows countdown timer
  - [ ] Error shows error message
  - [ ] Manual verification in Windows (not WinPE) for basic rendering

  **Commit**: YES
  - Message: `feat(gui): implement all WinPE GUI screens (Connectivity, Wizard, Progress, Completion)`
  - Files: `source/Xaml/WinPE/*.xaml`, `source/Private/WinPE/GUI/*.ps1`
  - Pre-commit: `./build.ps1 -Tasks build`

---

- [ ] 10. Implement Windows Image Apply Functions

  **What to do**:
  - Create `source/Private/WinPE/Image/Get-MCDWindowsImage.ps1` - List available images (cloud + local)
  - Create `source/Private/WinPE/Image/Save-MCDWindowsImage.ps1` - Download ESD from Microsoft
  - Create `source/Private/WinPE/Image/Expand-MCDWindowsImage.ps1` - Apply WIM/ESD to disk
  - Create `source/Private/WinPE/Image/Initialize-MCDDisk.ps1` - Partition and format disk
  - Handle: GPT partitioning, DISM apply, boot files (bcdboot)
  - Write Pester tests (mocked DISM calls)

  **Must NOT do**:
  - Don't support FFU format (WIM only for MVP)
  - Don't support Legacy BIOS partitioning

  **Parallelizable**: NO (depends on 8)

  **References**:
  - `source/Examples/OSD-master/Private/Disk/Initialize-OSDDisk.ps1` - Disk partitioning
  - `source/Examples/OSD-master/Private/Disk/New-OSDPartitionWindows.ps1` - Partition creation
  - `source/Examples/FFU-main/FFUDevelopment/WinPEDeployFFUFiles/ApplyFFU.ps1` - Disk operations

  **GPT Partition Layout** (from interview):
  ```
  Partition 1: EFI System (100 MB, FAT32)
  Partition 2: MSR (16 MB, no filesystem)
  Partition 3: Windows OS (remaining - recovery size)
  Partition 4: Recovery (optional, ~1 GB)
  ```

  **Image Apply Flow**:
  1. Clear-Disk (destructive!)
  2. Initialize-Disk -PartitionStyle GPT
  3. Create partitions (EFI, MSR, OS, optional Recovery)
  4. Format partitions
  5. Expand-WindowsImage -ImagePath <wim> -ApplyPath W:\ -Index 1
  6. bcdboot W:\Windows /s S: /f UEFI

  **Acceptance Criteria**:
  - [ ] Test files created: `tests/Unit/Private/WinPE/Image/*.tests.ps1`
  - [ ] `./build.ps1 -Tasks test -PesterPath tests/Unit/Private/WinPE/Image` → PASS
  - [ ] `Initialize-MCDDisk -DiskNumber 0` creates GPT partitions
  - [ ] `Expand-MCDWindowsImage` applies WIM to target partition
  - [ ] Boot files created via bcdboot
  - [ ] Manual verification: VM boots after deployment

  **Commit**: YES
  - Message: `feat(image): implement disk partitioning and Windows image apply`
  - Files: `source/Private/WinPE/Image/*.ps1`, `tests/Unit/Private/WinPE/Image/*.tests.ps1`
  - Pre-commit: `./build.ps1 -Tasks test -PesterPath tests/Unit/Private/WinPE/Image`

---

- [ ] 11. Implement Cleanup and Driver Functions

  **What to do**:
  - Create `source/Private/WinPE/Drivers/Add-MCDDrivers.ps1` - Inject drivers offline
  - Create `source/Private/WinPE/Cleanup/Complete-MCDDeployment.ps1` - Final cleanup
  - Create `source/Private/WinPE/Cleanup/Copy-MCDLogs.ps1` - Copy logs to target OS
  - Handle: Add-WindowsDriver offline, log copy to C:\Temp\MCD, reboot/shutdown

  **Must NOT do**:
  - Don't download cloud driver packs (local only for MVP)
  - Don't enable BitLocker (leave for Autopilot/Intune)

  **Parallelizable**: NO (depends on 10)

  **References**:
  - `source/Examples/OSD-master/Private/osdcloud-steps/Step-OSDCloudWinpeDriverPackCab.ps1` - Driver injection
  - `source/Examples/OSD-master/Private/osdcloud-steps/Step-OSDCloudWinpeCleanup.ps1` - Cleanup

  **Driver Injection**:
  ```powershell
  Add-WindowsDriver -Path "W:\" -Driver "D:\MCD\Drivers" -Recurse
  ```

  **Log Copy** (from interview):
  - Source: `X:\MCD\Logs\*`
  - Destination: `W:\Temp\MCD\`

  **Acceptance Criteria**:
  - [ ] Test files created: `tests/Unit/Private/WinPE/Drivers/*.tests.ps1`, `tests/Unit/Private/WinPE/Cleanup/*.tests.ps1`
  - [ ] `./build.ps1 -Tasks test` → PASS
  - [ ] `Add-MCDDrivers` injects drivers from USB cache
  - [ ] `Copy-MCDLogs` copies X:\MCD\Logs to W:\Temp\MCD
  - [ ] `Complete-MCDDeployment` triggers reboot with countdown

  **Commit**: YES
  - Message: `feat(deploy): implement driver injection and deployment cleanup`
  - Files: `source/Private/WinPE/Drivers/*.ps1`, `source/Private/WinPE/Cleanup/*.ps1`, `tests/Unit/Private/WinPE/*.tests.ps1`
  - Pre-commit: `./build.ps1 -Tasks test`

---

### Phase 4: Integration

- [ ] 12. Implement Public Entry Points

  **What to do**:
  - Create `source/Public/Start-MCDWorkspace.ps1` - Workspace entry point
  - Create `source/Public/Start-MCDWinPE.ps1` - WinPE entry point
  - Update module manifest to export these functions
  - Add proper comment-based help (SYNOPSIS, DESCRIPTION, EXAMPLES, PARAMETERS)

  **Must NOT do**:
  - Don't add complex parameter sets initially (keep simple)
  - Don't add aliases

  **Parallelizable**: NO (depends on 7, 11)

  **References**:
  - `source/Examples/OSD-master/Public/Start-OSDCloud.ps1` - OSDCloud entry point pattern
  - `source/Examples/OSD-master/Public/Start-OSDCloudGUI.ps1` - GUI launch pattern
  - Current placeholder: `source/Public/Get-Something.ps1` - Help format reference

  **Start-MCDWorkspace**:
  ```powershell
  function Start-MCDWorkspace {
      <# .SYNOPSIS Launches MCD Workspace dashboard... #>
      [CmdletBinding()]
      param(
          [string]$WorkspacePath = "$env:ProgramData\MCD\Workspaces\Default"
      )
      # Validate prerequisites
      # Initialize workspace if needed
      # Launch GUI
      Show-MCDWorkspaceDashboard -WorkspacePath $WorkspacePath
  }
  ```

  **Start-MCDWinPE**:
  ```powershell
  function Start-MCDWinPE {
      <# .SYNOPSIS Main entry point for MCD WinPE deployment... #>
      [CmdletBinding()]
      param()
      # Called from startnet.cmd
      # Runs initialization → Wizard → Deploy → Complete
      Initialize-MCDWinPE
  }
  ```

  **Acceptance Criteria**:
  - [ ] `Get-Command -Module MCD` shows Start-MCDWorkspace, Start-MCDWinPE
  - [ ] `Get-Help Start-MCDWorkspace -Full` shows proper help
  - [ ] `Start-MCDWorkspace` launches dashboard (on Windows)
  - [ ] Module manifest exports both functions
  - [ ] QA tests pass: `./build.ps1 -Tasks test -PesterTag FunctionalQuality`

  **Commit**: YES
  - Message: `feat(public): implement Start-MCDWorkspace and Start-MCDWinPE entry points`
  - Files: `source/Public/*.ps1`, `source/MCD.psd1`
  - Pre-commit: `./build.ps1 -Tasks test`

---

- [ ] 13. Integration Testing

  **What to do**:
  - Create `tests/Integration/MCD.Integration.tests.ps1` - Full workflow tests
  - Test: Module import, workspace creation, template creation (mocked ADK)
  - Test: End-to-end flow simulation
  - Verify code coverage >= 85%

  **Must NOT do**:
  - Don't run destructive disk operations in tests
  - Don't require real ADK installation for CI

  **Parallelizable**: NO (depends on 12)

  **References**:
  - `tests/QA/module.tests.ps1` - Existing QA test patterns
  - `build.yaml:107` - CodeCoverageThreshold: 85

  **Acceptance Criteria**:
  - [ ] Integration test file created: `tests/Integration/MCD.Integration.tests.ps1`
  - [ ] `./build.ps1 -Tasks test` → All tests PASS
  - [ ] Code coverage >= 85%
  - [ ] No PSScriptAnalyzer errors

  **Commit**: YES
  - Message: `test(integration): add integration tests and verify code coverage`
  - Files: `tests/Integration/*.tests.ps1`
  - Pre-commit: `./build.ps1 -Tasks test`

---

- [ ] 14. Manual End-to-End Verification

  **What to do**:
  - Create VM in Hyper-V for testing
  - Run Start-MCDWorkspace, create USB
  - Boot VM from USB, verify full WinPE flow
  - Deploy Windows, verify success
  - Document any issues found

  **Must NOT do**:
  - Don't automate this (manual verification)
  - Don't skip any screen in the flow

  **Parallelizable**: NO (final task)

  **Verification Procedure**:
  
  1. **Workspace Test**:
     ```powershell
     Import-Module MCD
     Start-MCDWorkspace
     # In GUI: Create Workspace → Build USB
     ```
  
  2. **Create Test VM**:
     ```powershell
     New-VM -Name "MCD-Test" -MemoryStartupBytes 4GB -Generation 2
     Set-VMFirmware -VMName "MCD-Test" -EnableSecureBoot On
     # Attach USB or ISO
     ```
  
  3. **WinPE Boot Test**:
     - Boot VM from MCD media
     - Verify: Connectivity screen (or skip if network OK)
     - Verify: Wizard shows and accepts input
     - Verify: Progress screen updates during deployment
     - Verify: Success screen with countdown
  
  4. **Post-Deployment**:
     - VM boots to Windows
     - Check C:\Temp\MCD\Logs for deployment logs

  **Acceptance Criteria**:
  - [ ] VM boots from MCD USB/ISO
  - [ ] All 5 WinPE screens display correctly
  - [ ] Windows deploys successfully
  - [ ] Logs copied to C:\Temp\MCD
  - [ ] Total deployment time noted

  **Commit**: NO (documentation only)

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `chore(structure): setup MCD folder structure` | source/** | build |
| 2 | `feat(classes): implement core MCD classes` | source/Classes/*, tests/Unit/Classes/* | test |
| 3 | `feat(core): implement core utility functions` | source/Private/Core/*, tests/** | test |
| 4 | `feat(adk): implement ADK detection and install` | source/Private/Workspace/ADK/*, tests/** | test |
| 5 | `feat(template): implement WinPE template creation` | source/Private/Workspace/Template/*, tests/** | test |
| 6 | `feat(media): implement USB and ISO creation` | source/Private/Workspace/Media/*, tests/** | test |
| 7 | `feat(gui): implement Workspace dashboard` | source/Xaml/Workspace/*, source/Private/Workspace/GUI/* | build |
| 8 | `feat(winpe): implement WinPE initialization` | source/Private/WinPE/Initialize/*, tests/** | test |
| 9 | `feat(gui): implement all WinPE GUI screens` | source/Xaml/WinPE/*, source/Private/WinPE/GUI/* | build |
| 10 | `feat(image): implement disk and image apply` | source/Private/WinPE/Image/*, tests/** | test |
| 11 | `feat(deploy): implement drivers and cleanup` | source/Private/WinPE/Drivers/*, source/Private/WinPE/Cleanup/* | test |
| 12 | `feat(public): implement entry points` | source/Public/*, source/MCD.psd1 | test |
| 13 | `test(integration): add integration tests` | tests/Integration/* | test |

---

## Success Criteria

### Verification Commands
```powershell
# Build and test
./build.ps1 -Tasks build        # Expected: Build succeeds
./build.ps1 -Tasks test         # Expected: All tests pass, coverage >= 85%

# Module functionality
Import-Module .\output\module\MCD\*\MCD.psd1
Get-Command -Module MCD         # Expected: Start-MCDWorkspace, Start-MCDWinPE

# Workspace launch
Start-MCDWorkspace              # Expected: Dashboard opens
```

### Final Checklist
- [ ] All 14 tasks completed
- [ ] All "Must Have" features present
- [ ] All "Must NOT Have" guardrails respected
- [ ] All tests pass
- [ ] Code coverage >= 85%
- [ ] Manual end-to-end verification successful
- [ ] Module imports and runs without errors
