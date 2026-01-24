<#
    .SYNOPSIS
    MCD Deployment class for managing WinPE runtime state.

    .DESCRIPTION
    The MCDDeployment class represents the runtime state during a Windows deployment
    in the WinPE environment. It tracks deployment progress, manages logging per step,
    and handles log preservation before reboot.
#>
class MCDDeployment
{
    # Unique identifier for this deployment session
    [string] $SessionId

    # Working directory in WinPE (typically X:\MCD)
    [string] $WorkingPath = 'X:\MCD'

    # Target disk for Windows installation (e.g., '0' for disk 0)
    [string] $TargetDisk

    # Path to the Windows image (WIM/ESD) to apply
    [string] $ImagePath

    # Step tracking hashtable - stores step name -> status/logs
    [hashtable] $Steps = @{}

    # Associated configuration object
    [MCDConfig] $Config

    # Deployment start time
    [datetime] $StartTime

    # Default constructor
    MCDDeployment()
    {
        $this.SessionId = [guid]::NewGuid().ToString()
        $this.StartTime = Get-Date
        $this.InitializeSteps()
    }

    # Constructor with config
    MCDDeployment([MCDConfig] $Config)
    {
        $this.SessionId = [guid]::NewGuid().ToString()
        $this.StartTime = Get-Date
        $this.Config = $Config
        $this.InitializeSteps()
    }

    # Constructor with config and custom working path
    MCDDeployment([MCDConfig] $Config, [string] $WorkingPath)
    {
        $this.SessionId = [guid]::NewGuid().ToString()
        $this.StartTime = Get-Date
        $this.Config = $Config
        $this.WorkingPath = $WorkingPath
        $this.InitializeSteps()
    }

    <#
        .SYNOPSIS
        Initializes the default deployment steps.

        .DESCRIPTION
        Sets up the standard deployment steps with their initial status.
    #>
    hidden [void] InitializeSteps()
    {
        $this.Steps = [ordered]@{
            '01-Initialize'   = @{ Status = 'Pending'; StartTime = $null; EndTime = $null; Logs = @() }
            '02-Wizard'       = @{ Status = 'Pending'; StartTime = $null; EndTime = $null; Logs = @() }
            '03-Format'       = @{ Status = 'Pending'; StartTime = $null; EndTime = $null; Logs = @() }
            '04-Image'        = @{ Status = 'Pending'; StartTime = $null; EndTime = $null; Logs = @() }
            '05-Drivers'      = @{ Status = 'Pending'; StartTime = $null; EndTime = $null; Logs = @() }
            '06-Provisioning' = @{ Status = 'Pending'; StartTime = $null; EndTime = $null; Logs = @() }
            '07-Cleanup'      = @{ Status = 'Pending'; StartTime = $null; EndTime = $null; Logs = @() }
        }
    }

    <#
        .SYNOPSIS
        Initializes the deployment working directory structure.

        .DESCRIPTION
        Creates the required directories in the WinPE environment.
    #>
    [void] Initialize()
    {
        if ([string]::IsNullOrEmpty($this.WorkingPath))
        {
            throw 'Cannot initialize deployment: WorkingPath is not configured.'
        }

        # Create main working directory
        if (-not (Test-Path -Path $this.WorkingPath))
        {
            New-Item -Path $this.WorkingPath -ItemType Directory -Force | Out-Null
        }

        # Create logs directory
        $logsPath = Join-Path -Path $this.WorkingPath -ChildPath 'Logs'
        if (-not (Test-Path -Path $logsPath))
        {
            New-Item -Path $logsPath -ItemType Directory -Force | Out-Null
        }

        # Create temp directory
        $tempPath = Join-Path -Path $this.WorkingPath -ChildPath 'Temp'
        if (-not (Test-Path -Path $tempPath))
        {
            New-Item -Path $tempPath -ItemType Directory -Force | Out-Null
        }
    }

    <#
        .SYNOPSIS
        Logs a message for a specific deployment step.

        .DESCRIPTION
        Records a log entry for the specified step with a timestamp.
        Also writes to the step's log file if file logging is enabled.

        .PARAMETER StepName
        The name of the deployment step (e.g., '01-Initialize', '04-Image').

        .PARAMETER Message
        The message to log.

        .PARAMETER Level
        The log level (Info, Warn, Error). Defaults to Info.
    #>
    [void] LogStep([string] $StepName, [string] $Message)
    {
        $this.LogStep($StepName, $Message, 'Info')
    }

    [void] LogStep([string] $StepName, [string] $Message, [string] $Level)
    {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $logEntry = "[$timestamp] [$Level] $Message"

        # Ensure step exists in tracking
        if (-not $this.Steps.ContainsKey($StepName))
        {
            $this.Steps[$StepName] = @{
                Status    = 'InProgress'
                StartTime = Get-Date
                EndTime   = $null
                Logs      = @()
            }
        }

        # Add to in-memory logs
        $this.Steps[$StepName].Logs += $logEntry

        # Write to step log file
        $logsPath = Join-Path -Path $this.WorkingPath -ChildPath 'Logs'
        if (Test-Path -Path $logsPath)
        {
            $logFile = Join-Path -Path $logsPath -ChildPath "$StepName.log"
            Add-Content -Path $logFile -Value $logEntry -ErrorAction SilentlyContinue
        }
    }

    <#
        .SYNOPSIS
        Marks a step as started.

        .PARAMETER StepName
        The name of the step to start.
    #>
    [void] StartStep([string] $StepName)
    {
        if ($this.Steps.ContainsKey($StepName))
        {
            $this.Steps[$StepName].Status = 'InProgress'
            $this.Steps[$StepName].StartTime = Get-Date
        }
        $this.LogStep($StepName, "Step started: $StepName")
    }

    <#
        .SYNOPSIS
        Marks a step as completed.

        .PARAMETER StepName
        The name of the step to complete.

        .PARAMETER Success
        Whether the step completed successfully.
    #>
    [void] CompleteStep([string] $StepName, [bool] $Success)
    {
        if ($this.Steps.ContainsKey($StepName))
        {
            $this.Steps[$StepName].Status = if ($Success) { 'Completed' } else { 'Failed' }
            $this.Steps[$StepName].EndTime = Get-Date
        }
        $status = if ($Success) { 'successfully' } else { 'with errors' }
        $this.LogStep($StepName, "Step completed $status`: $StepName")
    }

    <#
        .SYNOPSIS
        Copies deployment logs to the target OS before reboot.

        .DESCRIPTION
        Copies all logs from X:\MCD\Logs to C:\Temp\MCD\ so they persist
        after WinPE reboot into the installed Windows.
    #>
    [void] CopyLogsToTarget()
    {
        $sourcePath = Join-Path -Path $this.WorkingPath -ChildPath 'Logs'
        $targetPath = 'C:\Temp\MCD'

        # Check if source exists
        if (-not (Test-Path -Path $sourcePath))
        {
            return
        }

        # Check if C: drive is accessible
        if (-not (Test-Path -Path 'C:\'))
        {
            # Try to write to a fallback location
            $fallbackPath = Join-Path -Path $this.WorkingPath -ChildPath 'LogsArchive'
            if (-not (Test-Path -Path $fallbackPath))
            {
                New-Item -Path $fallbackPath -ItemType Directory -Force | Out-Null
            }
            Copy-Item -Path "$sourcePath\*" -Destination $fallbackPath -Recurse -Force -ErrorAction SilentlyContinue
            return
        }

        # Create target directory
        if (-not (Test-Path -Path $targetPath))
        {
            New-Item -Path $targetPath -ItemType Directory -Force | Out-Null
        }

        # Copy logs with session subfolder
        $sessionPath = Join-Path -Path $targetPath -ChildPath $this.SessionId
        if (-not (Test-Path -Path $sessionPath))
        {
            New-Item -Path $sessionPath -ItemType Directory -Force | Out-Null
        }

        Copy-Item -Path "$sourcePath\*" -Destination $sessionPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    <#
        .SYNOPSIS
        Gets the elapsed time since deployment started.

        .OUTPUTS
        [timespan] The elapsed time.
    #>
    [timespan] GetElapsedTime()
    {
        return (Get-Date) - $this.StartTime
    }

    <#
        .SYNOPSIS
        Gets the current step being executed.

        .OUTPUTS
        [string] The name of the current step, or $null if none.
    #>
    [string] GetCurrentStep()
    {
        foreach ($stepName in $this.Steps.Keys)
        {
            if ($this.Steps[$stepName].Status -eq 'InProgress')
            {
                return $stepName
            }
        }
        return $null
    }

    <#
        .SYNOPSIS
        Returns a string representation of the deployment.

        .OUTPUTS
        [string] A description of the deployment.
    #>
    [string] ToString()
    {
        $elapsed = $this.GetElapsedTime().ToString('hh\:mm\:ss')
        return "MCDDeployment: $($this.SessionId) - Elapsed: $elapsed"
    }
}
