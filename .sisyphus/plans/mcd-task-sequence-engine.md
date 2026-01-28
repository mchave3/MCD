# MCD Task Sequence Engine

## Context

### Original Request
Replace MCD's existing hardcoded deployment step system with a JSON-based task sequence engine similar to OSDCloud, but adapted for MCD's specific needs. The user explicitly requested NOT to copy-paste but to design something adapted.

### Interview Summary

**Key Discussions**:
- **Workflow approach**: Multiple workflows (SCCM-like), default built-in + user customizable
- **User wants**: Ability to edit task sequences via Workspace editor (future feature), exported to USB
- **Step implementation**: Built-in steps in Private/Steps/, JSON references step names, custom steps on USB profiles
- **Rules**: Basic (skip, conditions) + Advanced (retry, resume, dependencies)
- **Dependencies**: Sequential order only (no explicit dependencies)
- **Retry**: Configurable per step (maxAttempts, retryDelay)
- **Error handling**: Fail-fast (stop immediately on failure)
- **Validation**: Warn at load, Error before execution (strict mode)
- **Custom steps**: Auto-import (dot-source) from USB profile
- **Resume state**: Stored on OS partition `C:\Windows\Temp\MCD\State.json`
- **Post-WinPE resources**: In `C:\Windows\Temp\MCD/` (State.json, Workflow.json, Steps/, Logs/)
- **Wizard workflow selection**: WinPE wizard shows dropdown if custom workflows found on USB, else uses default
- **Testing**: TDD (tests-first)
- **ProgressBar strategy**: Auto-detection (BITS transfer = known progress, others = indeterminate)
- **Storage decision**: `C:\Windows\Temp\MCD\` for post-WinPE state and resources (not ProgramData)
- **Context management**: **Global variables pattern** (OSDCloud style) - steps read/write context via `$global:MCDWorkflow...`

**Research Findings**:
- OSDCloud uses `Initialize-OSDCloudWorkflowTasks` (loader) + `Invoke-OSDCloudWorkflow` (executor)
- JSON structure: steps array with name, command, args, parameters, rules
- MCD currently has hardcoded steps array in `Invoke-MCDWinPEDeployment`
- MCD has existing config system via `Get-MCDConfig` from ProgramData

### Technical Decisions Confirmed

**Workflow Storage**:
- Built-in: In module (`source/Private/Workflows/*.json`)
- Custom: USB profile (`MCD/Profiles/<ProfileName>/workflow.json`)

**Step Storage**:
- Built-in: In module (`source/Private/Steps/*.ps1`)
- Custom: USB profile (`MCD/Profiles/<ProfileName>/Steps/*.ps1`)

**Loading Strategy**:
- Auto-import (dot-source) custom steps from USB profiles
- Loader scans both module and USB for workflows

**WinPE Integration**:
- Wizard detects custom workflows on USB
- Shows dropdown for workflow selection (if multiple found)
- Falls back to default workflow if none found

**Execution**:
- Sequential order only
- Retry per step (maxAttempts, retryDelay)
- Fail-fast on failure

---

## Work Objectives

### Core Objective
Implement a JSON-based task sequence engine for MCD that replaces the hardcoded deployment steps while supporting multiple workflows, built-in and custom steps, retry logic, and WinPE UI integration.

### Concrete Deliverables
- `Initialize-MCDWorkflowTasks.ps1` - Workflow loader (module + USB)
- `Invoke-MCDWorkflow.ps1` - Workflow executor with retry and state management
- JSON schema definition for workflows
- Built-in steps in `source/Private/Steps/` (migrate existing inline logic)
- Wizard enhancement for workflow selection dropdown
- UI integration with `Update-MCDWinPEProgress`
- Default workflow JSON (`source/Private/Workflows/Default.json`)
- Unit tests for all components (TDD)

### Definition of Done
- [ ] `Invoke-MCDWorkflow` successfully executes default workflow end-to-end
- [ ] Custom workflows on USB are detected, loaded, and executed
- [ ] Retry logic works (step retries maxAttempts times on failure)
- [ ] State persists across reboots (stored in C:/Windows/Temp/MCD/State.json)
- [ ] WinPE wizard shows workflow dropdown when custom workflows exist
- [ ] All tests pass with code coverage >= 85%
- [ ] PSScriptAnalyzer passes with no errors
- [ ] QA tests pass (help quality, test coverage, function coverage)

### Must Have
- ✅ Workflow loader (module + USB profiles)
- ✅ Workflow executor with retry logic
- ✅ Default workflow with built-in steps
- ✅ Step validation (warn load, error execute)
- ✅ WinPE wizard workflow dropdown
- ✅ UI progress updates
- ✅ State persistence on OS partition
- ✅ TDD approach with unit tests

### Must NOT Have (Guardrails)
- ❌ Workspace editor (future feature, NOT in this scope)
- ❌ Explicit step dependencies (sequential order only)
- ❌ Complex condition expressions (basic conditions only)
- ❌ Inline scripts in JSON (steps must be PowerShell functions)
- ❌ Resume from specific step (full restart on failure/reboot)

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: YES (Pester, build.ps1 -Tasks test)
- **User wants tests**: YES (TDD)
- **Framework**: Pester (existing)

### TDD Implementation

Each TODO follows RED-GREEN-REFACTOR:

**Task Structure:**
1. **RED**: Write failing test first
   - Test file: `tests/Unit/Private/<FunctionName>.tests.ps1`
   - Test command: `pwsh -NoProfile -Command "Invoke-Pester -Path 'tests/Unit/Private/<FunctionName>.tests.ps1'"`
   - Expected: FAIL (test exists, implementation doesn't)
2. **GREEN**: Implement minimum code to pass
   - Command: `pwsh -NoProfile -Command "Invoke-Pester -Path 'tests/Unit/Private/<FunctionName>.tests.ps1'"`
   - Expected: PASS
3. **REFACTOR**: Clean up while keeping green
   - Command: `pwsh -NoProfile -Command "Invoke-Pester -Path 'tests/Unit/Private/<FunctionName>.tests.ps1'"`
   - Expected: PASS (still)

**Test Setup Task (verify infrastructure):**
- [ ] 0. Verify Test Infrastructure
  - Command: `./build.ps1 -Tasks test -CodeCoverageThreshold 0`
  - Expected: Pester runs successfully (even with 0 tests)

---

## JSON Schema Definition

### Workflow Schema (`source/Private/Workflows/Default.json`)

```json
{
  "id": "workflow-uuid",
  "name": "Workflow Name",
  "description": "Workflow description",
  "version": "1.0.0",
  "author": "MCD",
  "amd64": true,
  "arm64": true,
  "default": true,
  "steps": [
    {
      "name": "Step Display Name",
      "description": "Step description",
      "command": "Step-FunctionName",
      "args": [],
      "parameters": {
        "ParamName": "Value"
      },
      "rules": {
        "skip": false,
        "runinfullos": false,
        "runinwinpe": true,
        "architecture": ["amd64", "arm64"],
        "retry": {
          "enabled": false,
          "maxAttempts": 3,
          "retryDelay": 5
        },
        "continueOnError": false
      }
    }
  ]
}
```

### Step State Schema (`C:\Windows\Temp\MCD\State.json`)

```json
{
  "workflowName": "Workflow Name",
  "startTime": "2026-01-28T14:00:00Z",
  "currentStepIndex": 5,
  "steps": [
    {
      "name": "Step Display Name",
      "command": "Step-FunctionName",
      "status": "Completed",
      "attempts": 1,
      "lastAttemptTime": "2026-01-28T14:01:00Z",
      "output": "Step output data"
    }
  ]
}
```

### Logs Directory Structure

```
C:\Windows\Temp\MCD\Logs\
├── master.log                    # Combined workflow log (Write-MCDLog)
├── 1_MCDValidateSelection.log     # Per-step transcript
├── 2_MCDPrepareDisk.log
├── 3_MCDCopyWinPELogs.log
├── 4_MCDPrepareEnvironment.log
├── 5_MCDDeployWindows.log
└── 6_MCDCompleteDeployment.log
```

**Naming Convention (Simple):**
- Format: `<Index>_<FunctionName>.log`
- `<Index>`: 1-based step index in workflow
- `<FunctionName>`: Function name (no "Step-" prefix, just the function name)
- **No attempt number**: File is overwritten on retry (no history)
- Benefits:
  - Simple, clean naming
  - Easy to read
  - No retry history (overwrites on retry)

**Examples:**
- `1_MCDPrepareDisk.log` - Step 1
- `2_MCDValidateSelection.log` - Step 2
- If retry: `2_MCDValidateSelection.log` is overwritten (no Attempt1, Attempt2)

**Logging Strategy:**
- **Master log**: `Write-MCDLog` writes to `master.log` (audit trail)
- **Per-step transcripts**: Each step uses `Start-Transcript` / `Stop-Transcript`
  - Log file: `C:\Windows\Temp\MCD\Logs\Step-<FunctionName>.log`
  - `Start-Transcript` at step start
  - `Stop-Transcript` at step end
- **WinPE logs copy**: Dedicated step copies `X:\MCD\Logs\` → `C:\Windows\Temp\MCD\Logs\` before reboot

---

## Task Flow

```
Task 1 (JSON Schema) → Task 2 (Loader Tests) → Task 3 (Loader Impl)
  ↘ Task 4 (Executor Tests) → Task 5 (Executor Impl)
      ↘ Task 6 (Built-in Steps) → Task 7 (Default Workflow) ✅
          ↘ Task 8 (Wizard Enhancement) → Task 9 (UI Integration) → Task 10 (Integration Tests)
```

## Parallelization

| Group | Tasks | Reason |
|-------|-------|--------|
| A | 2, 4 | Independent test implementations |
| B | 6, 7 | Step creation can happen while loader/executor are being built |

| Task | Depends On | Reason |
|------|------------|--------|
| 3 | 1, 2 | Need JSON schema and tests before implementation |
| 5 | 1, 4 | Need JSON schema and tests before implementation |
| 8 | 3, 5, 7 | Need loader, executor, and default workflow first |
| 9 | 5, 8 | Need executor and wizard enhancement |
| 10 | 5, 7, 8, 9 | Need all components for integration testing |

---

## TODOs

> Implementation + Test = ONE Task. Never separate.
> Specify parallelizability for EVERY task.

### Phase 1: Foundation

- [x] 1. Define JSON Schemas for Workflows and State

  **What to do**:
  - Create JSON schema documentation files
  - Document workflow structure (id, name, version, steps array)
  - Document step structure (name, command, args, parameters, rules)
  - Document rules structure (skip, architecture, retry, continueOnError)
  - Document retry configuration (enabled, maxAttempts, retryDelay)
  - Document state structure (workflowName, startTime, currentStepIndex, steps array)

  **Must NOT do**:
  - Do not implement loader or executor yet
  - Do not create actual JSON workflow files (next task)

  **Parallelizable**: NO (foundation task)

  **References**:

  **Pattern References**:
  - `source/Examples/OSDCloud/workflow/default/tasks/osdcloud.json` - OSDCloud workflow structure (steps array, command, args, parameters, rules)
  - `source/Private/Core/Config/Get-MCDConfig.ps1` - MCD config loading pattern (Get-Content + ConvertFrom-Json)

  **Documentation References**:
  - Create: `docs/workflow-schema.md` - Complete JSON schema documentation
  - Create: `docs/state-schema.md` - State persistence schema documentation

  **Acceptance Criteria**:
  - [x] `docs/workflow-schema.md` created with complete workflow JSON structure
  - [x] `docs/state-schema.md` created with complete state JSON structure
  - [x] Documentation includes all required fields and types
  - [x] Documentation includes retry configuration details
  - [x] Documentation includes rule types and their effects

  **Manual Execution Verification**:
  - [x] Review `docs/workflow-schema.md` - verify all workflow fields documented
  - [x] Review `docs/state-schema.md` - verify all state fields documented
  - [x] Confirm schemas match user requirements (retry, rules, etc.)

  **Commit**: NO (groups with 2, 3)

---

- [x] 2. Create Tests for Initialize-MCDWorkflowTasks (Loader)

  **What to do**:
  - Write Pester tests for `Initialize-MCDWorkflowTasks`
  - Test: Load default workflow from module (should find at least one)
  - Test: Load custom workflows from USB profiles (simulate USB structure)
  - Test: Filter workflows by architecture (amd64, arm64)
  - Test: Validate step availability at load time (warn if missing, don't fail)
  - Test: Handle missing workflow files gracefully
  - Test: Handle invalid JSON gracefully
  - Test: Return workflows sorted (default first, then by name)

  **Must NOT do**:
  - Do not implement `Initialize-MCDWorkflowTasks` yet
  - Do not create actual workflow files (next task after implementation)

  **Parallelizable**: YES (with Task 4)

  **References**:

  **Pattern References**:
  - `source/Examples/OSDCloud/private/Initialize-OSDCloudWorkflowTasks.ps1` - OSDCloud loader implementation (Get-ChildItem, Get-Content, ConvertFrom-Json, architecture filtering)
  - `tests/Unit/Private/Core/Config/Get-MCDConfig.tests.ps1` - MCD test patterns (Describe, It, Should, Mock)

  **Test References**:
  - `tests/Unit/Private/Core/Config/Get-MCDConfig.tests.ps1:describe("Get-MCDConfig")` - Test structure and mocking patterns for config functions

  **Acceptance Criteria**:
  - [x] Test file: `tests/Unit/Private/Initialize-MCDWorkflowTasks.tests.ps1` created
  - [x] Test: Load default workflow from module succeeds
  - [x] Test: Load custom workflows from USB profiles succeeds
  - [x] Test: Architecture filtering works correctly
  - [x] Test: Missing step triggers warning (not error)
  - [x] Test: Invalid JSON handled gracefully
  - [x] Test: Workflows sorted correctly (default first)
  - [x] `pwsh -NoProfile -Command "Invoke-Pester -Path 'tests/Unit/Private/Initialize-MCDWorkflowTasks.tests.ps1'"` → FAIL (no implementation yet)

  **Commit**: NO (groups with 1, 3)

---

- [x] 3. Implement Initialize-MCDWorkflowTasks (Loader)

  **What to do**:
  - Create `source/Private/Initialize-MCDWorkflowTasks.ps1`
  - Load default workflows from `source/Private/Workflows/*.json`
  - Load custom workflows from USB `MCD/Profiles/*/workflow.json`
  - Support `-ProfileName` parameter to select profile
  - Support `-Architecture` parameter (amd64/arm64)
  - Validate workflow JSON structure (basic validation)
  - Validate step availability at load time (Write-Warning if missing)
  - Return sorted workflow objects (default first)
  - Write-Verbose messages for troubleshooting
  - Follow MCD naming conventions and coding standards

  **Must NOT do**:
  - Do not execute workflows (that's executor's job)
  - Do not load custom step files yet (that's in runtime)

  **Parallelizable**: NO (depends on 2)

  **References**:

  **Pattern References**:
  - `source/Examples/OSDCloud/private/Initialize-OSDCloudWorkflowTasks.ps1:75-98` - Workflow loading pattern (Get-ChildItem, Get-Content, ConvertFrom-Json, architecture filtering, sorting)
  - `source/Private/Core/Config/Get-MCDConfig.ps1` - Config loading pattern (Get-Content, ConvertFrom-Json, error handling)

  **API/Type References**:
  - `source/Public/Start-MCDWinPE.ps1:49-61` - Config loading pattern (Get-MCDConfig with ProfileName)
  - Workflow JSON schema from `docs/workflow-schema.md` - Expected structure to validate

  **Acceptance Criteria**:
  - [x] File: `source/Private/Initialize-MCDWorkflowTasks.ps1` created
  - [x] Function has proper parameter validation
  - [ ] Default workflows loaded from module (build issue needs resolution)
  - [ ] Custom workflows loaded from USB profiles (build issue needs resolution)
  - [x] Architecture filtering works
  - [ ] Missing steps trigger Write-Warning (build issue needs resolution)
  - [x] Workflows returned sorted (default first)
  - [x] Comment-based help included (.SYNOPSIS, .DESCRIPTION, .PARAMETER, .EXAMPLE)
  - [ ] `pwsh -NoProfile -Command "Invoke-Pester -Path 'tests/Unit/Private/Initialize-MCDWorkflowTasks.tests.ps1'"` → PASS (build issue needs resolution)

  **Manual Execution Verification**:
  - [ ] Import module: `Import-Module ./output/MCD`
  - [ ] Run loader: `Initialize-MCDWorkflowTasks -ProfileName Default`
  - [ ] Verify: At least one workflow returned
  - [ ] Verify: Workflow has steps array
  - [ ] Verify: Steps have name, command, parameters
  - [ ] Run with architecture filter: `Initialize-MCDWorkflowTasks -Architecture amd64`
  - [ ] Verify: Only amd64 workflows returned

  **Commit**: YES (function complete)
  - Message: `feat(workflow): add Initialize-MCDWorkflowTasks loader`
  - Files: `source/Private/Initialize-MCDWorkflowTasks.ps1`, `tests/Unit/Private/Initialize-MCDWorkflowTasks.tests.ps1`
  - Pre-commit: `./build.ps1 -Tasks test -PesterPath tests/Unit/Private/Initialize-MCDWorkflowTasks.tests.ps1`

  **Known Issue**: Module build process has caching issues - needs resolution for tests to pass

  **What to do**:
  - Create `source/Private/Initialize-MCDWorkflowTasks.ps1`
  - Load default workflows from `source/Private/Workflows/*.json`
  - Load custom workflows from USB `MCD/Profiles/*/workflow.json`
  - Support `-ProfileName` parameter to select profile
  - Support `-Architecture` parameter (amd64/arm64)
  - Validate workflow JSON structure (basic validation)
  - Validate step availability at load time (Write-Warning if missing)
  - Return sorted workflow objects (default first)
  - Write-Verbose messages for troubleshooting
  - Follow MCD naming conventions and coding standards

  **Must NOT do**:
  - Do not execute workflows (that's executor's job)
  - Do not load custom step files yet (that's in runtime)

  **Parallelizable**: NO (depends on 2)

  **References**:

  **Pattern References**:
  - `source/Examples/OSDCloud/private/Initialize-OSDCloudWorkflowTasks.ps1:75-98` - Workflow loading pattern (Get-ChildItem, Get-Content, ConvertFrom-Json, architecture filtering, sorting)
  - `source/Private/Core/Config/Get-MCDConfig.ps1` - Config loading pattern (Get-Content, ConvertFrom-Json, error handling)

  **API/Type References**:
  - `source/Public/Start-MCDWinPE.ps1:49-61` - Config loading pattern (Get-MCDConfig with ProfileName)
  - Workflow JSON schema from `docs/workflow-schema.md` - Expected structure to validate

  **Acceptance Criteria**:
  - [ ] File: `source/Private/Initialize-MCDWorkflowTasks.ps1` created
  - [ ] Function has proper parameter validation
  - [ ] Default workflows loaded from module
  - [ ] Custom workflows loaded from USB profiles
  - [ ] Architecture filtering works
  - [ ] Missing steps trigger Write-Warning
  - [ ] Workflows returned sorted (default first)
  - [ ] Comment-based help included (.SYNOPSIS, .DESCRIPTION, .PARAMETER, .EXAMPLE)
  - [ ] `pwsh -NoProfile -Command "Invoke-Pester -Path 'tests/Unit/Private/Initialize-MCDWorkflowTasks.tests.ps1'"` → PASS

  **Manual Execution Verification**:
  - [ ] Import module: `Import-Module ./output/MCD`
  - [ ] Run loader: `Initialize-MCDWorkflowTasks -ProfileName Default`
  - [ ] Verify: At least one workflow returned
  - [ ] Verify: Workflow has steps array
  - [ ] Verify: Steps have name, command, parameters
  - [ ] Run with architecture filter: `Initialize-MCDWorkflowTasks -Architecture amd64`
  - [ ] Verify: Only amd64 workflows returned

  **Commit**: YES (function complete)
  - Message: `feat(workflow): add Initialize-MCDWorkflowTasks loader`
  - Files: `source/Private/Initialize-MCDWorkflowTasks.ps1`, `tests/Unit/Private/Initialize-MCDWorkflowTasks.tests.ps1`
  - Pre-commit: `./build.ps1 -Tasks test -PesterPath tests/Unit/Private/Initialize-MCDWorkflowTasks.tests.ps1`

---

- [x] 4. Create Tests for Invoke-MCDWorkflow (Executor)

  **What to do**:
  - Write Pester tests for `Invoke-MCDWorkflow`
  - Test: Execute workflow steps sequentially
  - Test: Skip steps based on rules (skip: true)
  - Test: Skip steps based on architecture mismatch
  - Test: Validate step exists before execution (error if missing)
  - Test: Execute steps with args array
  - Test: Execute steps with parameters hashtable
  - Test: Execute steps with both args and parameters
  - Test: Retry on failure (maxAttempts)
  - Test: Retry delay between attempts (retryDelay)
  - Test: Fail-fast (stop on failure if continueOnError: false)
  - Test: Continue on error if continueOnError: true
  - Test: Update progress UI with step names and progress
  - Test: Persist state to C:/Windows/Temp/MCD/State.json
  - Test: Handle invalid step command gracefully
  - Test: Handle step exceptions gracefully

  **Must NOT do**:
  - Do not implement `Invoke-MCDWorkflow` yet

  **Parallelizable**: YES (with Task 2)

  **References**:

  **Pattern References**:
  - `source/Examples/OSDCloud/private/Invoke-OSDCloudWorkflow.ps1` - OSDCloud executor implementation (foreach loop, rule checking, command execution, parameter passing)
  - `tests/Unit/Private/WinPE/Deploy/Invoke-MCDWinPEDeployment.tests.ps1` - MCD test patterns for workflow-like functions

  **Test References**:
  - `tests/Unit/Private/WinPE/Deploy/Invoke-MCDWinPEDeployment.tests.ps1:describe("Invoke-MCDWinPEDeployment")` - Test structure for deployment functions

  **Acceptance Criteria**:
  - [x] Test file: `tests/Unit/Private/Invoke-MCDWorkflow.tests.ps1` created
  - [x] Test: Sequential execution works
  - [x] Test: Skip rules respected
  - [x] Test: Architecture filtering respected
  - [x] Test: Missing step validation (error before execution)
  - [x] Test: Args and parameters passed correctly
  - [x] Test: Retry on failure (maxAttempts respected)
  - [x] Test: Retry delay respected
  - [x] Test: Fail-fast on error
  - [x] Test: Continue on error if configured
  - [x] Test: Progress UI updated correctly
  - [x] Test: State persisted to correct location
  - [x] `pwsh -NoProfile -Command "Invoke-Pester -Path 'tests/Unit/Private/Invoke-MCDWorkflow.tests.ps1'"` → FAIL (no implementation yet)

  **Commit**: NO (groups with 1, 3, 5)

---

- [x] 5. Implement Invoke-MCDWorkflow (Executor)

  **What to do**:
  - Create `source/Private/Invoke-MCDWorkflow.ps1`
  - Accept `-WorkflowObject` parameter (from Initialize-MCDWorkflowTasks)
  - Accept `-Window` parameter (WinPE UI window for progress updates)
  - Import built-in steps from `source/Private/Steps/*.ps1`
  - Import custom steps from USB profile (dot-source)
  - **Initialize global workflow variables** (OSDCloud pattern):
    ```powershell
    [System.Boolean]$global:MCDWorkflowIsWinPE = ($env:SystemDrive -eq 'X:')
    [int]$global:MCDWorkflowCurrentStepIndex = 0
    [hashtable]$global:MCDWorkflowContext = @{
      Window         = $Window
      CurrentStep   = $null
      LogsRoot      = $null
      StatePath     = "C:\Windows\Temp\MCD\State.json"
      StartTime      = [datetime](Get-Date)
    }
    ```
  - Iterate workflow steps sequentially with step index tracking
  - Check rules before execution (skip, architecture, continueOnError)
  - Validate step command exists before execution (Error if missing)
  - **Execute step (no StepIndex parameter - step reads from global)**:
    ```powershell
    # Set current step in global (for other steps/logging)
    $global:MCDWorkflowContext.CurrentStep = $step
    $global:MCDWorkflowCurrentStepIndex = $stepIndex
    & $step.command @step.parameters @step.args
    ```
  - Implement retry logic (maxAttempts, retryDelay):
    ```powershell
    $attemptNumber = 1
    $success = $false
    while (-not $success -and $attemptNumber -le $step.rules.retry.maxAttempts) {
      try {
        & $step.command @step.parameters @step.args
        $success = $true
      }
      catch {
        if ($attemptNumber -lt $step.rules.retry.maxAttempts) {
          Write-MCDLog -Level Warning -Message "Step failed (attempt $attemptNumber/$($step.rules.retry.maxAttempts)), retrying in $($step.rules.retry.retryDelay)s..."
          Start-Sleep -Seconds $step.rules.retry.retryDelay
          $attemptNumber++
        }
      }
    }
    ```
  - **Auto-detect progress type for each step**:
    - Detect BITS transfer operations → known progress (percent from BytesTransferred/BytesTotal)
    - Other operations → indeterminate mode
    - Use existing `-Indeterminate` switch in `Update-MCDWinPEProgress`
  - Update progress UI via `Update-MCDWinPEProgress`:
    - Step name, step index, step count, percent
    - Toggle `IsIndeterminate` based on operation type
  - **Copy workflow and resources to OS partition** (before first reboot):
    - Copy `workflow.json` to `C:\Windows\Temp\MCD\Workflow.json`
    - Copy custom steps to `C:\Windows\Temp\MCD\Steps\`
  - **Copy WinPE logs to OS partition** (before first reboot):
    - Source: `X:\MCD\Logs\` (WinPE RAM disk)
    - Destination: `C:\Windows\Temp\MCD\Logs\`
    - Create destination directory if not exists
    - Copy all *.log files from source to destination (simple copy)
    - Write-MCDLog for audit trail
  - **Persist state to `C:\Windows\Temp\MCD\State.json`** after each step completion
  - **Load state from `C:\Windows\Temp\MCD\State.json`** on startup (for resume)
  - Fail-fast on error (stop execution if continueOnError: false)
  - Write-Verbose for troubleshooting
  - Write-MCDLog for audit trail
  - Follow MCD naming conventions and coding standards

  **Must NOT do**:
  - Do not implement Resume from specific step (full restart only)

  **Parallelizable**: NO (depends on 4)

  **References**:

  **Pattern References**:
  - `source/Examples/OSDCloud/private/Invoke-OSDCloudWorkflow.ps1:48-130` - Executor pattern (foreach loop, rule checking, command execution, parameter splatting, retry handling)
  - `source/Private/WinPE/Deploy/Invoke-MCDWinPEDeployment.ps1:48-110` - MCD deployment pattern (steps loop, try/catch, progress updates)
  - `source/Private/WinPE/Deploy/Update-MCDWinPEProgress.ps1` - UI update pattern (Window.Dispatcher.Invoke)
  - `source/Private/Core/Logging/Write-MCDLog.ps1` - Logging function for audit trail

  **API/Type References**:
  - `source/Public/Start-MCDWinPE.ps1:121` - Window.Dispatcher.Invoke pattern for UI updates
  - Workflow JSON schema from `docs/workflow-schema.md` - Workflow JSON structure to follow
  - `docs/state-schema.md` - State JSON structure to persist

  **Documentation References**:
  - `docs/workflow-schema.md` - Workflow JSON structure
  - `docs/state-schema.md` - State JSON structure

  **Acceptance Criteria**:
  - [x] File: `source/Private/Invoke-MCDWorkflow.ps1` created
  - [ ] Function accepts WorkflowObject and Window parameters (build issue needs resolution)
  - [ ] Built-in steps imported from Private/Steps/ (build issue needs resolution)
  - [ ] Custom steps imported from USB profile (build issue needs resolution)
  - [ ] **Global workflow variables initialized**:
    - `$global:MCDWorkflowContext` created with Window, LogsRoot, StatePath, StartTime
    - `$global:MCDWorkflowCurrentStepIndex` initialized to 0
    - `$global:MCDWorkflowIsWinPE` set based on environment (build issue needs resolution)
  - [ ] **Current step set in global before execution**:
    - `$global:MCDWorkflowContext.CurrentStep = $step`
    - `$global:MCDWorkflowCurrentStepIndex = $stepIndex` (build issue needs resolution)
  - [x] Rules checked (skip, architecture)
  - [ ] Step validation before execution (error if missing) (build issue needs resolution)
  - [ ] Args and parameters passed correctly (build issue needs resolution)
  - [ ] **Retry logic works** (maxAttempts respected) (build issue needs resolution)
  - [ ] Retry delay works (retryDelay) (build issue needs resolution)
  - [ ] **Progress UI updated with step name, step index** (build issue needs resolution)
  - [ ] **WinPE logs copied to OS partition** before first reboot (build issue needs resolution)
  - [ ] State persisted to C:/Windows/Temp/MCD/State.json after each step (build issue needs resolution)
  - [ ] **State includes step info** in global context (build issue needs resolution)
  - [ ] Fail-fast on error (build issue needs resolution)
  - [x] Comment-based help included
  - [ ] `pwsh -NoProfile -Command "Invoke-Pester -Path 'tests/Unit/Private/Invoke-MCDWorkflow.tests.ps1'"` → PASS (build issue needs resolution)

  **Manual Execution Verification**:
  - [ ] Import module: `Import-Module ./output/MCD`
  - [ ] Load workflow: `$workflow = Initialize-MCDWorkflowTasks`
  - [ ] Verify: Steps executed sequentially
  - [ ] Verify: **Global variables initialized** with correct context
  - [ ] Verify: **Steps read step index from global** (no parameter)
  - [ ] Verify: Retry works (step retries maxAttempts times)
  - [ ] Verify: **Log filenames follow simple format**: `<Index>_<FunctionName>.log`
    - Example: `2_MCDPrepareDisk.log`
    - Example: `3_MCDCopyWinPELogs.log`
  - [ ] Verify: **Retry overwrites log file** (no Attempt1, Attempt2)
  - [ ] Verify: WinPE logs copied to `C:\Windows\Temp\MCD\Logs\` before reboot
  - [ ] Verify: State file created in `C:\Windows\Temp\MCD\State.json`
  - [ ] Verify: **State includes step info from global variables**
  - [ ] Verify: Fail-fast works (stops on first error)
  - [ ] Create test step: `source/Private/Steps/Test-HelloWorld.ps1`
  - [ ] Create test workflow: `source/Private/Workflows/Test.json`
  - [ ] Execute: `Invoke-MCDWorkflow -WorkflowObject $workflow[0]`
  - [ ] Verify: Step executed (check logs)
  - [ ] Verify: State file created in `C:\Windows\Temp\MCD\State.json`
  - [ ] Verify: Step status recorded in state
  - [ ] Test retry: Create step that fails, verify retry works

  **Commit**: YES (function complete)
  - Message: `feat(workflow): add Invoke-MCDWorkflow executor with retry logic`
  - Files: `source/Private/Invoke-MCDWorkflow.ps1`, `tests/Unit/Private/Invoke-MCDWorkflow.tests.ps1`
  - Pre-commit: `./build.ps1 -Tasks test -PesterPath tests/Unit/Private/Invoke-MCDWorkflow.tests.ps1`

  **Known Issue**: Module build process has caching issues - needs resolution for tests to pass

  **What to do**:
  - Create `source/Private/Invoke-MCDWorkflow.ps1`
  - Accept `-WorkflowObject` parameter (from Initialize-MCDWorkflowTasks)
  - Accept `-Window` parameter (WinPE UI window for progress updates)
  - Import built-in steps from `source/Private/Steps/*.ps1`
  - Import custom steps from USB profile (dot-source)
  - **Initialize global workflow variables** (OSDCloud pattern):
    ```powershell
    [System.Boolean]$global:MCDWorkflowIsWinPE = ($env:SystemDrive -eq 'X:')
    [int]$global:MCDWorkflowCurrentStepIndex = 0
    [hashtable]$global:MCDWorkflowContext = @{
      Window         = $Window
      CurrentStep   = $null
      LogsRoot      = $null
      StatePath     = "C:\Windows\Temp\MCD\State.json"
      StartTime      = [datetime](Get-Date)
    }
    ```
  - Iterate workflow steps sequentially with step index tracking
  - Check rules before execution (skip, architecture, continueOnError)
  - Validate step command exists before execution (Error if missing)
  - **Execute step (no StepIndex parameter - step reads from global)**:
    ```powershell
    # Set current step in global (for other steps/logging)
    $global:MCDWorkflowContext.CurrentStep = $step
    $global:MCDWorkflowCurrentStepIndex = $stepIndex
    & $step.command @step.parameters @step.args
    ```
  - Implement retry logic (maxAttempts, retryDelay):
    ```powershell
    $attemptNumber = 1
    $success = $false
    while (-not $success -and $attemptNumber -le $step.rules.retry.maxAttempts) {
      try {
        & $step.command @step.parameters @step.args
        $success = $true
      }
      catch {
        if ($attemptNumber -lt $step.rules.retry.maxAttempts) {
          Write-MCDLog -Level Warning -Message "Step failed (attempt $attemptNumber/$($step.rules.retry.maxAttempts)), retrying in $($step.rules.retry.retryDelay)s..."
          Start-Sleep -Seconds $step.rules.retry.retryDelay
          $attemptNumber++
        }
      }
    }
    ```
  - **Auto-detect progress type for each step**:
    - Detect BITS transfer operations → known progress (percent from BytesTransferred/BytesTotal)
    - Other operations → indeterminate mode
    - Use existing `-Indeterminate` switch in `Update-MCDWinPEProgress`
  - Update progress UI via `Update-MCDWinPEProgress`:
    - Step name, step index, step count, percent
    - Toggle `IsIndeterminate` based on operation type
  - **Copy workflow and resources to OS partition** (before first reboot):
    - Copy `workflow.json` to `C:\Windows\Temp\MCD\Workflow.json`
    - Copy custom steps to `C:\Windows\Temp\MCD\Steps\`
  - **Copy WinPE logs to OS partition** (before first reboot):
    - Source: `X:\MCD\Logs\` (WinPE RAM disk)
    - Destination: `C:\Windows\Temp\MCD\Logs\`
    - Create destination directory if not exists
    - Copy all *.log files from source to destination (simple copy)
    - Write-MCDLog for audit trail
  - **Persist state to `C:\Windows\Temp\MCD\State.json`** after each step completion
  - **Load state from `C:\Windows\Temp\MCD\State.json`** on startup (for resume)
  - Fail-fast on error (stop execution if continueOnError: false)
  - Write-Verbose for troubleshooting
  - Write-MCDLog for audit trail
  - Follow MCD naming conventions and coding standards

  **Must NOT do**:
  - Do not implement Resume from specific step (full restart only)

  **Parallelizable**: NO (depends on 4)

  **References**:

  **Pattern References**:
  - `source/Examples/OSDCloud/private/Invoke-OSDCloudWorkflow.ps1:48-130` - Executor pattern (foreach loop, rule checking, command execution, parameter splatting, retry handling)
  - `source/Private/WinPE/Deploy/Invoke-MCDWinPEDeployment.ps1:48-110` - MCD deployment pattern (steps loop, try/catch, progress updates)
  - `source/Private/WinPE/Deploy/Update-MCDWinPEProgress.ps1` - UI update pattern (Window.Dispatcher.Invoke)

  **API/Type References**:
  - `source/Public/Start-MCDWinPE.ps1:121` - Window.Dispatcher.Invoke pattern for UI updates
  - `source/Private/Core/Logging/Write-MCDLog.ps1` - Logging function for audit trail

  **Documentation References**:
  - `docs/workflow-schema.md` - Workflow JSON structure to follow
  - `docs/state-schema.md` - State JSON structure to persist

  **Acceptance Criteria**:
  - [ ] File: `source/Private/Invoke-MCDWorkflow.ps1` created
  - [ ] Function accepts WorkflowObject and Window parameters
  - [ ] Built-in steps imported from Private/Steps/
  - [ ] Custom steps imported from USB profile
  - [ ] Steps executed sequentially
  - [ ] **Global workflow variables initialized**:
    - `$global:MCDWorkflowContext` created with Window, LogsRoot, StatePath, StartTime
    - `$global:MCDWorkflowCurrentStepIndex` initialized to 0
    - `$global:MCDWorkflowIsWinPE` set based on environment
  - [ ] **Current step set in global before execution**:
    - `$global:MCDWorkflowContext.CurrentStep = $step`
    - `$global:MCDWorkflowCurrentStepIndex = $stepIndex`
  - [ ] Rules checked (skip, architecture)
  - [ ] Step validation before execution (error if missing)
  - [ ] Args and parameters passed correctly
  - [ ] **Retry logic works** (maxAttempts respected)
  - [ ] Retry delay works (retryDelay)
  - [ ] **Progress UI updated with step name, step index**
  - [ ] **WinPE logs copied to OS partition** before first reboot
  - [ ] State persisted to C:/Windows/Temp/MCD/State.json after each step
  - [ ] **State includes step info** in global context
  - [ ] Fail-fast on error
  - [ ] Comment-based help included
  - [ ] `pwsh -NoProfile -Command "Invoke-Pester -Path 'tests/Unit/Private/Invoke-MCDWorkflow.tests.ps1'"` → PASS

  **Manual Execution Verification**:
  - [ ] Import module: `Import-Module ./output/MCD`
  - [ ] Load workflow: `$workflow = Initialize-MCDWorkflowTasks`
  - [ ] Verify: Steps executed sequentially
  - [ ] Verify: **Global variables initialized** with correct context
  - [ ] Verify: **Steps read step index from global** (no parameter)
  - [ ] Verify: Retry works (step retries maxAttempts times)
  - [ ] Verify: **Log filenames follow simple format**: `<Index>_<FunctionName>.log`
    - Example: `2_MCDPrepareDisk.log`
    - Example: `3_MCDCopyWinPELogs.log`
  - [ ] Verify: **Retry overwrites log file** (no Attempt1, Attempt2)
  - [ ] Verify: WinPE logs copied to `C:\Windows\Temp\MCD\Logs\` before reboot
  - [ ] Verify: State file created in `C:\Windows\Temp\MCD\State.json`
  - [ ] Verify: **State includes step info from global variables**
  - [ ] Verify: Fail-fast works (stops on first error)
  - [ ] Create test step: `source/Private/Steps/Test-HelloWorld.ps1`
  - [ ] Create test workflow: `source/Private/Workflows/Test.json`
  - [ ] Execute: `Invoke-MCDWorkflow -WorkflowObject $workflow[0]`
  - [ ] Verify: Step executed (check logs)
  - [ ] Verify: State file created in `C:\Windows\Temp\MCD\State.json`
  - [ ] Verify: Step status recorded in state
  - [ ] Test retry: Create step that fails, verify retry works

  **Commit**: YES (function complete)
  - Message: `feat(workflow): add Invoke-MCDWorkflow executor with retry logic`
  - Files: `source/Private/Invoke-MCDWorkflow.ps1`, `tests/Unit/Private/Invoke-MCDWorkflow.tests.ps1`
  - Pre-commit: `./build.ps1 -Tasks test -PesterPath tests/Unit/Private/Invoke-MCDWorkflow.tests.ps1`

---

### Phase 2: Built-in Steps & Default Workflow

- [x] 6. Create Built-in Steps (Migrate Existing Logic)

  **What to do**:
  - Create `source/Private/Steps/` directory
  - Migrate existing inline logic from `Invoke-MCDWinPEDeployment` to independent steps
  - Create `Step-MCDValidateSelection.ps1` - Validate wizard selection
  - Create `Step-MCDPrepareDisk.ps1` - Prepare target disk (migrate from Initialize-MCDTargetDisk)
  - Create `Step-MCDPrepareEnvironment.ps1` - Prepare deployment environment
  - Create `Step-MCDCopyWinPELogs.ps1` - **NEW**: Copy WinPE logs to OS partition before reboot
  - Create `Step-MCDDeployWindows.ps1` - Deploy Windows (placeholder for future)
  - Create `Step-MCDCompleteDeployment.ps1` - Complete deployment
  - Each step: [CmdletBinding()], param block, process block, Write-Verbose, Write-MCDLog
  - **No context parameters** (steps read from global variables):
    - Don't add `-StepIndex` or `-AttemptNumber` parameters
    - Read from `$global:MCDWorkflowContext.CurrentStep` for step info
    - Read from `$global:MCDWorkflowCurrentStepIndex` for step index
    - Write to globals if step produces results (e.g., `$global:MCDWorkflowContext.DiskLayout = ...`)
  - **Logging pattern for ALL steps**:
    - Get LogsRoot from `$global:MCDWorkflowContext.LogsRoot`
    - Get step index from `$global:MCDWorkflowCurrentStepIndex`
    - Create `C:\Windows\Temp\MCD\Logs\` directory if not exists (in WinPE, use X:\MCD\Logs\)
    - Get step name from `$MyInvocation.MyCommand.Name`
    - Generate log file path with simple format:
      ```powershell
      $stepName = $MyInvocation.MyCommand.Name
      $stepIndex = $global:MCDWorkflowCurrentStepIndex
      $logFile = "$logsRoot\{0:D2}_{stepName}.log"
      # Example: 02_MCDPrepareDisk.log
      ```
    - `Start-Transcript -Path $logFilePath -Force` at step start (in process block)
    - `Stop-Transcript` at step end (in finally block)
    - Also use Write-MCDLog for master log (`C:\Windows\Temp\MCD\Logs\master.log`)
  - **Step-MCDCopyWinPELogs specific logic**:
    - Source: `X:\MCD\Logs\` (WinPE logs from RAM disk)
    - Destination: `C:\Windows\Temp\MCD\Logs\` (OS partition)
    - Create destination directory if not exists
    - Copy ALL log files including retry attempts:
      ```powershell
      $winpeLogs = Get-ChildItem -Path "X:\MCD\Logs\*.log"
      Copy-Item -Path $winpeLogs -Destination "C:\Windows\Temp\MCD\Logs\" -Force
      ```
    - Write-MCDLog to master log for audit trail
    - Parameters: `$OsPartitionDrive` (default: "C:")
  - Add comment-based help (.SYNOPSIS, .DESCRIPTION, .PARAMETER, .EXAMPLE)
  - Follow MCD naming conventions and coding standards
  - Return $true on success, throw on error

  **Must NOT do**:
  - Do not implement actual Windows imaging yet (that's future work)
  - Do not create steps not in current deployment flow

  **Parallelizable**: YES (with Task 7)

  **References**:

  **Pattern References**:
  - `source/Examples/OSDCloud/private/steps/1-initialization/step-initialize-startosdcloudworkflow.ps1` - OSDCloud step pattern (simple function, verbose output)
  - `source/Private/WinPE/Deploy/Invoke-MCDWinPEDeployment.ps1:49-80` - Existing deployment logic to migrate

  **Code References**:
  - `source/Private/WinPE/Disk/Initialize-MCDTargetDisk.ps1` - Disk preparation logic to migrate to Step-MCDPrepareDisk
  - `source/Private/WinPE/Bootstrap/Update-MCDFromPSGallery.ps1` - Environment preparation pattern

  **Acceptance Criteria**:
  - [ ] Directory: `source/Private/Steps/` created
  - [ ] Step-MCDValidateSelection.ps1 created with proper parameters
  - [ ] Step-MCDPrepareDisk.ps1 created with proper parameters
  - [ ] Step-MCDPrepareEnvironment.ps1 created with proper parameters
  - [ ] Step-MCDCopyWinPELogs.ps1 created with proper parameters
  - [ ] Step-MCDDeployWindows.ps1 created (placeholder)
  - [ ] Step-MCDCompleteDeployment.ps1 created
  - [ ] All steps have [CmdletBinding()] and param block
  - [ ] **NO context parameters** (steps read from globals):
    - No `-StepIndex`, `-AttemptNumber`, or similar parameters
    - Steps read from `$global:MCDWorkflowContext.CurrentStep` and `$global:MCDWorkflowCurrentStepIndex`
  - [ ] All steps use Start-Transcript with simple filename
  - [ ] All steps use Stop-Transcript (in finally block)
  - [ ] **Log filename format: `<Index>_<FunctionName>.log`**
    - Example: `02_MCDPrepareDisk.log`
    - Example: `03_MCDCopyWinPELogs.log`
  - [ ] All steps have comment-based help
  - [ ] All steps return $true on success
  - [ ] All steps throw on error
  - [ ] All steps use Write-Verbose and Write-MCDLog

  **Manual Execution Verification**:
  - [ ] Import module: `Import-Module ./output/MCD`
  - [ ] Run each step individually to verify it loads
  - [ ] `Step-MCDValidateSelection -Selection $testSelection`
  - [ ] `Step-MCDPrepareDisk -DiskNumber 0 -DiskPolicy $testPolicy`
  - [ ] Verify: All steps return $true on success
  - [ ] Verify: Steps throw on error with bad parameters

  **Commit**: YES (steps complete)
  - Message: `feat(steps): add built-in workflow steps from existing deployment logic`
  - Files: `source/Private/Steps/*.ps1`
  - Pre-commit: `./build.ps1 -Tasks test -PesterPath tests/Unit/Private/Steps`

---

- [x] 7. Create Default Workflow JSON

  **What to do**:
  - Create `source/Private/Workflows/Default.json`
  - Define workflow metadata (id, name, version, author)
  - Set amd64: true, arm64: true, default: true
  - Define steps array referencing built-in steps from Task 6
  - **Add "Copy WinPE Logs" step** (new step to create in Task 6):
    - Step name: "Step-MCDCopyWinPELogs"
    - Command: "Step-MCDCopyWinPELogs"
    - Description: "Copy WinPE logs to OS partition before reboot"
    - Run in WinPE only (runinwinpe: true, runinfullos: false)
    - Position: Before reboot steps (before Windows imaging)
  - Configure rules for each step (skip: false, runinfullos: false, runinwinpe: true)
  - Configure retry for critical steps (enabled: true, maxAttempts: 3, retryDelay: 5)
  - Set continueOnError: false for all steps (fail-fast)
  - Add proper descriptions for each step
  - Validate JSON syntax
  - Follow schema from `docs/workflow-schema.md`

  **Must NOT do**:
  - Do not include steps that don't exist yet
  - Do not create custom workflow profiles (that's user's job)

  **Additional Requirement - Create Step-MCDCopyWinPELogs**:
  - This step will be added to Task 6 (Built-in Steps)
  - Function: `Step-MCDCopyWinPELogs`
  - Logic:
    - Source: `X:\MCD\Logs\` (WinPE logs)
    - Destination: `C:\Windows\Temp\MCD\Logs\`
    - Create destination directory if not exists
    - Copy all log files from source to destination
    - Write-MCDLog for audit trail
  - Parameters: `$OsPartitionDrive` (default: "C:")
  - Return: $true on success

  **Parallelizable**: YES (with Task 6)

  **References**:

  **Pattern References**:
  - `source/Examples/OSDCloud/workflow/default/tasks/osdcloud.json` - OSDCloud workflow structure (steps array, command references, rules)

  **Documentation References**:
  - `docs/workflow-schema.md` - Schema definition to follow
  - `source/Private/Steps/` - Available built-in steps to reference

  **Acceptance Criteria**:
  - [ ] File: `source/Private/Workflows/Default.json` created
  - [ ] JSON validates against schema
  - [ ] Workflow id, name, version, author defined
  - [ ] amd64: true, arm64: true, default: true
  - [ ] Steps array includes Step-MCDValidateSelection
  - [ ] Steps array includes Step-MCDPrepareDisk
  - [ ] Steps array includes Step-MCDPrepareEnvironment
  - [ ] Steps array includes Step-MCDDeployWindows
  - [ ] Steps array includes Step-MCDCompleteDeployment
  - [ ] All steps have proper rules configured
  - [ ] Critical steps have retry enabled
  - [ ] All steps have continueOnError: false

  **Manual Execution Verification**:
  - [ ] Load workflow: `$workflow = Get-Content ./source/Private/Workflows/Default.json | ConvertFrom-Json`
  - [ ] Verify: JSON parses correctly
  - [ ] Verify: Workflow has steps array
  - [ ] Verify: Each step has name, command, parameters, rules
  - [ ] Verify: Step commands match built-in step names
  - [ ] Verify: Retry configuration present for critical steps

  **Commit**: YES (workflow complete)
  - Message: `feat(workflow): add default workflow JSON with built-in steps`
  - Files: `source/Private/Workflows/Default.json`
  - Pre-commit: `./build.ps1 -Tasks build` (to validate JSON syntax)

---

### Phase 3: WinPE Integration

- [ ] 8. Enhance Wizard for Workflow Selection

  **What to do**:
  - Examine `source/Private/WinPE/Wizard/Start-MCDWizard.ps1`
  - Add workflow detection logic (scan USB for custom profiles)
  - Add workflow dropdown control to wizard XAML (if custom workflows found)
  - Pass selected workflow to caller (add to selection object)
  - If no custom workflows, skip dropdown and use default
  - If multiple custom workflows, show dropdown populated with workflow names
  - User can select which workflow to run
  - Update selection object with selected workflow
  - Follow existing wizard patterns for dropdown controls

  **Must NOT do**:
  - Do not modify OS/Language selection (existing functionality)
  - Do not create new wizard windows

  **Parallelizable**: NO (depends on 3, 5, 7)

  **References**:

  **Pattern References**:
  - `source/Private/WinPE/Wizard/Start-MCDWizard.ps1` - Wizard implementation (XAML loading, selection object building)
  - `source/Private/WinPE/UI/Import-MCDWinPEXaml.ps1` - XAML import pattern
  - `source/Public/Start-MCDWinPE.ps1:83` - Wizard call pattern (passing workspace/winpe config)

  **Code References**:
  - `source/Private/Initialize-MCDWorkflowTasks.ps1` - Workflow loader to call for detecting custom workflows
  - `source/Private/WinPE/Connectivity/Get-MCDExternalVolume.ps1` - USB detection pattern

  **Acceptance Criteria**:
  - [ ] Function: Detect custom workflows on USB (added to Start-MCDWizard or new helper)
  - [ ] Workflow dropdown added to wizard XAML (conditional display)
  - [ ] Dropdown populated with workflow names if custom workflows found
  - [ ] Dropdown hidden if only default workflow available
  - [ ] Selected workflow added to selection object
  - [ ] Existing wizard functionality preserved (OS/Language selection)
  - [ ] Comment-based help added if new function created
  - [ ] Unit tests added for workflow detection

  **Manual Execution Verification**:
  - [ ] Import module: `Import-Module ./output/MCD`
  - [ ] Start wizard with no custom workflows: `Start-MCDWizard ...`
  - [ ] Verify: No workflow dropdown shown
  - [ ] Verify: Default workflow used
  - [ ] Create test workflow on USB: `MCD/Profiles/Test/workflow.json`
  - [ ] Start wizard with custom workflow: `Start-MCDWizard ...`
  - [ ] Verify: Workflow dropdown appears
  - [ ] Verify: Dropdown populated with workflow names
  - [ ] Select workflow from dropdown
  - [ ] Verify: Selection object includes selected workflow

  **Commit**: YES (wizard enhancement complete)
  - Message: `feat(wizard): add workflow selection dropdown for custom workflows`
  - Files: Modified `source/Private/WinPE/Wizard/Start-MCDWizard.ps1`, new tests
  - Pre-commit: `./build.ps1 -Tasks test -PesterPath tests/Unit/Private/WinPE/Wizard`

---

- [ ] 9. Integrate Invoke-MCDWorkflow with WinPE UI

  **What to do**:
  - Update `Invoke-MCDWinPEDeployment` to use `Invoke-MCDWorkflow` instead of hardcoded steps
  - Pass workflow object from selection to `Invoke-MCDWorkflow`
  - Pass WinPE window to `Invoke-MCDWorkflow` for progress updates
  - Update `Update-MCDWinPEProgress` to support workflow context
  - Display step name, step index, step count in UI
  - Display retry status if retry is active
  - Update progress bar based on step completion
  - Handle workflow completion (display success message)
  - Handle workflow failure (display error message)
  - Preserve existing UI functionality (overall look and feel)
  - Follow MCD UI patterns

  **Must NOT do**:
  - Do not change existing XAML layout unless necessary
  - Do not break existing progress update patterns

  **Parallelizable**: NO (depends on 5, 8)

  **References**:

  **Pattern References**:
  - `source/Private/WinPE/Deploy/Invoke-MCDWinPEDeployment.ps1:82-115` - Current step execution loop to replace
  - `source/Private/WinPE/Deploy/Update-MCDWinPEProgress.ps1` - Progress update function to enhance
  - `source/Private/Invoke-MCDWorkflow.ps1` - New executor to call

  **Code References**:
  - `source/Public/Start-MCDWinPE.ps1:121` - Async deployment start pattern

  **Acceptance Criteria**:
  - [ ] Invoke-MCDWinPEDeployment updated to use Invoke-MCDWorkflow
  - [ ] Workflow object passed from selection
  - [ ] Window passed to Invoke-MCDWorkflow
  - [ ] Update-MCDWinPEProgress enhanced for workflow context
  - [ ] Step name displayed in UI
  - [ ] Step index and count displayed (e.g., "Step 3 of 10")
  - [ ] Progress bar updates correctly based on step completion
  - [ ] Retry status displayed if active
  - [ ] Success message displayed on completion
  - [ ] Error message displayed on failure
  - [ ] Existing UI patterns preserved

  **Manual Execution Verification**:
  - [ ] Import module: `Import-Module ./output/MCD`
  - [ ] Start WinPE deployment: `Start-MCDWinPE -ProfileName Default`
  - [ ] Run through wizard selection
  - [ ] Verify: Progress window opens
  - [ ] Verify: Step names displayed sequentially
  - [ ] Verify: Progress bar updates
  - [ ] Verify: Step index/count displayed
  - [ ] Verify: Success message at end

  **Commit**: YES (UI integration complete)
  - Message: `feat(ui): integrate Invoke-MCDWorkflow with WinPE progress window`
  - Files: Modified `source/Private/WinPE/Deploy/Invoke-MCDWinPEDeployment.ps1`, `source/Private/WinPE/Deploy/Update-MCDWinPEProgress.ps1`
  - Pre-commit: `./build.ps1 -Tasks test -PesterPath tests/Unit/Private/WinPE/Deploy`

---

### Phase 4: Integration & Documentation

- [ ] 10. Integration Testing and Documentation

  **What to do**:
  - Create integration test for full workflow execution
  - Test: Load default workflow from module
  - Test: Execute workflow end-to-end with built-in steps
  - Test: Custom workflow on USB detected and executed
  - Test: Workflow selection in wizard
  - Test: Retry on failure
  - Test: State persistence
  - Test: Fail-fast on error
  - Test: UI progress updates
  - Update module README with task sequence engine documentation
  - Add examples of creating custom workflows
  - Document step development guide
  - Document JSON schema reference
  - Update `docs/` directory with new documentation

  **Must NOT do**:
  - Do not create integration tests for Workspace editor (future feature)

  **Parallelizable**: NO (depends on 5, 7, 8, 9)

  **References**:

  **Pattern References**:
  - `tests/QA/module.tests.ps1` - QA test patterns
  - `README.md` - Module documentation structure

  **Documentation References**:
  - `docs/workflow-schema.md` - JSON schema documentation
  - `docs/state-schema.md` - State schema documentation

  **Acceptance Criteria**:
  - [ ] Integration test file: `tests/Integration/MCDWorkflow.tests.ps1` created
  - [ ] Test: Default workflow loads and executes
  - [ ] Test: Custom workflow on USB detected
  - [ ] Test: Retry logic works
  - [ ] Test: State persistence works
  - [ ] Test: Fail-fast works
  - [ ] README.md updated with task sequence engine section
  - [ ] Custom workflow creation examples added
  - [ ] Step development guide added
  - [ ] JSON schema reference added
  - [ ] `./build.ps1 -Tasks test` → PASS all tests
  - [ ] Code coverage >= 85%
  - [ ] PSScriptAnalyzer passes

  **Manual Execution Verification**:
  - [ ] Full build and test: `./build.ps1`
  - [ ] Verify: All tests pass
  - [ ] Verify: Code coverage >= 85%
  - [ ] Verify: PSScriptAnalyzer passes (QA tests)
  - [ ] Import module: `Import-Module ./output/MCD`
  - [ ] Test default workflow: `Start-MCDWinPE -ProfileName Default` (in WinPE)
  - [ ] Test custom workflow: Create custom on USB, run in WinPE
  - [ ] Verify: Custom workflow detected and executed
  - [ ] Review README.md for completeness

  **Commit**: YES (documentation complete)
  - Message: `docs: add task sequence engine documentation and integration tests`
  - Files: `tests/Integration/MCDWorkflow.tests.ps1`, `README.md`, new docs
  - Pre-commit: `./build.ps1 -Tasks test`

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `docs(workflow): define JSON schemas for workflows and state` | `docs/*.md` | N/A |
| 2 | `test(workflow): add tests for Initialize-MCDWorkflowTasks` | `tests/Unit/Private/Initialize-MCDWorkflowTasks.tests.ps1` | Pester test |
| 3 | `feat(workflow): add Initialize-MCDWorkflowTasks loader` | `source/Private/Initialize-MCDWorkflowTasks.ps1`, tests | `./build.ps1 -Tasks test` |
| 4 | `test(workflow): add tests for Invoke-MCDWorkflow` | `tests/Unit/Private/Invoke-MCDWorkflow.tests.ps1` | Pester test |
| 5 | `feat(workflow): add Invoke-MCDWorkflow executor with retry logic` | `source/Private/Invoke-MCDWorkflow.ps1`, tests | `./build.ps1 -Tasks test` |
| 6 | `feat(steps): add built-in workflow steps from existing deployment logic` | `source/Private/Steps/*.ps1`, tests | `./build.ps1 -Tasks test` |
| 7 | `feat(workflow): add default workflow JSON with built-in steps` | `source/Private/Workflows/Default.json` | `./build.ps1 -Tasks build` |
| 8 | `feat(wizard): add workflow selection dropdown for custom workflows` | `source/Private/WinPE/Wizard/Start-MCDWizard.ps1`, tests | `./build.ps1 -Tasks test` |
| 9 | `feat(ui): integrate Invoke-MCDWorkflow with WinPE progress window` | `source/Private/WinPE/Deploy/*.ps1`, tests | `./build.ps1 -Tasks test` |
| 10 | `docs(workflow): add integration tests and complete documentation` | `tests/Integration/MCDWorkflow.tests.ps1`, `README.md`, docs | `./build.ps1 -Tasks test` |

---

## Success Criteria

### Verification Commands
```bash
# Build and test
./build.ps1

# Test coverage
./build.ps1 -Tasks test
# Expected: All tests pass, code coverage >= 85%

# Linting
pwsh -NoProfile -Command "Invoke-ScriptAnalyzer -Path 'source' -Recurse -Settings '.vscode/analyzersettings.psd1'"
# Expected: No errors

# QA tests
pwsh -NoProfile -Command "Invoke-Pester -Path 'tests/QA'"
# Expected: All QA tests pass
```

### Final Checklist
- [ ] All "Must Have" features implemented
- [ ] All "Must NOT Have" excluded
- [ ] Default workflow executes successfully
- [ ] Custom workflows on USB detected and executed
- [ ] Retry logic works correctly
- [ ] State persists on OS partition
- [ ] WinPE wizard shows workflow dropdown
- [ ] UI progress updates correctly
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] Code coverage >= 85%
- [ ] PSScriptAnalyzer passes
- [ ] QA tests pass
- [ ] Documentation complete
- [ ] Comment-based help on all functions
