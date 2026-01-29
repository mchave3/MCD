# MCD

MCD (Modern Cloud Deployment) is a modern PowerShell framework for deploying Windows operating systems from the cloud, replacing traditional on-premises deployment solutions.

## Features

- **Cloud-Native Deployment**: Deploy Windows directly from Microsoft's content delivery network
- **WinPE Integration**: Full Windows PE environment with modern UI
- **Task Sequence Engine**: JSON-based workflow system for customizable deployments
- **USB Profile Support**: Custom configurations and workflows via USB drives

## Installation

```powershell
Install-Module -Name MCD -Scope CurrentUser
```

## Quick Start

### Start WinPE Deployment

```powershell
Start-MCDWinPE -ProfileName Default
```

### Start Workspace (Admin PC)

```powershell
Start-MCDWorkspace
```

## Task Sequence Engine

MCD uses a JSON-based task sequence engine for flexible, customizable deployments. Workflows define the steps executed during deployment, with support for retry logic, architecture filtering, and environment-specific execution.

### Workflow Structure

Workflows are defined in JSON files with the following structure:

```json
{
  "id": "unique-workflow-id",
  "name": "Workflow Name",
  "description": "Description of what this workflow does",
  "version": "1.0.0",
  "author": "Author Name",
  "amd64": true,
  "arm64": true,
  "default": true,
  "steps": [
    {
      "name": "Step Display Name",
      "description": "What this step does",
      "command": "Step-FunctionName",
      "args": [],
      "parameters": {},
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

### Creating Custom Workflows

1. Create a USB profile directory: `MCD/Profiles/<ProfileName>/`
2. Create a `workflow.json` file in the profile directory
3. Define your steps, referencing built-in or custom step functions
4. Custom step functions can be placed in `MCD/Profiles/<ProfileName>/Steps/`

### Built-in Steps

| Step | Description |
|------|-------------|
| `Step-MCDValidateSelection` | Validates the wizard selection before deployment |
| `Step-MCDPrepareEnvironment` | Prepares the deployment environment |
| `Step-MCDPrepareDisk` | Prepares and partitions the target disk |
| `Step-MCDDeployWindows` | Deploys the Windows image |
| `Step-MCDCopyWinPELogs` | Copies WinPE logs to OS partition |
| `Step-MCDCompleteDeployment` | Finalizes deployment and prepares for reboot |

### Step Rules

| Rule | Description |
|------|-------------|
| `skip` | Skip this step entirely when `true` |
| `runinwinpe` | Execute this step in WinPE environment |
| `runinfullos` | Execute this step in full OS environment |
| `architecture` | Array of architectures where step runs (`amd64`, `arm64`) |
| `retry.enabled` | Enable automatic retry on failure |
| `retry.maxAttempts` | Maximum retry attempts |
| `retry.retryDelay` | Seconds to wait between retries |
| `continueOnError` | Continue workflow if step fails |

### State Persistence

Workflow state is persisted to `C:\Windows\Temp\MCD\State.json`, enabling recovery and debugging. The state includes:

- Current step index
- Step execution status
- Attempt counts and timestamps
- Error information

### Logging

Logs are written to:
- **Master log**: `C:\Windows\Temp\MCD\Logs\master.log`
- **Per-step logs**: `C:\Windows\Temp\MCD\Logs\<Index>_<StepName>.log`

## Development

### Building

```powershell
./build.ps1 -Tasks build
```

### Testing

```powershell
./build.ps1 -Tasks test
```

### Running Specific Tests

```powershell
./build.ps1 -Tasks test -PesterPath tests/Unit/Private/Invoke-MCDWorkflow.Tests.ps1
```

## Contributing

Please see the [Contributing Guide](CONTRIBUTING.md) for details on how to contribute to this project.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
