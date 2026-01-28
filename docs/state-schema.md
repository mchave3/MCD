# MCD State JSON Schema

This document defines the JSON schema for MCD workflow execution state persistence.

## Overview

The MCD workflow executor maintains a state file that tracks workflow execution progress, step status, and results. The state file is used for:
- Resuming workflows after reboots
- Troubleshooting deployment issues
- Auditing deployment execution history
- Providing context to steps via global variables

## State File Location

The state file is persisted at:
- **Path**: `C:\Windows\Temp\MCD\State.json`
- **Created by**: `Invoke-MCDWorkflow`
- **Updated**: After each step completion
- **Read**: On workflow startup for resume capability

## State Structure

```json
{
  "workflowName": "Workflow Name",
  "workflowId": "workflow-uuid",
  "startTime": "2026-01-28T14:00:00Z",
  "endTime": null,
  "status": "InProgress",
  "currentStepIndex": 5,
  "totalSteps": 10,
  "architecture": "amd64",
  "isWinPE": true,
  "steps": [
    {
      "name": "Step Display Name",
      "command": "Step-FunctionName",
      "description": "Step description",
      "status": "Completed",
      "attempts": 1,
      "lastAttemptTime": "2026-01-28T14:01:00Z",
      "duration": 12.5,
      "output": "Step output data",
      "error": null
    }
  ]
}
```

## State Fields

### Top-Level Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `workflowName` | string | Yes | Name of the workflow being executed |
| `workflowId` | string | Yes | Unique identifier of the workflow |
| `startTime` | string | Yes | ISO 8601 timestamp when workflow started |
| `endTime` | string \| null | No | ISO 8601 timestamp when workflow completed (null if in progress) |
| `status` | string | Yes | Current workflow status: "InProgress", "Completed", "Failed", "Cancelled" |
| `currentStepIndex` | integer | Yes | Index of the current step (0-based) |
| `totalSteps` | integer | Yes | Total number of steps in workflow |
| `architecture` | string | Yes | System architecture: "amd64" or "arm64" |
| `isWinPE` | boolean | Yes | Whether execution is in WinPE environment |
| `steps` | array | Yes | Array of step state objects |

### Step State Fields

Each step in the `steps` array is an object with the following fields:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Human-readable name of the step |
| `command` | string | Yes | Name of the PowerShell function executed |
| `description` | string | Yes | Description of what the step does |
| `status` | string | Yes | Step status: "Pending", "InProgress", "Completed", "Failed", "Skipped" |
| `attempts` | integer | Yes | Number of execution attempts made |
| `lastAttemptTime` | string | Yes | ISO 8601 timestamp of last execution attempt |
| `duration` | number | No | Execution duration in seconds (null if not completed) |
| `output` | string \| null | No | Step output data (captured from stdout) |
| `error` | string \| null | No | Error message if step failed (null if successful) |

## Workflow Status Values

| Status | Description |
|--------|-------------|
| `InProgress` | Workflow is currently executing |
| `Completed` | All steps completed successfully |
| `Failed` | Workflow failed (step failed with continueOnError: false) |
| `Cancelled` | Workflow was cancelled by user or system |

## Step Status Values

| Status | Description |
|--------|-------------|
| `Pending` | Step has not started yet |
| `InProgress` | Step is currently executing |
| `Completed` | Step completed successfully |
| `Failed` | Step failed after all retry attempts |
| `Skipped` | Step was skipped (skip: true or architecture mismatch) |

## State Persistence Strategy

### Write After Each Step

The state file is updated after each step completion:
1. Step executes
2. Result captured (success/failure)
3. State file updated with step status
4. State file written to disk

### Write on Failure

The state file is also updated on failure:
1. Step fails (all retry attempts exhausted)
2. Error captured
3. State file updated with failure status
4. State file written to disk

### Write on Workflow Completion

On workflow completion:
1. `status` set to "Completed" or "Failed"
2. `endTime` set to current timestamp
3. Final state written to disk

## State Loading (Resume Capability)

### On Workflow Startup

When `Invoke-MCDWorkflow` starts:

1. Check if state file exists at `C:\Windows\Temp\MCD\State.json`
2. If exists, load and validate:
   - Parse JSON
   - Validate structure
   - Check if workflow ID matches current workflow
3. If valid:
   - Set `currentStepIndex` to `totalSteps` (full restart)
   - Set `status` to "InProgress"
   - Log resume attempt
4. If invalid or missing:
   - Create new state file
   - Initialize with current workflow info
   - Set `currentStepIndex` to 0

### Resume Behavior

MCD uses full restart on failure/reboot:
- Workflow restarts from step 0 (not from failed step)
- Previous state is preserved for audit/history
- Steps can read previous execution data from state if needed

## Global Variable Context

In addition to the state file, workflow execution context is also maintained via global variables (OSDCloud pattern):

### Global Variables

```powershell
# Boolean: Whether running in WinPE
[bool]$global:MCDWorkflowIsWinPE = ($env:SystemDrive -eq 'X:')

# Integer: Current step index (0-based)
[int]$global:MCDWorkflowCurrentStepIndex = 0

# Hashtable: Workflow context
[hashtable]$global:MCDWorkflowContext = @{
  Window         = $Window              # WinPE UI window (if available)
  CurrentStep   = $step                # Current step object
  LogsRoot      = $logsRoot            # Path to logs directory
  StatePath     = "C:\Windows\Temp\MCD\State.json"
  StartTime      = [datetime](Get-Date)
}
```

### Accessing Global Context

Steps can access context via global variables:
```powershell
$stepName = $global:MCDWorkflowContext.CurrentStep.name
$stepIndex = $global:MCDWorkflowCurrentStepIndex
$isWinPE = $global:MCDWorkflowIsWinPE
```

### Writing to Global Context

Steps can write results to global context for other steps:
```powershell
$global:MCDWorkflowContext.DiskLayout = $diskLayout
$global:MCDWorkflowContext.WindowsImage = $selectedImage
```

## Example State File

```json
{
  "workflowName": "MCD Default Deployment",
  "workflowId": "550e8400-e29b-41d4-a716-446655440000",
  "startTime": "2026-01-28T14:00:00Z",
  "endTime": null,
  "status": "InProgress",
  "currentStepIndex": 3,
  "totalSteps": 6,
  "architecture": "amd64",
  "isWinPE": true,
  "steps": [
    {
      "name": "Validate Selection",
      "command": "Step-MCDValidateSelection",
      "description": "Validate wizard selection before deployment",
      "status": "Completed",
      "attempts": 1,
      "lastAttemptTime": "2026-01-28T14:00:05Z",
      "duration": 5.2,
      "output": "Selection validated successfully",
      "error": null
    },
    {
      "name": "Prepare Disk",
      "command": "Step-MCDPrepareDisk",
      "description": "Prepare target disk for deployment",
      "status": "Completed",
      "attempts": 1,
      "lastAttemptTime": "2026-01-28T14:00:15Z",
      "duration": 10.8,
      "output": "Disk 0 prepared successfully",
      "error": null
    },
    {
      "name": "Copy WinPE Logs",
      "command": "Step-MCDCopyWinPELogs",
      "description": "Copy WinPE logs to OS partition before reboot",
      "status": "Completed",
      "attempts": 1,
      "lastAttemptTime": "2026-01-28T14:00:25Z",
      "duration": 3.5,
      "output": "Copied 5 log files from X:\\MCD\\Logs\\ to C:\\Windows\\Temp\\MCD\\Logs\\",
      "error": null
    },
    {
      "name": "Prepare Environment",
      "command": "Step-MCDPrepareEnvironment",
      "description": "Prepare deployment environment",
      "status": "InProgress",
      "attempts": 1,
      "lastAttemptTime": "2026-01-28T14:00:28Z",
      "duration": null,
      "output": null,
      "error": null
    },
    {
      "name": "Deploy Windows",
      "command": "Step-MCDDeployWindows",
      "description": "Deploy Windows image to disk",
      "status": "Pending",
      "attempts": 0,
      "lastAttemptTime": null,
      "duration": null,
      "output": null,
      "error": null
    },
    {
      "name": "Complete Deployment",
      "command": "Step-MCDCompleteDeployment",
      "description": "Complete deployment process",
      "status": "Pending",
      "attempts": 0,
      "lastAttemptTime": null,
      "duration": null,
      "output": null,
      "error": null
    }
  ]
}
```

## State File Management

### Directory Creation

The state directory is created automatically:
```powershell
$stateDirectory = Split-Path -Path $StatePath -Parent
if (-not (Test-Path -Path $stateDirectory)) {
  New-Item -Path $stateDirectory -ItemType Directory -Force | Out-Null
}
```

### File Overwriting

The state file is overwritten on each update (no versioning):
- Previous state is lost on write
- Only current state is preserved
- For history, rely on master log file

### File Permissions

The state file is created with default permissions:
- Owner: SYSTEM (in WinPE) or Administrator (in full OS)
- Read/Write for owner
- No ACL restrictions (simple model)

## State File Validation

### Required Fields

At minimum, the state file must contain:
- `workflowName`
- `workflowId`
- `startTime`
- `status`
- `currentStepIndex`
- `totalSteps`
- `steps` array

### Optional Fields

The following fields are optional:
- `endTime` (null if workflow not completed)
- `step.duration` (null if step not completed)
- `step.output` (null if no output)
- `step.error` (null if no error)

## Troubleshooting

### State File Issues

**Problem**: State file not found
- **Cause**: First execution or state deleted
- **Solution**: Create new state file, start from step 0

**Problem**: State file is corrupted
- **Cause**: Disk error or interrupted write
- **Solution**: Create new state file, start from step 0

**Problem**: Workflow ID mismatch
- **Cause**: Different workflow than previous execution
- **Solution**: Create new state file, start from step 0

### Debugging

To view current state:
```powershell
Get-Content -Path "C:\Windows\Temp\MCD\State.json" | ConvertFrom-Json | ConvertTo-Json -Depth 10
```

To view step history:
```powershell
$state = Get-Content -Path "C:\Windows\Temp\MCD\State.json" | ConvertFrom-Json
$state.steps | Where-Object { $_.status -eq "Failed" } | Select-Object name, status, attempts, error
```

## Related Documentation

- [Workflow Schema](workflow-schema.md) - Workflow configuration structure
- [Logging Strategy](../README.md) - How logs are captured and stored
- [Step Development](../README.md) - How to create steps that use global context
