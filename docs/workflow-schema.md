# MCD Workflow JSON Schema

This document defines the JSON schema for MCD workflow configuration files.

## Overview

MCD workflows define a sequence of deployment steps that execute during the Windows deployment process. Workflows are stored as JSON files and can be either built-in (included with the module) or custom (provided by users on USB profiles).

## Workflow Structure

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

## Workflow Metadata Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Unique identifier for the workflow (UUID format recommended) |
| `name` | string | Yes | Human-readable name of the workflow |
| `description` | string | Yes | Detailed description of what the workflow does |
| `version` | string | Yes | Version number following semantic versioning (e.g., "1.0.0") |
| `author` | string | Yes | Author or organization that created the workflow |
| `amd64` | boolean | Yes | Whether this workflow supports x64 architecture |
| `arm64` | boolean | Yes | Whether this workflow supports ARM64 architecture |
| `default` | boolean | Yes | Whether this is the default workflow (only one should be default) |
| `steps` | array | Yes | Array of step objects defining the workflow sequence |

## Step Fields

Each step in the `steps` array is an object with the following fields:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Human-readable name of the step |
| `description` | string | Yes | Detailed description of what the step does |
| `command` | string | Yes | Name of the PowerShell function to execute |
| `args` | array | No | Array of positional arguments to pass to the command |
| `parameters` | object | No | Hashtable of named parameters to pass to the command |
| `rules` | object | Yes | Rules governing step execution |

### Command Execution

The step command must be a valid PowerShell function that exists in either:
- Built-in steps: `source/Private/Steps/*.ps1`
- Custom steps: `MCD/Profiles/<ProfileName>/Steps/*.ps1`

The command is invoked using PowerShell splatting:
```powershell
& $step.command @step.parameters @step.args
```

## Step Rules

### Rule Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `skip` | boolean | Yes | false | If true, the step is skipped during execution |
| `runinfullos` | boolean | Yes | false | If true, the step runs only in full OS environment |
| `runinwinpe` | boolean | Yes | false | If true, the step runs only in WinPE environment |
| `architecture` | array | Yes | ["amd64", "arm64"] | Supported architectures for this step |
| `retry` | object | Yes | See below | Retry configuration |
| `continueOnError` | boolean | Yes | false | If true, workflow continues after step fails |

### Architecture Filtering

Steps are filtered based on:
1. Current system architecture (detected at runtime)
2. Step's `architecture` array

If the current architecture is not in the step's `architecture` array, the step is skipped.

### Execution Environment Rules

- `runinfullos`: Step executes only when NOT in WinPE (`$env:SystemDrive -ne 'X:'`)
- `runinwinpe`: Step executes only when IN WinPE (`$env:SystemDrive -eq 'X:'`)
- Both `runinfullos` and `runinwinpe` can be true (step runs in both environments)
- If both are false, the step runs in the current environment

## Retry Configuration

### Retry Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `enabled` | boolean | Yes | false | Whether retry is enabled for this step |
| `maxAttempts` | integer | Yes | 3 | Maximum number of execution attempts |
| `retryDelay` | integer | Yes | 5 | Delay in seconds between retry attempts |

### Retry Behavior

When `retry.enabled` is `true`:
1. Step execution is attempted up to `maxAttempts` times
2. After each failure, the step waits `retryDelay` seconds before retrying
3. If all attempts fail, the step throws the last error
4. Retry attempts are logged with attempt number (e.g., "Step failed (attempt 2/3), retrying in 5s...")
5. Per-step transcript logs are overwritten on retry (no attempt history)

When `retry.enabled` is `false`:
- Step executes once and fails immediately on error

### Example Retry Configuration

```json
"retry": {
  "enabled": true,
  "maxAttempts": 5,
  "retryDelay": 10
}
```

This configuration retries the step up to 5 times with a 10-second delay between attempts.

## Error Handling

### Fail-Fast (Default)

When `continueOnError` is `false` (default):
- Workflow stops immediately on step failure
- No subsequent steps execute
- Error is thrown to caller
- State is saved with failure status

### Continue on Error

When `continueOnError` is `true`:
- Workflow continues to next step after failure
- Error is logged but not thrown
- Subsequent steps execute
- Step status in state is marked as "Failed" but workflow continues

## Step Execution Order

Steps execute in sequential order as defined in the `steps` array:
1. Step 0 (first step)
2. Step 1
3. ...
4. Step N (last step)

No parallel execution or explicit step dependencies are supported. All dependencies must be managed through step ordering.

## Validation Rules

### At Load Time (Warnings)
- Missing step commands: Warning logged, workflow still loaded
- Invalid JSON: Warning logged, workflow skipped
- Missing required fields: Warning logged, workflow skipped

### Before Execution (Errors)
- Missing step command: Error thrown, workflow stops
- Step not found: Error thrown, workflow stops
- Invalid architecture: Step skipped with verbose message

## Example Complete Workflow

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "MCD Default Deployment",
  "description": "Default MCD deployment workflow for Windows deployment",
  "version": "1.0.0",
  "author": "MCD",
  "amd64": true,
  "arm64": true,
  "default": true,
  "steps": [
    {
      "name": "Validate Selection",
      "description": "Validate wizard selection before deployment",
      "command": "Step-MCDValidateSelection",
      "args": [],
      "parameters": {},
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
    },
    {
      "name": "Prepare Disk",
      "description": "Prepare target disk for deployment",
      "command": "Step-MCDPrepareDisk",
      "args": [],
      "parameters": {
        "DiskNumber": 0,
        "DiskPolicy": "Clean"
      },
      "rules": {
        "skip": false,
        "runinfullos": false,
        "runinwinpe": true,
        "architecture": ["amd64", "arm64"],
        "retry": {
          "enabled": true,
          "maxAttempts": 3,
          "retryDelay": 5
        },
        "continueOnError": false
      }
    }
  ]
}
```

## File Location

- **Built-in workflows**: `source/Private/Workflows/*.json`
- **Custom workflows**: `MCD/Profiles/<ProfileName>/workflow.json`

## Related Documentation

- [State Schema](state-schema.md) - Workflow execution state persistence
- [Step Development Guide](../README.md) - How to create custom steps
- [Workflow Examples](../Examples/) - Example workflow files
