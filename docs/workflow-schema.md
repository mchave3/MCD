# Workflow Schema

This document defines the JSON schema for MCD (Modern Cloud Deployment) workflows. Workflows are sequential task sequences that define the deployment process.

## Metadata Fields

| Field | Type | Description |
| :--- | :--- | :--- |
| `id` | String (GUID) | Unique identifier for the workflow. |
| `name` | String | Human-readable name of the workflow. |
| `description` | String | Purpose of the workflow (minimum 40 characters recommended). |
| `version` | String | Semantic version of the workflow definition. |
| `author` | String | Person or organization that created the workflow. |
| `amd64` | Boolean | Whether this workflow supports x64 architecture. |
| `arm64` | Boolean | Whether this workflow supports ARM64 architecture. |
| `default` | Boolean | Whether this is a default built-in workflow. |
| `steps` | Array | Ordered list of task steps to execute. |

## Step Fields

Each item in the `steps` array must contain:

| Field | Type | Description |
| :--- | :--- | :--- |
| `name` | String | Name of the step. |
| `description` | String | Description of what the step does. |
| `command` | String | The PowerShell function name to execute. |
| `args` | Array | Positional arguments passed to the command. |
| `parameters` | Object | Key-value pairs passed as named parameters to the command. |
| `rules` | Object | Execution control rules for the step. |

### Step Rules

| Rule | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `skip` | Boolean | `false` | If `true`, the step is ignored. |
| `runinfullos` | Boolean | `false` | If `true`, the step can run in the full Operating System. |
| `runinwinpe` | Boolean | `true` | If `true`, the step can run in Windows PE. |
| `architecture` | Array | `["amd64", "arm64"]` | List of supported architectures (e.g., `["amd64"]`). |
| `retry` | Object | See below | Configuration for retrying the step on failure. |
| `continueOnError` | Boolean | `false` | If `true`, the workflow continues even if this step fails. |

#### Retry Configuration

| Field | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `enabled` | Boolean | `false` | Whether retry is enabled for this step. |
| `maxAttempts` | Integer | `3` | Maximum number of attempts including the first one. |
| `retryDelay` | Integer | `5` | Seconds to wait between retry attempts. |

## Semantic Rules

1. **Sequential Execution**: Steps are executed strictly in the order they appear in the `steps` array.
2. **Fail-Fast**: By default, any step failure stops the workflow unless `continueOnError` is `true`.
3. **No Inline Scripts**: The `command` field must refer to an existing PowerShell function. Complex logic should be encapsulated in a function.
4. **Retry Behavior**: If a step is retried, the previous failure is logged in the master log, but the log file for the step is overwritten on each attempt.

## Example Workflow

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "Default Deployment",
  "description": "Standard cloud deployment workflow for Windows 11 Enterprise.",
  "version": "1.0.0",
  "author": "MCD Team",
  "amd64": true,
  "arm64": true,
  "default": true,
  "steps": [
    {
      "name": "Initialize Environment",
      "description": "Prepare the WinPE environment for deployment.",
      "command": "Initialize-MCDEnvironment",
      "args": [],
      "parameters": {
        "Verbose": true
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
    },
    {
      "name": "Format Disk",
      "description": "Wipe and partition the primary system disk.",
      "command": "Invoke-MCDDiskPart",
      "args": [],
      "parameters": {
        "DiskNumber": 0
      },
      "rules": {
        "skip": false,
        "runinfullos": false,
        "runinwinpe": true,
        "architecture": ["amd64"],
        "retry": {
          "enabled": false
        },
        "continueOnError": false
      }
    }
  ]
}
```
