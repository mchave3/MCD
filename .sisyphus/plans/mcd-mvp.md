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

### Authoritative Document
**THIS PLAN is authoritative for MVP scope.** The draft file (`.sisyphus/drafts/mcd-module-architecture.md`) contains the full interview including post-MVP features (Autopilot, cloud drivers, multi-language). For MVP, only features listed in "Must Have" below are in scope. Features marked as "Confirmed" in the draft but listed in "Must NOT Have" here are explicitly deferred to post-MVP.

### Self-Gap Analysis
**Identified Gaps Addressed**:
1. PowerShell version compatibility (5.1 required for WinPE) - will enforce in module manifest
2. WPF in WinPE limitations - documented, will test during implementation
3. ADK download URLs change over time - will scrape Microsoft page (pattern documented in Microsoft docs)
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
- Windows image apply from **local WIM on USB** (cloud ESD deferred to post-MVP)
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

### ShouldProcess Requirement (PSScriptAnalyzer Compliance)

This repo enforces PSScriptAnalyzer rules including `PSShouldProcess`. **All functions that modify system state MUST implement `SupportsShouldProcess`.**

**Functions requiring ShouldProcess**:
- `Install-MCDADK` - Installs software
- `New-MCDTemplate` - Creates/modifies files, mounts WIM
- `New-MCDUSB` - Formats disk (DESTRUCTIVE)
- `Update-MCDUSB` - Modifies disk contents
- `New-MCDISO` - Creates files
- `Initialize-MCDDisk` - Wipes and partitions disk (DESTRUCTIVE)
- `Expand-MCDWindowsImage` - Writes to disk
- `Add-MCDDrivers` - Modifies Windows image
- `Complete-MCDDeployment` - Reboots system

**Implementation Pattern**:
```powershell
function New-MCDUSB {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [int]$DiskNumber
    )
    
    if ($PSCmdlet.ShouldProcess("Disk $DiskNumber", "Format and create bootable USB")) {
        # Destructive operations here
        Clear-Disk -Number $DiskNumber -RemoveData -RemoveOEM -Confirm:$false
        # ...
    }
}
```

**ConfirmImpact Levels**:
- `High`: Destructive disk operations (`New-MCDUSB`, `Initialize-MCDDisk`)
- `Medium`: System modifications (`Install-MCDADK`, `Complete-MCDDeployment`)
- `Low`: File operations (`New-MCDTemplate`, `New-MCDISO`)

### PowerShell Version Compatibility (CRITICAL)

**Target**: Windows PowerShell 5.1 (required for WinPE)
**Module Manifest**: `PowerShellVersion = '5.1'`

**Compatibility Rules**:

| Feature | PS 5.1 | PS 7 | Action |
|---------|--------|------|--------|
| `Invoke-WebRequest` | Requires `-UseBasicParsing` | `-UseBasicParsing` deprecated but works | Always use `-UseBasicParsing` for compatibility |
| `ConvertFrom-Json` | Returns PSCustomObject | Returns PSCustomObject (or hashtable with `-AsHashtable`) | Use PSCustomObject property iteration (see JSON section) |
| WPF/XAML | Full support | Limited (Windows only) | WPF is core requirement; PS 7 on Windows works |
| `Get-Volume`, `Get-Disk` | Full support | Full support | No issues |

**Test Matrix**:

| Test Type | PowerShell Version | How to Run |
|-----------|-------------------|------------|
| CI (GitHub Actions) | PowerShell 7 (pwsh) | `./build.ps1 -Tasks test` - Uses Sampler defaults |
| Local Development | PowerShell 5.1 | `powershell -NoProfile -File ./build.ps1 -Tasks test` |
| WinPE Runtime | PowerShell 5.1 | Implicit (WinPE only has 5.1) |

**CI Compatibility Pattern**:

Functions using potentially-incompatible cmdlets MUST work on both:

```powershell
# In Invoke-WebRequest calls:
$Response = Invoke-WebRequest -Uri $Url -UseBasicParsing  # Always include -UseBasicParsing

# For hashtable needs from JSON:
# DON'T use: ConvertFrom-Json -AsHashtable (PS 7 only)
# DO use: PSCustomObject.PSObject.Properties iteration (works on both)
```

**Local Test Verification**:

Developers SHOULD verify on PS 5.1 before submitting:
```powershell
# Explicitly test on PS 5.1
powershell -NoProfile -Command "./build.ps1 -Tasks test"
```

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

### CI-Safe Test Strategy

Tests that require admin rights, ADK, internet, or destructive disk operations MUST:
1. Be tagged with `RequiresAdmin`, `RequiresADK`, `RequiresInternet`, or `DestructiveDisk`
2. Use mocks for CI environments
3. Have manual verification procedures documented

**Tag Usage in Pester:**
```powershell
Describe "Install-MCDADK" -Tag "RequiresAdmin", "RequiresInternet" {
    It "should install ADK silently" -Skip:(-not $IsAdmin) {
        # Real test - only runs when admin
    }
}

Describe "Install-MCDADK" -Tag "Unit" {
    It "should validate parameters" {
        # Mock-based test - runs in CI
    }
}
```

**CI Configuration (MUST UPDATE build.yaml in Task 1):**

Current state: `build.yaml:102` has `ExcludeTag:` with no values configured.

**Required Change** (add to Task 1):
```yaml
# In build.yaml, update ExcludeTag section:
Pester:
  ExcludeTag:
    - RequiresAdmin
    - RequiresADK
    - RequiresInternet
    - DestructiveDisk
```

**Enforcement:**
- CI (GitHub Actions / Azure Pipelines): Uses `./build.ps1 -Tasks test` which reads `ExcludeTag` from `build.yaml`
- Local admin runs: `./build.ps1 -Tasks test -PesterExcludeTag @()` to run ALL tests including CI-unsafe ones
- CI runs: All tests EXCEPT those tagged `RequiresAdmin`, `RequiresADK`, `RequiresInternet`, `DestructiveDisk`

### Manual Verification for GUI
- Manual testing with real USB + VM (Hyper-V)
- Screenshots for documentation

---

## WinPE Integration Details

### Startnet.cmd Location and Injection

**Source file location (CREATED IN TASK 5, does not exist initially):**
- `source/Resources/WinPE/startnet.cmd` - Created as part of Task 5 (Template Functions)
- The `source/Resources/` directory is also created in Task 1 (folder structure)

**Packaging (CRITICAL - build.yaml change required in Task 1):**
- Task 1 adds `Resources` to `build.yaml:CopyPaths`
- After build, file is at: `output/module/MCD/<version>/Resources/WinPE/startnet.cmd`
- At runtime (installed module): Use canonical module root pattern (see below)

**Canonical Module Root Pattern (USE EVERYWHERE)**:

All functions accessing module resources (XAML, Resources) MUST use this pattern:

```powershell
# Get module root - works for both development and installed module
$ModuleRoot = $PSScriptRoot
while ($ModuleRoot -and -not (Test-Path (Join-Path $ModuleRoot 'MCD.psd1'))) {
    $ModuleRoot = Split-Path $ModuleRoot -Parent
}
# Alternative (simpler, works after import):
$ModuleRoot = Split-Path (Get-Module MCD).Path

# Access resources
$StartnetPath = Join-Path $ModuleRoot 'Resources\WinPE\startnet.cmd'
$XamlPath = Join-Path $ModuleRoot 'Xaml\Workspace\Dashboard.xaml'
```

**All code snippets in this plan using `$PSScriptRoot/../` are illustrative only. Implementers MUST use the canonical `$ModuleRoot` pattern above.**

**Injection during template creation (New-MCDTemplate):**
1. Locate startnet.cmd in module: `$ModuleRoot = Split-Path (Get-Module MCD).Path; $StartnetPath = Join-Path $ModuleRoot 'Resources\WinPE\startnet.cmd'`
2. Mount WinPE `boot.wim` to temporary path (e.g., `C:\MCD\Mount`)
3. Copy startnet.cmd to `<MountPath>\Windows\System32\startnet.cmd`
4. This OVERWRITES the default ADK startnet.cmd

**Module injection into WinPE:**
1. During `New-MCDTemplate`, copy the built MCD module to:
   - `<MountPath>\Program Files\WindowsPowerShell\Modules\MCD\`
2. The module folder is copied from `output\module\MCD\<version>\`
3. XAML files are included via build.yaml CopyPaths

**PowerShellGet Injection for PSGallery Support (CRITICAL)**:

WinPE does NOT include PowerShellGet by default. To enable `Find-Module`/`Save-Module` in WinPE:

1. **During template creation** (in `New-MCDTemplate`), inject PowerShellGet module:
   - Source: `$env:ProgramFiles\WindowsPowerShell\Modules\PowerShellGet\*` (from host)
   - OR: Download from PSGallery during workspace setup and cache locally
   - Destination: `<MountPath>\Program Files\WindowsPowerShell\Modules\PowerShellGet\`

2. **Also inject PackageManagement** (PowerShellGet dependency):
   - Source: `$env:ProgramFiles\WindowsPowerShell\Modules\PackageManagement\*`
   - Destination: `<MountPath>\Program Files\WindowsPowerShell\Modules\PackageManagement\`

3. **TLS 1.2 Configuration** (required for PSGallery HTTPS):
   - Set via registry in mounted WIM:
   - Path: `<MountPath>\Windows\System32\config\SOFTWARE`
   - Load hive, set `HKLM\OFFLINE\Microsoft\.NETFramework\v4.0.30319\SchUseStrongCrypto` = 1
   - OR: Set at runtime in `Initialize-MCDWinPE`:
     ```powershell
     [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
     ```

4. **Fallback Strategy** (if PSGallery unavailable):
   - `Update-MCDModule` attempts PSGallery → on failure, logs warning and continues with USB-cached module
   - USB module is ALWAYS present (copied during media creation)
   - PSGallery update is opportunistic, not required

**Runtime paths (when WinPE boots):**
- WinPE RAM disk: `X:\`
- Module location: `X:\Program Files\WindowsPowerShell\Modules\MCD\`
- XAML files: `X:\Program Files\WindowsPowerShell\Modules\MCD\Xaml\`
- Working directory: `X:\MCD\` (created at runtime by Initialize-MCDWinPE)
- Logs: `X:\MCD\Logs\` (created at runtime)

**Before reboot, logs are copied:**
- Source: `X:\MCD\Logs\*`
- Destination: `<OsLetter>:\MCD\Logs\` (e.g., `W:\MCD\Logs\`)
- **Canonical log destination**: `<OsDrive>\MCD\Logs\` (NOT `Temp\MCD` or `Temp\MCD\Logs`)

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
  - Create `source/Resources/WinPE/` for startnet.cmd template
  - Create `source/Xaml/Workspace/` folder for workspace GUI
  - Remove placeholder files (Get-Something.ps1, Get-PrivateFunction.ps1, class files)
  - Remove or rewrite corresponding placeholder tests
  - Update module manifest (MCD.psd1) with PowerShellVersion = '5.1'
  - **Update build.yaml to exclude CI-unsafe tags** (see CI-Safe Test Strategy section)

  **Must NOT do**:
  - Don't create actual function files yet (just folders)
  - Don't modify build.yaml **EXCEPT** for: (1) ExcludeTag update, (2) adding Resources to CopyPaths

  **Parallelizable**: NO (first task)

  **References**:
  - `source/MCD.psd1:36` - PowerShellVersion currently '5.0', change to '5.1'
  - `source/Public/Get-Something.ps1` - Remove this placeholder
  - `source/Private/Get-PrivateFunction.ps1` - Remove this placeholder
  - `source/Classes/*.ps1` - Remove placeholder class files (1.class1.ps1, 2.class2.ps1, 3.class11.ps1, 4.class12.ps1)
  - `tests/Unit/Public/Get-Something.tests.ps1` - Remove or update (if exists)
  - `tests/Unit/Private/Get-PrivateFunction.tests.ps1` - Remove or update (if exists)
  - `tests/Unit/Classes/*.tests.ps1` - Remove placeholder class tests (if exist)
  - `build.yaml:10-13` - CopyPaths includes en-US and Xaml; **ADD Resources to this list**
  - `build.yaml:102-105` - ExcludeTag section; **ADD the 4 CI-unsafe tags here**

  **Acceptance Criteria**:
  - [ ] Folder structure exists: `ls source/Private/Core`, `ls source/Private/Workspace/ADK`, etc.
  - [ ] `ls source/Resources/WinPE` exists
  - [ ] `ls source/Xaml/Workspace` exists
  - [ ] Placeholder files removed from source/
  - [ ] Placeholder tests removed or updated (no failing tests for removed files)
  - [ ] `build.yaml` updated: `CopyPaths` includes `Resources` (for startnet.cmd packaging)
  - [ ] `build.yaml` updated: `ExcludeTag: [RequiresAdmin, RequiresADK, RequiresInternet, DestructiveDisk]`
  - [ ] `./build.ps1 -Tasks build` succeeds
  - [ ] Module manifest has PowerShellVersion = '5.1'

  **Commit**: YES
  - Message: `chore(structure): setup MCD folder structure, clean placeholders, configure CI tags`
  - Files: `source/Private/**`, `source/Public/**`, `source/Classes/**`, `source/Resources/**`, `source/Xaml/**`, `source/MCD.psd1`, `build.yaml`, `tests/**`
  - Pre-commit: `./build.ps1 -Tasks build`

---

- [ ] 2. Implement Core Classes

  **What to do**:
  - Create `source/Classes/1.MCDConfig.ps1` with properties and JSON serialization
  - Create `source/Classes/2.MCDWorkspace.ps1` with workspace state management
  - Create `source/Classes/3.MCDDeployment.ps1` with deployment runtime state
  - Create `source/Classes/4.MCDMediaBuilder.ps1` with media creation methods
  - Prefix with numbers for load order (PowerShell loads alphabetically)
  - Write Pester tests first (TDD)

  **Must NOT do**:
  - Don't implement complex logic yet (just structure + basic methods)
  - Don't add dependencies on functions that don't exist yet

  **Parallelizable**: NO (depends on 1)

  **References**:
  - Microsoft docs for ConvertTo-Json/ConvertFrom-Json for serialization pattern

  **MVP Config Schema (AUTHORITATIVE - NOT the draft)**:

  The draft file contains post-MVP fields. For MVP, implement ONLY these fields:

  ```json
  // workspace.json (MCDConfig)
  {
    "Version": "1.0.0",
    "WorkspacePath": "C:\\MCD\\Workspaces\\Default",
    "Defaults": {
      "Language": "en-US",
      "Edition": "Pro",
      "ComputerNameTemplate": "PC-{SERIAL}"
    },
    "Logging": {
      "Level": "Info",
      "Path": null
    }
  }
  ```

  **PowerShell 5.1 JSON Serialization (CRITICAL)**:

  Windows PowerShell 5.1 (`ConvertFrom-Json`) returns `PSCustomObject`, not hashtables.
  The class methods MUST handle this:

  ```powershell
  class MCDConfig {
      # ... properties ...
      
      static [MCDConfig]Load([string]$Path) {
          $Json = Get-Content -Path $Path -Raw | ConvertFrom-Json
          $Config = [MCDConfig]::new()
          
          # Copy simple properties
          $Config.Version = $Json.Version
          $Config.WorkspacePath = $Json.WorkspacePath
          
          # Convert PSCustomObject to hashtable for nested objects
          $Config.Defaults = @{}
          if ($Json.Defaults) {
              $Json.Defaults.PSObject.Properties | ForEach-Object {
                  $Config.Defaults[$_.Name] = $_.Value
              }
          }
          
          $Config.Logging = @{}
          if ($Json.Logging) {
              $Json.Logging.PSObject.Properties | ForEach-Object {
                  $Config.Logging[$_.Name] = $_.Value
              }
          }
          
          return $Config
      }
      
      [void]Save([string]$Path) {
          # Depth must be sufficient for nested hashtables
          $this | ConvertTo-Json -Depth 5 | Set-Content -Path $Path -Encoding UTF8
      }
  }
  ```

  **Missing Field Defaults**:
  - If a field is missing in JSON, use class default (property initializers)
  - Example: `[string]$Version = '1.0.0'` provides default if JSON omits `Version`

  **MVP Class Properties**:
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
      [int]$TargetDisk           # From wizard selection
      [string]$ImagePath         # Path to WIM/ESD file
      [int]$ImageIndex           # Resolved index in WIM
      [string]$ComputerName      # From wizard input
      [string]$OsLetter          # Dynamic, from Initialize-MCDDisk (e.g., 'W')
      [string]$EfiLetter         # Dynamic, from Initialize-MCDDisk (e.g., 'S')
      [hashtable]$Steps
      [MCDConfig]$Config
      [void]LogStep([string]$StepName, [string]$Message) { }
      [void]CopyLogsToTarget() { }
  }
  
  class MCDMediaBuilder {
      [MCDWorkspace]$Workspace
      [string]$OutputPath
      [void]CreateUSB([int]$DiskNumber) { }  # Note: [int] not [string]
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
  - [ ] `[MCDConfig]::Load()` and `.Save()` work with JSON files

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
  - Create `source/Private/Core/Get-AvailableDriveLetter.ps1` - Find available drive letter (for disk partitioning)
  - Write Pester tests first (TDD)
  - Use mocks for network tests in CI

  **Must NOT do**:
  - Don't use Write-Host (use Write-Verbose, Write-Warning, Write-Output)
  - Don't hardcode paths (use parameters or config)

  **Parallelizable**: NO (depends on 2)

  **References**:
  - Logging paths from interview:
    - Workspace: `$env:ProgramData\MCD\Logs\`
    - WinPE: `X:\MCD\Logs\`
  - PowerShell Test-NetConnection for network testing
  - Get-Disk cmdlet for disk enumeration

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

  **Logging Contract (AUTHORITATIVE)**:

  **Context Propagation (No Globals)**:

  The plan forbids global variables. Config/logging context is passed via:
  1. **Script-scoped context** set once at entry point
  2. **Parameter threading** for deep functions

  **Entry Point Context Setup**:
  ```powershell
  # In Start-MCDWorkspace (entry point):
  $script:MCDContext = @{
      Config = Get-MCDConfig -WorkspacePath $WorkspacePath
      IsWinPE = $false
      LogPath = $null  # Uses default from config or fallback
  }
  
  # In Start-MCDWinPE (entry point):
  $script:MCDContext = @{
      Config = Get-MCDConfig -Path 'X:\MCD\config.json' -ErrorAction SilentlyContinue
      IsWinPE = $true
      LogPath = 'X:\MCD\Logs'
      Deployment = [MCDDeployment]::new()
  }
  ```

  **Write-MCDLog Uses Context**:
  ```powershell
  function Write-MCDLog {
      param(
          [string]$Message,
          [ValidateSet('Info','Warning','Error','Debug')]
          [string]$Level = 'Info',
          [string]$Step,
          [string]$LogPath  # Explicit override takes precedence
      )
      
      # Path resolution using script-scoped context
      $EffectivePath = if ($LogPath) { $LogPath }
                       elseif ($script:MCDContext.LogPath) { $script:MCDContext.LogPath }
                       elseif ($script:MCDContext.Config.Logging.Path) { $script:MCDContext.Config.Logging.Path }
                       elseif ($script:MCDContext.IsWinPE) { 'X:\MCD\Logs' }
                       else { "$env:ProgramData\MCD\Logs" }
      # ... write to log
  }
  ```

  **For Tests**: Mock `$script:MCDContext` in BeforeAll, or pass explicit `-LogPath`.

  **Log Line Format**:
  ```
  [YYYY-MM-DD HH:mm:ss] [LEVEL] [STEP] Message text here
  ```
  Example: `[2024-01-15 14:32:45] [INFO] [ImageApply] Starting Windows image apply...`

  If `$Step` is empty, omit the step brackets:
  ```
  [2024-01-15 14:32:45] [WARNING] Network connectivity check failed
  ```

  **File Naming**:
  - Workspace operations: `MCD_<YYYYMMDD>.log` (daily rotation)
  - WinPE operations: `MCD_<SessionId>.log` (per-deployment)

  **Path Resolution Precedence** (first match wins):
  1. `-LogPath` parameter (explicit override)
  2. `$Deployment.Config.Logging.Path` (if config loaded)
  3. Environment-specific default:
     - Workspace: `$env:ProgramData\MCD\Logs\`
     - WinPE: `X:\MCD\Logs\`

  **Detection of WinPE Environment**:
  ```powershell
  $IsWinPE = Test-Path 'X:\Windows\System32\startnet.cmd'
  ```

  **Testable Acceptance Criteria for Write-MCDLog**:
  - [ ] When `-LogPath $TestDrive\test.log` is provided, writes to that file
  - [ ] Log line matches regex: `^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] \[(INFO|WARNING|ERROR|DEBUG)\]`
  - [ ] When `-Step 'ImageApply'` provided, line contains `[ImageApply]`
  - [ ] When no `-LogPath` and not WinPE, writes to `$env:ProgramData\MCD\Logs\`
  - [ ] Creates log directory if it doesn't exist

  **Test Mocking Strategy**:
  ```powershell
  # In tests - mock network calls
  Mock Test-NetConnection { return @{ TcpTestSucceeded = $true } }
  
  # In tests - mock disk enumeration
  Mock Get-Disk { return @(
      [PSCustomObject]@{ Number = 0; Size = 256GB; BusType = 'SATA' }
  )}
  ```

  **Acceptance Criteria**:
  - [ ] Test files created: `tests/Unit/Private/Core/*.tests.ps1`
  - [ ] All tests use mocks for external dependencies
  - [ ] `./build.ps1 -Tasks test -PesterPath tests/Unit/Private/Core` → PASS
  - [ ] `Write-MCDLog -Message "Test" -Level Info` creates log entry (mocked file system OK)
  - [ ] `Test-MCDAdminRights` returns boolean based on elevation status
  - [ ] `Test-MCDNetwork` uses mock in CI, real call when tagged RequiresInternet

  **Commit**: YES
  - Message: `feat(core): implement core utility functions with logging and validation`
  - Files: `source/Private/Core/*.ps1`, `tests/Unit/Private/Core/*.tests.ps1`
  - Pre-commit: `./build.ps1 -Tasks test -PesterPath tests/Unit/Private/Core`

---

### Phase 2: Workspace

- [ ] 4. Implement ADK Management Functions

  **What to do**:
  - Create `source/Private/Workspace/ADK/Get-MCDADK.ps1` - Detect installed ADK via registry
  - Create `source/Private/Workspace/ADK/Test-MCDADK.ps1` - Validate ADK installation
  - Create `source/Private/Workspace/ADK/Install-MCDADK.ps1` - Download and install ADK
  - Create `source/Private/Workspace/ADK/Get-MCDADKPaths.ps1` - Get ADK component paths
  - Write Pester tests (TDD) with mocks for registry and downloads

  **Must NOT do**:
  - Don't hardcode ADK download URLs (scrape from Microsoft page)
  - Don't assume specific ADK version

  **Parallelizable**: YES (with 5)

  **References**:
  - ADK install page: `https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install`
  - **ADK silent install reference**: `https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-offline-install` (contains feature names for `/features`)
  - **ADK feature names (from adksetup.exe /list)**: `OptionId.DeploymentTools`, `OptionId.WindowsPreinstallationEnvironment`
  - Registry path: `HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Kits\Installed Roots`

  **ADK Silent Install Command Pattern**:
  ```cmd
  # Download adksetup.exe from Microsoft, then run:
  adksetup.exe /quiet /norestart /features OptionId.DeploymentTools OptionId.WindowsPreinstallationEnvironment
  
  # To discover available features on any ADK version:
  adksetup.exe /list
  
  # Output includes lines like:
  #   OptionId.DeploymentTools
  #   OptionId.WindowsPreinstallationEnvironment
  #   OptionId.UserStateMigrationTool
  #   ... etc
  ```

  **ADK Download URL Discovery (for BOTH installers)**:

  The ADK page contains TWO distinct download links. `Install-MCDADK` must find and download both:

  1. **Base ADK** (adksetup.exe): Contains Deployment Tools, USMT, etc.
  2. **WinPE Add-on** (adkwinpesetup.exe): Contains WinPE optional components

  **Link Identification Strategy**:
  ```powershell
  # Fetch the ADK page
  $PageUrl = 'https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install'
  $Html = (Invoke-WebRequest -Uri $PageUrl -UseBasicParsing).Content
  
  # Parse for download links - look for go.microsoft.com/fwlink patterns
  # The page structure (as of 2024) has:
  # - "Download the Windows ADK" → first fwlink
  # - "Download the Windows PE add-on for the Windows ADK" → second fwlink
  
  # Extract all fwlinks
  $Links = [regex]::Matches($Html, 'https://go\.microsoft\.com/fwlink/\?linkid=\d+')
  
  # Identify by adjacent text (fragile but workable)
  # Pattern: Look for "Windows PE add-on" text near the link
  if ($Html -match 'Download the Windows ADK[^<]*<[^>]*href="(https://go\.microsoft\.com/fwlink/\?linkid=\d+)"') {
      $AdkUrl = $Matches[1]
  }
  if ($Html -match 'Windows PE add-on[^<]*<[^>]*href="(https://go\.microsoft\.com/fwlink/\?linkid=\d+)"') {
      $WinPEUrl = $Matches[1]
  }
  
  # Fallback: Known stable linkids (update with module releases)
  # These are fallbacks if page scraping fails
  $FallbackAdkUrl = 'https://go.microsoft.com/fwlink/?linkid=2243390'      # Windows 11 ADK
  $FallbackWinPEUrl = 'https://go.microsoft.com/fwlink/?linkid=2243391'   # Windows 11 WinPE add-on
  
  if (-not $AdkUrl) {
      Write-MCDLog -Message "ADK URL scraping failed, using fallback" -Level Warning
      $AdkUrl = $FallbackAdkUrl
  }
  if (-not $WinPEUrl) {
      Write-MCDLog -Message "WinPE URL scraping failed, using fallback" -Level Warning
      $WinPEUrl = $FallbackWinPEUrl
  }
  ```

  **Installation Sequence**:
  1. Download and run base ADK first: `adksetup.exe /quiet /features OptionId.DeploymentTools`
  2. Then download and run WinPE add-on: `adkwinpesetup.exe /quiet /features OptionId.WindowsPreinstallationEnvironment`
  3. Verify both paths exist (see ADK Detection section)

  **ADK Detection Pattern**:
  ```powershell
  # Registry paths to check
  $AdkRegPath = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Kits\Installed Roots'
  $AdkRoot = (Get-ItemProperty -Path $AdkRegPath -ErrorAction SilentlyContinue).KitsRoot10
  ```

  **ADK Tooling Invocation Details (CRITICAL)**:

  The ADK installs command-line tools that require specific invocation patterns.

  **WinPE Add-on Detection**:
  The WinPE add-on is a SEPARATE installer from the base ADK. Both must be installed.
  - Base ADK detection: `$AdkRoot` exists and `<AdkRoot>\Assessment and Deployment Kit\Deployment Tools\` exists
  - WinPE add-on detection: `<AdkRoot>\Assessment and Deployment Kit\Windows Preinstallation Environment\` exists
  - If WinPE add-on missing: `Install-MCDADK` must install BOTH installers

  **copype.cmd Location and Invocation**:
  ```powershell
  # copype.cmd is in the Deployment Tools folder
  $DeployToolsPath = Join-Path $AdkRoot 'Assessment and Deployment Kit\Deployment Tools'
  $CopypePath = Join-Path $DeployToolsPath 'amd64\copype.cmd'
  
  # copype requires DandISetEnv.bat to set environment variables
  # Option 1: Run via cmd.exe with environment setup
  $EnvBat = Join-Path $DeployToolsPath 'DandISetEnv.bat'
  $TempPath = 'C:\MCD\Temp\WinPE'
  
  # Invoke copype with proper environment
  $CmdArgs = "/c `"call `"$EnvBat`" && copype amd64 `"$TempPath`"`""
  Start-Process -FilePath 'cmd.exe' -ArgumentList $CmdArgs -Wait -NoNewWindow
  
  # Verify copype succeeded
  if (-not (Test-Path (Join-Path $TempPath 'media\boot.wim'))) {
      throw "copype failed to create WinPE template"
  }
  ```

  **oscdimg.exe Location (for ISO creation)**:
  ```powershell
  $OscdimgPath = Join-Path $DeployToolsPath 'amd64\Oscdimg\oscdimg.exe'
  
  # Verify oscdimg exists
  if (-not (Test-Path $OscdimgPath)) {
      throw "oscdimg.exe not found. ADK Deployment Tools may not be installed correctly."
  }
  
  # ISO creation command
  $BootFile = Join-Path $SourcePath 'boot\etfsboot.com'
  $EfiBoot = Join-Path $SourcePath 'efi\microsoft\boot\efisys.bin'
  & $OscdimgPath -m -o -u2 -udfver102 -bootdata:"2#p0,e,b$BootFile#pEF,e,b$EfiBoot" $SourcePath $OutputIso
  ```

  **Test Mocking Strategy**:
  ```powershell
  # Mock registry for CI
  Mock Get-ItemProperty { 
      return @{ KitsRoot10 = 'C:\Program Files (x86)\Windows Kits\10\' }
  } -ParameterFilter { $Path -like '*Windows Kits*' }
  
  # Mock web request for download URL scraping
  Mock Invoke-WebRequest { return @{ Content = '<html>...' } }
  ```

  **Acceptance Criteria**:
  - [ ] Test files created: `tests/Unit/Private/Workspace/ADK/*.tests.ps1`
  - [ ] Tests use mocks for registry access
  - [ ] `./build.ps1 -Tasks test -PesterPath tests/Unit/Private/Workspace/ADK` → PASS (CI-safe)
  - [ ] `Get-MCDADK` returns ADK info hashtable or $null if not installed
  - [ ] `Install-MCDADK` has tests tagged `RequiresAdmin`, `RequiresInternet` (skipped in CI)

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
  - Create `source/Resources/WinPE/startnet.cmd` - Template file for WinPE startup
  - Handle: copype, mount WIM, add optional components, inject drivers, copy module, copy startnet.cmd, dismount
  - Write Pester tests (TDD) with mocks for DISM operations

  **Must NOT do**:
  - Don't add multi-language support yet (en-US only for MVP)
  - Don't inject cloud driver packs (local only)

  **Parallelizable**: YES (with 4)

  **References**:
  - WinPE OCs to add: WMI, NetFX, Scripting, PowerShell, StorageWMI, DismCmdlets
  - Mount-WindowsImage cmdlet documentation
  - Add-WindowsPackage cmdlet for OCs

  **WPF in WinPE Prerequisites (CRITICAL)**:

  WPF requires .NET Framework and specific WinPE optional components. Without these, `PresentationFramework` will fail to load.

  **Required Optional Components (exact paths in ADK):**
  ```
  <ADK>\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\
  ├── WinPE-WMI.cab                    # Windows Management Instrumentation
  ├── en-us\WinPE-WMI_en-us.cab        # Language pack
  ├── WinPE-NetFx.cab                  # .NET Framework (REQUIRED FOR WPF)
  ├── en-us\WinPE-NetFx_en-us.cab      # Language pack
  ├── WinPE-Scripting.cab              # Scripting support
  ├── en-us\WinPE-Scripting_en-us.cab  # Language pack
  ├── WinPE-PowerShell.cab             # PowerShell (depends on NetFx, WMI, Scripting)
  ├── en-us\WinPE-PowerShell_en-us.cab # Language pack
  ├── WinPE-StorageWMI.cab             # Storage cmdlets
  ├── en-us\WinPE-StorageWMI_en-us.cab # Language pack
  ├── WinPE-DismCmdlets.cab            # DISM cmdlets
  └── en-us\WinPE-DismCmdlets_en-us.cab # Language pack
  ```

  **Installation Order** (dependencies matter):
  ```powershell
  # In New-MCDTemplate, after mounting boot.wim:
  $OcPath = Join-Path $AdkPath 'Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs'
  
  # Order: WMI → NetFx → Scripting → PowerShell → StorageWMI → DismCmdlets
  $Packages = @(
      'WinPE-WMI.cab', 'en-us\WinPE-WMI_en-us.cab',
      'WinPE-NetFx.cab', 'en-us\WinPE-NetFx_en-us.cab',
      'WinPE-Scripting.cab', 'en-us\WinPE-Scripting_en-us.cab',
      'WinPE-PowerShell.cab', 'en-us\WinPE-PowerShell_en-us.cab',
      'WinPE-StorageWMI.cab', 'en-us\WinPE-StorageWMI_en-us.cab',
      'WinPE-DismCmdlets.cab', 'en-us\WinPE-DismCmdlets_en-us.cab'
  )
  foreach ($pkg in $Packages) {
      Add-WindowsPackage -Path $MountPath -PackagePath (Join-Path $OcPath $pkg)
  }
  ```

  **WPF Verification Step** (in Task 5 acceptance criteria):
  - After template creation, mount the resulting boot.wim
  - Run: `dism /image:<MountPath> /get-packages | findstr NetFx`
  - Expected: Shows `WinPE-NetFx` as installed
  - OR: Boot the ISO in a VM and run `[System.Windows.Window]::new()` to verify WPF loads

  **Startnet.cmd Content** (source/Resources/WinPE/startnet.cmd):
  ```cmd
  wpeinit
  powercfg /s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
  powershell -NoLogo -ExecutionPolicy Bypass -Command "Start-MCDWinPE"
  ```

  **Template Creation Flow**:
  1. Run `copype amd64 <tempPath>` via ADK's Deployment Tools
  2. Mount `boot.wim` using `Mount-WindowsImage -Path <MountPath> -ImagePath <boot.wim> -Index 1`
  3. Add optional components from `<ADK>\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\` (see WPF Prerequisites above for exact order)
  4. Inject drivers from `Workspace\PEDrivers\` if present using `Add-WindowsDriver`
  5. **Copy MCD module into WinPE** (see Module Source Path below)
  6. **Copy PowerShellGet module** from host to `<MountPath>\Program Files\WindowsPowerShell\Modules\PowerShellGet\`
  7. **Copy PackageManagement module** from host to `<MountPath>\Program Files\WindowsPowerShell\Modules\PackageManagement\`
  8. Copy startnet.cmd from module's `Resources\WinPE\startnet.cmd` to `<MountPath>\Windows\System32\startnet.cmd`
  9. **Set ExecutionPolicy and TLS via offline registry** (see procedure below)
  10. Dismount and save using `Dismount-WindowsImage -Path <MountPath> -Save`
  11. Copy to `Workspace\Template\`

  **Module Source Path for WinPE Injection (Step 5)**:

  `New-MCDTemplate` needs to copy the MCD module into the WinPE image. The source depends on context:

  **Scenario A: Running from installed module** (typical user):
  ```powershell
  # Get the installed module path
  $ModuleRoot = Split-Path (Get-Module MCD).Path
  # Module is at: C:\Program Files\WindowsPowerShell\Modules\MCD\1.0.0\
  # Copy entire module folder
  $Destination = Join-Path $MountPath 'Program Files\WindowsPowerShell\Modules\MCD'
  Copy-Item -Path $ModuleRoot -Destination $Destination -Recurse
  ```

  **Scenario B: Running from development/build** (developers):
  ```powershell
  # During development, module is loaded from output folder
  $ModuleRoot = Split-Path (Get-Module MCD).Path
  # Module is at: E:\Github\MCD\output\module\MCD\0.0.1\
  # Same copy logic works - Get-Module.Path gives actual loaded location
  ```

  **Key Insight**: `(Get-Module MCD).Path` returns the **actual loaded module path**, regardless of whether it's installed or from build output. Use this as the canonical source.

  **Prerequisite Check**:
  ```powershell
  # At start of New-MCDTemplate, verify module is loaded
  $Module = Get-Module MCD
  if (-not $Module) {
      throw "MCD module must be imported before creating template. Run: Import-Module MCD"
  }
  $ModuleRoot = Split-Path $Module.Path
  ```

  **Offline Registry Edit Procedure (Step 9)**:

  WinPE uses its own registry hives which must be edited offline while the WIM is mounted.

  ```powershell
  # Registry hive paths in mounted WIM
  $SoftwareHive = Join-Path $MountPath 'Windows\System32\config\SOFTWARE'
  
  # Load hive to temporary location
  reg load 'HKLM\OFFLINE_SOFTWARE' $SoftwareHive
  
  # Set PowerShell ExecutionPolicy to Bypass
  # Key: HKLM\OFFLINE_SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell
  $PSKey = 'HKLM:\OFFLINE_SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell'
  if (-not (Test-Path $PSKey)) {
      New-Item -Path $PSKey -Force | Out-Null
  }
  Set-ItemProperty -Path $PSKey -Name 'ExecutionPolicy' -Value 'Bypass' -Type String
  
  # Set TLS 1.2 for .NET (required for PSGallery HTTPS)
  # Key: HKLM\OFFLINE_SOFTWARE\Microsoft\.NETFramework\v4.0.30319
  $NetKey = 'HKLM:\OFFLINE_SOFTWARE\Microsoft\.NETFramework\v4.0.30319'
  if (-not (Test-Path $NetKey)) {
      New-Item -Path $NetKey -Force | Out-Null
  }
  Set-ItemProperty -Path $NetKey -Name 'SchUseStrongCrypto' -Value 1 -Type DWord
  
  # Also set for 64-bit
  $NetKey64 = 'HKLM:\OFFLINE_SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319'
  if (-not (Test-Path $NetKey64)) {
      New-Item -Path $NetKey64 -Force | Out-Null
  }
  Set-ItemProperty -Path $NetKey64 -Name 'SchUseStrongCrypto' -Value 1 -Type DWord
  
  # Unload hive (CRITICAL - must unload before dismount)
  [gc]::Collect()  # Force garbage collection to release handles
  reg unload 'HKLM\OFFLINE_SOFTWARE'
  ```

  **Verification of Registry Edits**:
  - Reload hive after unload
  - Query: `reg query 'HKLM\OFFLINE_SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell' /v ExecutionPolicy`
  - Expected: `ExecutionPolicy    REG_SZ    Bypass`
  - Unload again before proceeding

  **Test Mocking Strategy**:
  ```powershell
  # Mock DISM cmdlets
  Mock Mount-WindowsImage { }
  Mock Add-WindowsPackage { }
  Mock Add-WindowsDriver { }
  Mock Dismount-WindowsImage { }
  Mock Copy-Item { }
  ```

  **Acceptance Criteria**:
  - [ ] Test files created: `tests/Unit/Private/Workspace/Template/*.tests.ps1`
  - [ ] `source/Resources/WinPE/startnet.cmd` created with correct content
  - [ ] Tests use mocks for DISM operations
  - [ ] `./build.ps1 -Tasks test -PesterPath tests/Unit/Private/Workspace/Template` → PASS (CI-safe)
  - [ ] `New-MCDTemplate` tests tagged `RequiresADK` (skipped in CI)
  - [ ] Template creation flow includes PowerShellGet and PackageManagement injection
  - [ ] Template creation flow includes all 6 WinPE OCs in correct order
  - [ ] Template creation flow is correctly sequenced (11 steps)
  - [ ] **WPF Verification** (manual, tagged `RequiresADK`): Mount created boot.wim → `dism /get-packages` shows WinPE-NetFx installed

  **Commit**: YES
  - Message: `feat(template): implement WinPE template creation from ADK`
  - Files: `source/Private/Workspace/Template/*.ps1`, `source/Resources/WinPE/startnet.cmd`, `tests/Unit/Private/Workspace/Template/*.tests.ps1`
  - Pre-commit: `./build.ps1 -Tasks test -PesterPath tests/Unit/Private/Workspace/Template`

---

- [ ] 6. Implement Media Creation Functions

  **What to do**:
  - Create `source/Private/Workspace/Media/New-MCDUSB.ps1` - Create bootable USB (dual partition)
  - Create `source/Private/Workspace/Media/Update-MCDUSB.ps1` - Smart update existing USB (robocopy pattern)
  - Create `source/Private/Workspace/Media/New-MCDISO.ps1` - Create bootable ISO
  - Create `source/Private/Workspace/Media/Get-MCDUSBDrive.ps1` - Enumerate USB drives
  - Handle: partitioning, formatting, copying files, oscdimg
  - Write Pester tests (TDD) with mocks for disk operations

  **Must NOT do**:
  - Don't support disks > 2TB (USB limitation)
  - Don't use Legacy BIOS boot files

  **Parallelizable**: NO (depends on 5 - needs template)

  **References**:
  - Clear-Disk, New-Partition, Format-Volume cmdlets
  - Robocopy for smart USB updates
  - oscdimg.exe from ADK for ISO creation

  **USB Partition Layout** (from interview):
  ```
  Partition 1: FAT32 (~2GB) - Label "WinPE" or "MCD"
  Partition 2: NTFS (remaining) - Label "MCDData"
  ```

  **USB Cache Structure** (from interview):
  ```
  MCDData:\MCD\
  ├── Images\          # Windows WIM/ESD files
  ├── Drivers\         # Driver packages (.inf folders)
  ├── Autopilot\       # PLACEHOLDER: Created empty, unused in MVP
  ├── PPKG\            # PLACEHOLDER: Created empty, unused in MVP
  ├── Scripts\         # Custom scripts (post-MVP feature)
  └── Logs\            # Log destination (copied from WinPE)
  ```

  **MVP Note**: The `Autopilot\`, `PPKG\`, and `Scripts\` folders are created as empty placeholders for future use. No MVP code reads from or writes to these folders. They exist to establish the USB structure for post-MVP features without requiring a breaking change to the media format.

  **Test Mocking Strategy**:
  ```powershell
  # Mock disk cmdlets
  Mock Get-Disk { return @([PSCustomObject]@{ Number = 2; Size = 32GB; BusType = 'USB' }) }
  Mock Clear-Disk { }
  Mock New-Partition { return [PSCustomObject]@{ DriveLetter = 'E' } }
  Mock Format-Volume { }
  Mock Set-Partition { }
  ```

  **Acceptance Criteria**:
  - [ ] Test files created: `tests/Unit/Private/Workspace/Media/*.tests.ps1`
  - [ ] Tests use mocks for disk operations
  - [ ] `./build.ps1 -Tasks test -PesterPath tests/Unit/Private/Workspace/Media` → PASS (CI-safe)
  - [ ] `New-MCDUSB` tests tagged `DestructiveDisk` (skipped in CI)
  - [ ] Manual verification documented: USB boots in Hyper-V

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
  - `source/Xaml/WinPE/MainWindow.xaml` - Use this as base styling reference (DockPanel layout, Segoe UI font, similar spacing)
  - Note: MainWindow.xaml has hardcoded French text - Dashboard should use English and be data-bound

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

  **WPF Loading Pattern** (uses canonical module root):
  ```powershell
  function Show-MCDWorkspaceDashboard {
      param([string]$WorkspacePath)
      
      # Canonical module root resolution
      $ModuleRoot = Split-Path (Get-Module MCD).Path
      $XamlPath = Join-Path $ModuleRoot 'Xaml\Workspace\Dashboard.xaml'
      
      # Load XAML
      [xml]$Xaml = Get-Content $XamlPath
      
      # Create window
      $Reader = [System.Xml.XmlNodeReader]::new($Xaml)
      Add-Type -AssemblyName PresentationFramework
      $Window = [System.Windows.Markup.XamlReader]::Load($Reader)
      
      # Wire up events...
      $Window.ShowDialog()
  }
  ```

  **Acceptance Criteria**:
  - [ ] XAML file created: `source/Xaml/Workspace/Dashboard.xaml`
  - [ ] `Show-MCDWorkspaceDashboard` function exists and loads XAML
  - [ ] Basic/Advanced toggle visibility works
  - [ ] "Build Media" tile click handler exists (can be empty for now)
  - [ ] `./build.ps1 -Tasks build` succeeds (XAML copied to output)
  - [ ] Manual verification: Window renders correctly in Windows

  **Commit**: YES
  - Message: `feat(gui): implement Workspace dashboard with Basic/Advanced mode`
  - Files: `source/Xaml/Workspace/*.xaml`, `source/Private/Workspace/GUI/*.ps1`
  - Pre-commit: `./build.ps1 -Tasks build`

---

### Phase 3: WinPE

- [ ] 8. Implement WinPE Initialization Functions

  **What to do**:
  - Create `source/Private/WinPE/Initialize/Initialize-MCDWinPE.ps1` - Main WinPE startup orchestrator
  - Create `source/Private/WinPE/Initialize/Test-MCDConnectivity.ps1` - Check network
  - Create `source/Private/WinPE/Initialize/Update-MCDModule.ps1` - Download latest from PSGallery
  - Create `source/Private/WinPE/Initialize/Get-MCDUSBContent.ps1` - Find USB data partition
  - Write Pester tests (mocked, since actual WinPE not available)

  **Must NOT do**:
  - Don't assume internet is always available (fallback to USB module)
  - Don't block on module update failure

  **Parallelizable**: NO (depends on 3)

  **References**:
  - Find-Module, Save-Module for PSGallery operations
  - Get-Volume for finding USB partitions

  **Get-MCDUSBContent Contract (CRITICAL - Used by All WinPE Functions)**:

  This function discovers the USB data partition at runtime. **NO function should hardcode drive letters like `D:`**.

  ```powershell
  function Get-MCDUSBContent {
      <#
      .SYNOPSIS
      Discovers the MCD USB data partition and returns paths to content.
      
      .OUTPUTS
      Hashtable with paths, or $null if not found:
      @{
          DriveLetter = 'E'              # Actual drive letter (varies per system)
          RootPath    = 'E:\'            # Root of data partition
          ImagesPath  = 'E:\MCD\Images'  # Windows images
          DriversPath = 'E:\MCD\Drivers' # Driver packages
          ScriptsPath = 'E:\MCD\Scripts' # Custom scripts
          LogsPath    = 'E:\MCD\Logs'    # Log destination
          ConfigPath  = 'E:\MCD\config.json' # Optional config file
      }
      #>
  }
  ```

  **Discovery Logic**:
  1. `Get-Volume | Where-Object { $_.FileSystemLabel -eq 'MCDData' }`
  2. If not found by label, look for `MCD\config.json` file on any NTFS volume
  3. Returns $null if no USB data partition found → triggers error in wizard

  **Consumer Functions MUST Use This Contract**:
  - `Get-MCDWindowsImage` → uses `$USBContent.ImagesPath`
  - `Add-MCDDrivers` → uses `$USBContent.DriversPath`
  - `Copy-MCDLogs` → uses `$USBContent.LogsPath` as additional destination
  - `Initialize-MCDWinPE` → calls `Get-MCDUSBContent` once and passes to child functions

  **Initialization Flow**:
  1. Create working directory `X:\MCD\` and `X:\MCD\Logs\`
  2. Check network connectivity via `Test-MCDConnectivity`
  3. If no network → Call `Show-MCDConnectivity` (WiFi GUI)
  4. Try update module from PSGallery via `Update-MCDModule`
  5. On failure → Log warning, continue with USB module
  6. Launch wizard via `Show-MCDWizard`
  7. Execute deployment based on wizard selections
  8. Show completion screen

  **Test Mocking Strategy**:
  ```powershell
  # Mock file system operations for X: drive
  Mock New-Item { }
  Mock Test-Path { return $true }
  
  # Mock PSGallery
  Mock Find-Module { return @{ Version = '1.0.0' } }
  Mock Save-Module { }
  
  # Mock GUI calls
  Mock Show-MCDConnectivity { }
  Mock Show-MCDWizard { return @{ Language = 'en-US'; Edition = 'Pro' } }
  ```

  **Acceptance Criteria**:
  - [ ] Test files created: `tests/Unit/Private/WinPE/Initialize/*.tests.ps1`
  - [ ] Tests use mocks for all external dependencies
  - [ ] `./build.ps1 -Tasks test -PesterPath tests/Unit/Private/WinPE/Initialize` → PASS (CI-safe)
  - [ ] `Initialize-MCDWinPE` orchestrates the correct flow
  - [ ] Network failure triggers WiFi GUI
  - [ ] Module update failure is non-blocking

  **Commit**: YES
  - Message: `feat(winpe): implement WinPE initialization and module update flow`
  - Files: `source/Private/WinPE/Initialize/*.ps1`, `tests/Unit/Private/WinPE/Initialize/*.tests.ps1`
  - Pre-commit: `./build.ps1 -Tasks test -PesterPath tests/Unit/Private/WinPE/Initialize`

---

- [ ] 9. Implement WinPE GUI Screens (4 screens)

  **What to do**:
  - 9a. Create `source/Xaml/WinPE/Connectivity.xaml` + `source/Private/WinPE/GUI/Show-MCDConnectivity.ps1` - WiFi connection
  - 9b. Create `source/Xaml/WinPE/Wizard.xaml` + `source/Private/WinPE/GUI/Show-MCDWizard.ps1` - Deployment options
  - 9c. Enhance existing `source/Xaml/WinPE/MainWindow.xaml` + `source/Private/WinPE/GUI/Show-MCDProgress.ps1` - Progress display
  - 9d. Create `source/Xaml/WinPE/Success.xaml`, `source/Xaml/WinPE/Error.xaml` + handlers

  **Must NOT do**:
  - Don't implement Autopilot selection (post-MVP)
  - Don't add cloud driver pack download (post-MVP)

  **Parallelizable**: YES (9a, 9b, 9c, 9d are independent)

  **References**:
  - `source/Xaml/WinPE/MainWindow.xaml` - Base layout exists; enhance by making text bindable
  - Use consistent styling: Segoe UI font, similar color scheme

  **MainWindow.xaml Enhancement**:
  - Current: Hardcoded strings like "Application de l'image Windows..."
  - Change to: Data-bound properties (`Text="{Binding CurrentStep}"`, etc.)
  - Add named elements for programmatic access (`x:Name="StepText"`, etc.)

  **Wizard Screen Elements** (from interview):
  - Computer name input (TextBox with template preview)
  - Language dropdown (ComboBox, filtered by config)
  - OS Edition dropdown (ComboBox, filtered by config)
  - Driver pack dropdown (ComboBox, auto-detected + manual)
  - **Target Disk dropdown** (ComboBox, populated from Get-MCDDisk)
  - "Deploy" button

  **WinPE Wizard Deployment Selection Contract (CRITICAL)**:

  The wizard collects all deployment parameters. Here's the authoritative contract:

  **Wizard Output Schema** (Show-MCDWizard returns this hashtable):
  ```powershell
  @{
      ComputerName  = 'PC-ABC123'           # String, from user input
      Language      = 'en-US'               # String, from dropdown
      Edition       = 'Pro'                 # String, from dropdown (e.g., 'Home', 'Pro', 'Enterprise')
      TargetDisk    = 2                     # Int, disk number from Get-MCDDisk
      ImagePath     = 'E:\MCD\Images\install.wim'  # String, path to WIM/ESD
      ImageIndex    = 6                     # Int, resolved index (see below)
  }
  ```

  **Edition → ImageIndex Resolution**:
  The wizard must resolve the user's Edition selection to a concrete WIM index:
  ```powershell
  # In Show-MCDWizard, after user selects Edition:
  $Images = Get-WindowsImage -ImagePath $ImagePath
  $Match = $Images | Where-Object { $_.ImageName -match $Edition }
  
  if ($Match.Count -eq 1) {
      $ImageIndex = $Match.ImageIndex
  }
  elseif ($Match.Count -gt 1) {
      # Multiple matches (e.g., "Pro" matches "Pro" and "Pro N")
      # Prefer exact match, or first match
      $Exact = $Match | Where-Object { $_.ImageName -eq "Windows 11 $Edition" -or $_.ImageName -eq "Windows 10 $Edition" }
      $ImageIndex = if ($Exact) { $Exact[0].ImageIndex } else { $Match[0].ImageIndex }
      Write-MCDLog -Message "Multiple editions matched '$Edition', using index $ImageIndex" -Level Warning
  }
  else {
      # No match - show error, don't proceed
      throw "Edition '$Edition' not found in $ImagePath. Available: $($Images.ImageName -join ', ')"
  }
  ```

  **Flow: Wizard Output → MCDDeployment → Functions**:
  ```powershell
  # In Initialize-MCDWinPE, after wizard returns:
  $WizardResult = Show-MCDWizard -USBContent $USBContent
  
  # Create deployment object with all parameters
  $Deployment = [MCDDeployment]::new()
  $Deployment.SessionId = [guid]::NewGuid().ToString()
  $Deployment.TargetDisk = $WizardResult.TargetDisk
  $Deployment.ImagePath = $WizardResult.ImagePath
  $Deployment.ImageIndex = $WizardResult.ImageIndex
  $Deployment.ComputerName = $WizardResult.ComputerName
  # OsLetter and EfiLetter set later by Initialize-MCDDisk
  
  # Execute deployment (pseudo-code)
  $DiskResult = Initialize-MCDDisk -DiskNumber $Deployment.TargetDisk
  $Deployment.OsLetter = $DiskResult.OsLetter
  $Deployment.EfiLetter = $DiskResult.EfiLetter
  
  Expand-MCDWindowsImage -ImagePath $Deployment.ImagePath -Index $Deployment.ImageIndex -OsLetter $Deployment.OsLetter
  Add-MCDDrivers -USBContent $USBContent -Deployment $Deployment
  # etc.
  ```

  **Acceptance Criteria**:
  - [ ] XAML files created: Connectivity.xaml, Wizard.xaml, Success.xaml, Error.xaml
  - [ ] MainWindow.xaml enhanced with data binding
  - [ ] All Show-MCD* functions load and display their windows
  - [ ] Show-MCDWizard returns hashtable with selected options
  - [ ] Show-MCDProgress updates step name and percentage via binding
  - [ ] Show-MCDSuccess shows countdown timer
  - [ ] Show-MCDError shows error message
  - [ ] `./build.ps1 -Tasks build` succeeds
  - [ ] Manual verification: Windows render correctly in Windows (simulates WinPE)

  **Commit**: YES
  - Message: `feat(gui): implement all WinPE GUI screens (Connectivity, Wizard, Progress, Completion)`
  - Files: `source/Xaml/WinPE/*.xaml`, `source/Private/WinPE/GUI/*.ps1`
  - Pre-commit: `./build.ps1 -Tasks build`

---

- [ ] 10. Implement Windows Image Apply Functions

  **What to do**:
  - Create `source/Private/WinPE/Image/Get-MCDWindowsImage.ps1` - List available images from USB
  - Create `source/Private/WinPE/Image/Save-MCDWindowsImage.ps1` - **STUB: throws NotImplementedException** (cloud ESD deferred)
  - Create `source/Private/WinPE/Image/Expand-MCDWindowsImage.ps1` - Apply WIM/ESD to disk
  - Create `source/Private/WinPE/Image/Initialize-MCDDisk.ps1` - Partition and format disk (DESTRUCTIVE), returns dynamic drive letters
  - Handle: GPT partitioning, DISM apply, boot files (bcdboot)
  - Write Pester tests with mocks for all disk/DISM operations

  **Must NOT do**:
  - Don't support FFU format (WIM only for MVP)
  - Don't support Legacy BIOS partitioning

  **Parallelizable**: NO (depends on 8)

  **References**:
  - Clear-Disk, Initialize-Disk, New-Partition, Format-Volume cmdlets
  - Expand-WindowsImage cmdlet (DISM)
  - bcdboot.exe for boot configuration

  **Microsoft ESD Download Mechanism - MVP DECISION (AUTHORITATIVE)**:

  **MVP SCOPE: LOCAL WIM ONLY. Cloud ESD is DEFERRED to post-MVP.**

  The function `Save-MCDWindowsImage.ps1` will be created as a **stub** in MVP:
  - Function signature defined
  - Throws `[NotImplementedException]` with message: "Cloud ESD download is planned for a future release. Please use local WIM files."
  - This allows the wizard UI to show a disabled "Download from Cloud" option for future use

  **MVP Implementation Path**:
  - User pre-downloads Windows ISO and extracts `install.wim` or `install.esd` to USB
  - Location: `<USBDataPartition>\MCD\Images\install.wim`
  - `Get-MCDWindowsImage` enumerates this folder
  - No network required for image deployment
  - **This is the ONLY supported path in MVP**

  **Post-MVP Cloud ESD Notes** (for reference only, NOT implemented in MVP):
  - Use Windows Update Catalog API or known-good direct URLs
  - Cache downloaded ESDs on USB for reuse
  - Endpoint patterns documented in code comments for future implementation

  **Get-MCDWindowsImage Contract**:
  ```powershell
  # Returns array of available images
  # $USBContent comes from Get-MCDUSBContent
  Get-MCDWindowsImage -ImagesPath $USBContent.ImagesPath
  # Output example (drive letter varies):
  @(
      @{ Name = 'Windows 11 Pro'; Index = 6; Path = 'E:\MCD\Images\install.wim'; Source = 'USB' }
      @{ Name = 'Windows 11 Home'; Index = 1; Path = 'E:\MCD\Images\install.wim'; Source = 'USB' }
  )
  ```

  **File Naming/Caching (if cloud download implemented)**:
  - Download to: `<USBDataPartition>\MCD\Images\<ProductName>_<Version>_<Language>.esd`
  - Example: `Windows11_23H2_en-US.esd`
  - Cache indefinitely; user manually deletes old versions

  **GPT Partition Layout** (from interview):
  ```
  Partition 1: EFI System (100 MB, FAT32, GptType = {c12a7328-f81f-11d2-ba4b-00a0c93ec93b})
  Partition 2: MSR (16 MB, no filesystem, GptType = {e3c9e316-0b5c-4db8-817d-f92df00215ae})
  Partition 3: Windows OS (remaining - recovery size)
  Partition 4: Recovery (optional, ~1 GB, GptType = {de94bba4-06d1-4d40-a16a-bfd50179d6ac})
  ```

  **Drive Letter Assignment Strategy (CRITICAL)**:

  The image apply flow uses `S:` for EFI and `W:` for Windows OS. These are **assigned dynamically**, not assumed available:

  ```powershell
  # In Initialize-MCDDisk:
  # 1. Create EFI partition WITHOUT drive letter initially
  $EfiPartition = New-Partition -DiskNumber $DiskNumber -Size 100MB -GptType '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}'
  
  # 2. Assign first available letter (prefer S, fallback to any)
  $EfiLetter = Get-AvailableDriveLetter -Preferred 'S'
  Set-Partition -InputObject $EfiPartition -NewDriveLetter $EfiLetter
  
  # 3. Same for OS partition (prefer W, fallback to any)
  $OsPartition = New-Partition -DiskNumber $DiskNumber -UseMaximumSize
  $OsLetter = Get-AvailableDriveLetter -Preferred 'W'
  Set-Partition -InputObject $OsPartition -NewDriveLetter $OsLetter
  
  # 4. Return the actual letters for use by subsequent functions
  return @{ EfiLetter = $EfiLetter; OsLetter = $OsLetter }
  ```

  **Helper Function Required** (add to Core):
  ```powershell
  function Get-AvailableDriveLetter {
      param([char]$Preferred = 'W')
      $Used = (Get-Volume).DriveLetter
      if ($Preferred -notin $Used) { return $Preferred }
      # Fallback: find any available letter D-Z
      'D'..'Z' | Where-Object { $_ -notin $Used } | Select-Object -First 1
  }
  ```

  **Consumers use returned letters, NOT hardcoded**:
  - `Expand-WindowsImage -ApplyPath "$($Disk.OsLetter):\"`
  - `bcdboot "$($Disk.OsLetter):\Windows" /s "$($Disk.EfiLetter):" /f UEFI`

  **Image Apply Flow** (uses dynamic drive letters from Initialize-MCDDisk):
  1. `$DiskInfo = Initialize-MCDDisk -DiskNumber $Deployment.TargetDisk` → returns `@{ EfiLetter; OsLetter }`
  2. `Clear-Disk -Number $Deployment.TargetDisk -RemoveData -RemoveOEM -Confirm:$false` (DESTRUCTIVE!)
  3. `Initialize-Disk -Number $Deployment.TargetDisk -PartitionStyle GPT`
  4. Create EFI partition with dynamic letter assignment (see Drive Letter Strategy above)
  5. Create MSR: `New-Partition -DiskNumber $Deployment.TargetDisk -Size 16MB -GptType '{e3c9e316-0b5c-4db8-817d-f92df00215ae}'`
  6. Create OS partition with dynamic letter assignment
  7. Format: `Format-Volume -DriveLetter $DiskInfo.EfiLetter -FileSystem FAT32`, `Format-Volume -DriveLetter $DiskInfo.OsLetter -FileSystem NTFS`
  8. `Expand-WindowsImage -ImagePath $Deployment.ImagePath -ApplyPath "$($DiskInfo.OsLetter):\" -Index $Deployment.ImageIndex`
  9. `bcdboot "$($DiskInfo.OsLetter):\Windows" /s "$($DiskInfo.EfiLetter):" /f UEFI`

  **Test Mocking Strategy**:
  ```powershell
  # Mock all destructive operations
  Mock Clear-Disk { }
  Mock Initialize-Disk { }
  Mock New-Partition { return [PSCustomObject]@{ DriveLetter = 'W' } }
  Mock Format-Volume { }
  Mock Expand-WindowsImage { }
  Mock Start-Process { } -ParameterFilter { $FilePath -eq 'bcdboot' }
  ```

  **Acceptance Criteria**:
  - [ ] Test files created: `tests/Unit/Private/WinPE/Image/*.tests.ps1`
  - [ ] ALL disk operations are mocked in tests
  - [ ] `./build.ps1 -Tasks test -PesterPath tests/Unit/Private/WinPE/Image` → PASS (CI-safe)
  - [ ] Tests for actual disk operations tagged `DestructiveDisk` and skipped
  - [ ] Correct partition GUIDs used for GPT
  - [ ] `Initialize-MCDDisk` returns hashtable with `EfiLetter` and `OsLetter`
  - [ ] `Save-MCDWindowsImage` throws `[NotImplementedException]` (stub for post-MVP)
  - [ ] All image apply functions use dynamic drive letters from `Initialize-MCDDisk`
  - [ ] Manual verification documented: VM boots after deployment

  **Commit**: YES
  - Message: `feat(image): implement disk partitioning and Windows image apply`
  - Files: `source/Private/WinPE/Image/*.ps1`, `tests/Unit/Private/WinPE/Image/*.tests.ps1`
  - Pre-commit: `./build.ps1 -Tasks test -PesterPath tests/Unit/Private/WinPE/Image`

---

- [ ] 11. Implement Cleanup and Driver Functions

  **What to do**:
  - Create `source/Private/WinPE/Drivers/Add-MCDDrivers.ps1` - Inject drivers offline
  - Create `source/Private/WinPE/Cleanup/Complete-MCDDeployment.ps1` - Final cleanup and reboot
  - Create `source/Private/WinPE/Cleanup/Copy-MCDLogs.ps1` - Copy logs to target OS
  - Handle: Add-WindowsDriver offline, log copy to `<OsDrive>\MCD\Logs\` (canonical destination), countdown reboot

  **Must NOT do**:
  - Don't download cloud driver packs (local only for MVP)
  - Don't enable BitLocker (leave for Autopilot/Intune)

  **Parallelizable**: NO (depends on 10)

  **References**:
  - Add-WindowsDriver cmdlet with -Path for offline injection
  - Copy-Item for log copying
  - Restart-Computer for reboot (with -Delay for countdown)

  **Driver Injection** (uses deployment state, NOT hardcoded drive letters):
  ```powershell
  # $Deployment is MCDDeployment instance passed from orchestrator
  # Contains OsLetter from Initialize-MCDDisk result
  param(
      [hashtable]$USBContent,
      [MCDDeployment]$Deployment
  )
  
  $DriverPath = $USBContent.DriversPath  # e.g., 'E:\MCD\Drivers'
  $OsPath = "$($Deployment.OsLetter):\"  # Dynamic, e.g., 'W:\' or 'V:\'
  
  if ($DriverPath -and (Test-Path $DriverPath)) {
      Add-WindowsDriver -Path $OsPath -Driver $DriverPath -Recurse -ErrorAction SilentlyContinue
  }
  ```

  **Log Copy** (uses deployment state, canonical destination):
  ```powershell
  param(
      [hashtable]$USBContent,
      [MCDDeployment]$Deployment
  )
  
  # Primary destination: Target OS (canonical: <OsDrive>\MCD\Logs)
  $OsPath = "$($Deployment.OsLetter):"  # e.g., 'W:' or 'V:'
  $LogDestOS = Join-Path $OsPath 'MCD\Logs'
  New-Item -Path $LogDestOS -ItemType Directory -Force
  Copy-Item -Path "X:\MCD\Logs\*" -Destination $LogDestOS -Recurse
  
  # Secondary destination: USB (if available, for troubleshooting boot failures)
  if ($USBContent.LogsPath) {
      Copy-Item -Path "X:\MCD\Logs\*" -Destination $USBContent.LogsPath -Recurse -ErrorAction SilentlyContinue
  }
  ```

  **Acceptance Criteria**:
  - [ ] Test files created: `tests/Unit/Private/WinPE/Drivers/*.tests.ps1`, `tests/Unit/Private/WinPE/Cleanup/*.tests.ps1`
  - [ ] Tests mock Add-WindowsDriver, Copy-Item, Restart-Computer
  - [ ] `./build.ps1 -Tasks test` → PASS (all tests including these)
  - [ ] `Add-MCDDrivers` handles missing driver folder gracefully
  - [ ] `Copy-MCDLogs` creates destination directory
  - [ ] `Complete-MCDDeployment` shows countdown before reboot

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
  - Update module manifest to export these functions (FunctionsToExport)
  - Add proper comment-based help (SYNOPSIS, DESCRIPTION, EXAMPLES, PARAMETERS)
  - Ensure help meets QA requirements (description > 40 chars, parameter descriptions, examples)

  **Must NOT do**:
  - Don't add complex parameter sets initially (keep simple)
  - Don't add aliases

  **Parallelizable**: NO (depends on 7, 11)

  **References**:
  - `tests/QA/module.tests.ps1` - QA requirements for help
  - `source/MCD.psd1:72` - FunctionsToExport array

  **Start-MCDWorkspace**:
  ```powershell
  function Start-MCDWorkspace {
      <#
      .SYNOPSIS
      Launches the MCD Workspace dashboard for creating deployment media.
      
      .DESCRIPTION
      Start-MCDWorkspace opens the MCD Workspace graphical interface which allows
      administrators to configure Windows deployment options, manage WinPE templates,
      and create bootable USB or ISO media for deploying Windows 10/11.
      
      .PARAMETER WorkspacePath
      The path to the MCD workspace folder. Defaults to the system ProgramData location.
      
      .EXAMPLE
      Start-MCDWorkspace
      
      Launches the dashboard using the default workspace location.
      
      .EXAMPLE
      Start-MCDWorkspace -WorkspacePath "D:\MCD\MyWorkspace"
      
      Launches the dashboard using a custom workspace location.
      #>
      [CmdletBinding()]
      param(
          [Parameter()]
          [string]$WorkspacePath = "$env:ProgramData\MCD\Workspaces\Default"
      )
      
      # Validate prerequisites
      if (-not (Test-MCDAdminRights)) {
          throw "MCD requires administrator privileges. Please run as administrator."
      }
      
      # Initialize workspace if needed
      if (-not (Test-Path $WorkspacePath)) {
          New-Item -Path $WorkspacePath -ItemType Directory -Force | Out-Null
      }
      
      # Launch GUI
      Show-MCDWorkspaceDashboard -WorkspacePath $WorkspacePath
  }
  ```

  **Start-MCDWinPE**:
  ```powershell
  function Start-MCDWinPE {
      <#
      .SYNOPSIS
      Main entry point for MCD deployment in Windows PE environment.
      
      .DESCRIPTION
      Start-MCDWinPE is called automatically by startnet.cmd when booting from MCD
      deployment media. It initializes the WinPE environment, checks connectivity,
      updates the module if possible, and launches the deployment wizard.
      
      .EXAMPLE
      Start-MCDWinPE
      
      Starts the MCD deployment flow. Typically called from startnet.cmd, not manually.
      #>
      [CmdletBinding()]
      param()
      
      # Called from startnet.cmd
      # Runs initialization → Wizard → Deploy → Complete
      Initialize-MCDWinPE
  }
  ```

  **Acceptance Criteria**:
  - [ ] `source/Public/Start-MCDWorkspace.ps1` exists with proper help
  - [ ] `source/Public/Start-MCDWinPE.ps1` exists with proper help
  - [ ] `source/MCD.psd1` exports both functions
  - [ ] `Get-Command -Module MCD` shows Start-MCDWorkspace, Start-MCDWinPE
  - [ ] `Get-Help Start-MCDWorkspace -Full` shows complete help
  - [ ] QA tests pass: `./build.ps1 -Tasks test -PesterTag helpQuality`
  - [ ] `Start-MCDWorkspace` launches dashboard (manual verification)

  **Commit**: YES
  - Message: `feat(public): implement Start-MCDWorkspace and Start-MCDWinPE entry points`
  - Files: `source/Public/*.ps1`, `source/MCD.psd1`
  - Pre-commit: `./build.ps1 -Tasks test`

---

- [ ] 13. Integration Testing

  **What to do**:
  - Create `tests/Integration/MCD.Integration.tests.ps1` - Full workflow tests
  - Test: Module import, class instantiation, config save/load
  - Test: Workspace creation flow (mocked external dependencies)
  - Verify code coverage >= 85%
  - Ensure all tests are CI-safe (no admin, ADK, disk, or internet required)

  **Must NOT do**:
  - Don't run destructive disk operations in tests
  - Don't require real ADK installation for CI
  - Don't require internet access for CI

  **Parallelizable**: NO (depends on 12)

  **References**:
  - `tests/QA/module.tests.ps1` - Existing QA test patterns
  - `build.yaml:107` - CodeCoverageThreshold: 85

  **Integration Test Structure**:
  ```powershell
  BeforeAll {
      Import-Module "$PSScriptRoot\..\..\output\module\MCD\*\MCD.psd1" -Force
  }
  
  Describe "MCD Module Integration" -Tag "Integration" {
      Context "Module Loading" {
          It "should import without errors" {
              { Import-Module MCD } | Should -Not -Throw
          }
          
          It "should export expected commands" {
              $commands = Get-Command -Module MCD
              $commands.Name | Should -Contain 'Start-MCDWorkspace'
              $commands.Name | Should -Contain 'Start-MCDWinPE'
          }
      }
      
      Context "Class Instantiation" {
          It "should create MCDConfig" {
              { [MCDConfig]::new() } | Should -Not -Throw
          }
      }
      
      Context "Config Round-Trip" {
          It "should save and load config" {
              $config = [MCDConfig]::new()
              $config.Version = "1.0.0"
              $tempPath = Join-Path $TestDrive "config.json"
              $config.Save($tempPath)
              $loaded = [MCDConfig]::Load($tempPath)
              $loaded.Version | Should -Be "1.0.0"
          }
      }
  }
  ```

  **Acceptance Criteria**:
  - [ ] Integration test file created: `tests/Integration/MCD.Integration.tests.ps1`
  - [ ] All integration tests are CI-safe (mocked dependencies)
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
  - Run Start-MCDWorkspace, create USB (or ISO for VM testing)
  - Boot VM from ISO, verify full WinPE flow
  - Deploy Windows, verify success
  - Document any issues found

  **Must NOT do**:
  - Don't automate this (manual verification)
  - Don't skip any screen in the flow

  **Parallelizable**: NO (final task)

  **Verification Procedure**:
  
  1. **Workspace Test**:
     ```powershell
     # Run as Administrator
     Import-Module .\output\module\MCD\*\MCD.psd1
     Start-MCDWorkspace
     # In GUI: Create Workspace → Build ISO (for VM testing)
     ```
  
  2. **Create Test VM**:
     ```powershell
     New-VM -Name "MCD-Test" -MemoryStartupBytes 4GB -Generation 2 -NewVHDPath "C:\VMs\MCD-Test.vhdx" -NewVHDSizeBytes 60GB
     Set-VMFirmware -VMName "MCD-Test" -EnableSecureBoot On -SecureBootTemplate MicrosoftUEFICertificateAuthority
     Add-VMDvdDrive -VMName "MCD-Test" -Path "C:\MCD\Workspace\Media\MCD.iso"
     Set-VMFirmware -VMName "MCD-Test" -FirstBootDevice (Get-VMDvdDrive -VMName "MCD-Test")
     Start-VM -Name "MCD-Test"
     ```
  
  3. **WinPE Boot Test** (observe VM console):
     - Verify: Connectivity check runs (or WiFi screen if no network)
     - Verify: Wizard screen shows and accepts input
     - Verify: Progress screen updates during deployment
     - Verify: Success screen with countdown
     - Verify: VM reboots into Windows
  
  4. **Post-Deployment Verification**:
     - Log into Windows
     - Check `C:\MCD\Logs` for deployment logs (canonical destination)
     - Verify all log files present

  **Acceptance Criteria**:
  - [ ] VM boots from MCD ISO
  - [ ] All WinPE screens display correctly
  - [ ] Windows deploys successfully
  - [ ] Logs copied to `C:\MCD\Logs` (canonical destination)
  - [ ] Total deployment time noted
  - [ ] Any issues documented

  **Commit**: NO (documentation only)

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `chore(structure): setup MCD folder structure, configure CI` | source/**, tests/**, build.yaml | build |
| 2 | `feat(classes): implement core MCD classes` | source/Classes/*, tests/Unit/Classes/* | test |
| 3 | `feat(core): implement core utility functions` | source/Private/Core/*, tests/** | test |
| 4 | `feat(adk): implement ADK detection and install` | source/Private/Workspace/ADK/*, tests/** | test |
| 5 | `feat(template): implement WinPE template creation` | source/Private/Workspace/Template/*, source/Resources/**, tests/** | test |
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

# Workspace launch (requires admin)
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
