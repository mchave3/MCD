# State Schema

This document defines the JSON schema for the MCD (Modern Cloud Deployment) workflow state. The state file tracks the progress of a running workflow and allows for auditing and potentially resuming after reboots.

## State Fields

| Field | Type | Description |
| :--- | :--- | :--- |
| `workflowName` | String | Human-readable name of the workflow currently being executed. |
| `startTime` | String (ISO 8601) | When the workflow execution started. |
| `currentStepIndex` | Integer | The 0-based index of the step currently being executed or last attempted. |
| `steps` | Array | Progress and result information for each step. |

## Step State Fields

Each item in the `steps` array contains:

| Field | Type | Description |
| :--- | :--- | :--- |
| `name` | String | Name of the step (copied from workflow). |
| `command` | String | The PowerShell function name (copied from workflow). |
| `status` | String | Result of the step (e.g., `Completed`, `Failed`, `Running`). |
| `attempts` | Integer | Total number of times this step was attempted (including retries). |
| `lastAttemptTime` | String (ISO 8601) | When the most recent attempt for this step started. |
| `output` | String | A summary or data result produced by the step (if applicable). |

## Semantic Rules

1. **Persistence**: The state file is updated after every step completion (success or failure).
2. **Location**: In WinPE, this may be in RAM disk or on the target OS partition (`C:\Windows\Temp\MCD\State.json`).
3. **Atomic Updates**: State updates should be written atomically to prevent corruption during unexpected shutdowns or reboots.

## Example State

```json
{
  "workflowName": "Default Deployment",
  "startTime": "2026-01-28T14:00:00Z",
  "currentStepIndex": 5,
  "steps": [
    {
      "name": "Prepare Disk",
      "command": "Step-MCDPrepareDisk",
      "status": "Completed",
      "attempts": 1,
      "lastAttemptTime": "2026-01-28T14:01:00Z",
      "output": "Disk 0 partitioned successfully"
    },
    {
      "name": "Deploy Windows",
      "command": "Step-MCDDeployWindows",
      "status": "Running",
      "attempts": 1,
      "lastAttemptTime": "2026-01-28T14:05:00Z",
      "output": null
    }
  ]
}
```
