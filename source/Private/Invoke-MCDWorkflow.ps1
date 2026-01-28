function Invoke-MCDWorkflow {
    <#
    .SYNOPSIS
    Executes an MCD workflow with retry logic, state persistence, and UI updates.

    .DESCRIPTION
    Executes a workflow object loaded by Initialize-MCDWorkflowTasks. Supports retry
    logic, fail-fast behavior, progress UI updates, state persistence to
    C:\Windows\Temp\MCD\State.json, and WinPE log copying to OS partition.
    Uses global variables for context (OSDCloud pattern).

    .PARAMETER WorkflowObject
    Workflow object to execute. Must be loaded by Initialize-MCDWorkflowTasks.

    .PARAMETER Window
    WinPE UI window object for progress updates. Pass to Update-MCDWinPEProgress.

    .EXAMPLE
    $workflows = Initialize-MCDWorkflowTasks
    Invoke-MCDWorkflow -WorkflowObject $workflows[0]

    Executes the first (default) workflow.

    .OUTPUTS
    None
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCustomObject]
        $WorkflowObject,

        [Parameter(Mandatory = $false)]
        [System.Object]
        $Window
    )

    #=================================================
    $Error.Clear()
    Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Start"
    Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Workflow: $($WorkflowObject.name)"
    Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Steps: $($WorkflowObject.steps.Count)"
    #=================================================

    #=================================================
    # Initialize global workflow variables (OSDCloud pattern)
    #=================================================
    [System.Boolean]$global:MCDWorkflowIsWinPE = ($env:SystemDrive -eq 'X:')
    [int]$global:MCDWorkflowCurrentStepIndex = 0
    [hashtable]    $global:MCDWorkflowContext = [ordered]@{
        Window         = $Window
        CurrentStep   = $null
        LogsRoot      = $null
        StatePath     = "C:\Windows\Temp\MCD\State.json"
        StartTime      = [datetime](Get-Date)
    }

    Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] IsWinPE: $global:MCDWorkflowIsWinPE"

    #=================================================
    # Setup logs directory
    #=================================================
    if ($global:MCDWorkflowIsWinPE) {
        $global:MCDWorkflowContext.LogsRoot = "X:\MCD\Logs"
    }
    else {
        $global:MCDWorkflowContext.LogsRoot = "C:\Windows\Temp\MCD\Logs"
    }

    $logsDirectory = $global:MCDWorkflowContext.LogsRoot
    if (-not (Test-Path -Path $logsDirectory)) {
        New-Item -Path $logsDirectory -ItemType Directory -Force | Out-Null
        Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Created logs directory: $logsDirectory"
    }

    #=================================================
    # Load state from previous execution (resume support)
    #=================================================
    $statePath = $global:MCDWorkflowContext.StatePath
    $previousState = $null

    if (Test-Path -Path $statePath) {
        Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Loading previous state from: $statePath"
        try {
            $previousState = Get-Content -Path $statePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop

            if ($previousState.workflowId -eq $WorkflowObject.id) {
                Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Previous state found, full restart from step 0"
            }
            else {
                Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Different workflow, creating new state"
                $previousState = $null
            }
        }
        catch {
            Write-Warning -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Failed to load previous state: $_"
            $previousState = $null
        }
    }

    #=================================================
    # Import built-in steps
    #=================================================
    Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Importing built-in steps..."
    $stepsPath = Join-Path -Path $MyInvocation.MyCommand.Module.ModuleBase -ChildPath 'Steps'

    if (Test-Path -Path $stepsPath) {
        $stepFiles = Get-ChildItem -Path $stepsPath -Filter '*.ps1' -ErrorAction Stop
        foreach ($file in $stepFiles) {
            Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Importing step: $($file.BaseName)"
            try {
                . $file.FullName
            }
            catch {
                Write-Warning -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Failed to import step '$($file.FullName)': $_"
            }
        }
    }
    else {
        Write-Warning -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Steps directory does not exist: $stepsPath"
    }

    #=================================================
    # Copy workflow and resources to OS partition (before first reboot)
    #=================================================
    $osDirectory = "C:\Windows\Temp\MCD"
    if (-not (Test-Path -Path $osDirectory)) {
        New-Item -Path $osDirectory -ItemType Directory -Force | Out-Null
        Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Created MCD directory: $osDirectory"
    }

    # Save workflow to OS partition
    $workflowSavePath = Join-Path -Path $osDirectory -ChildPath 'Workflow.json'
    $WorkflowObject | ConvertTo-Json -Depth 10 | Out-File -FilePath $workflowSavePath -Encoding utf8 -Force
    Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Saved workflow to: $workflowSavePath"

    #=================================================
    # Initialize state object
    #=================================================
    $currentState = @{
        workflowName        = $WorkflowObject.name
        workflowId          = $WorkflowObject.id
        startTime            = [datetime](Get-Date)
        endTime              = $null
        status              = 'InProgress'
        currentStepIndex    = 0
        totalSteps          = $WorkflowObject.steps.Count
        architecture         = $Architecture
        isWinPE              = $global:MCDWorkflowIsWinPE
        steps                = @()
    }

    #=================================================
    # Copy previous step states if resuming
    #=================================================
    if ($previousState -and $previousState.workflowId -eq $WorkflowObject.id) {
        foreach ($prevStep in $previousState.steps) {
            $currentState.steps += $prevStep
        }
    }

    # Initialize step states
    foreach ($step in $WorkflowObject.steps) {
        $stepState = $currentState.steps | Where-Object { $_.command -eq $step.command } | Select-Object -First 1

        if (-not $stepState) {
            $newStepState = @{
                name              = $step.name
                command           = $step.command
                description       = $step.description
                status            = 'Pending'
                attempts          = 0
                lastAttemptTime  = $null
                duration          = $null
                output            = $null
                error             = $null
            }
            $currentState.steps += $newStepState
        }
    }

    #=================================================
    # Save initial state
    #=================================================
    Save-MCDWorkflowState -State $currentState -Path $statePath

    #=================================================
    # Execute workflow steps sequentially
    #=================================================
    Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Executing workflow steps..."

    $stepNumber = 0

    foreach ($step in $WorkflowObject.steps) {
        $stepNumber++
        Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Step $stepNumber/$($WorkflowObject.steps.Count): $($step.name)"

        #=================================================
        # Set current step in global context
        #=================================================
        $global:MCDWorkflowContext.CurrentStep = $step
        $global:MCDWorkflowCurrentStepIndex = $stepNumber - 1

        #=================================================
        # Check rules
        #=================================================
        # Skip rule
        if ($step.rules.skip -eq $true) {
            Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Step skipped (skip rule)"
            $stepStatus = $currentState.steps | Where-Object { $_.command -eq $step.command } | Select-Object -First 1
            $stepStatus.status = 'Skipped'
            $stepStatus.attempts = 0
            Save-MCDWorkflowState -State $currentState -Path $statePath
            continue
        }

        # Architecture rule
        $currentArchitecture = $env:PROCESSOR_ARCHITECTURE
        if ($step.rules.architecture -notcontains $currentArchitecture) {
            Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Step skipped (architecture mismatch: $currentArchitecture not in $($step.rules.architecture -join ', '))"
            $stepStatus = $currentState.steps | Where-Object { $_.command -eq $step.command } | Select-Object -First 1
            $stepStatus.status = 'Skipped'
            $stepStatus.attempts = 0
            Save-MCDWorkflowState -State $currentState -Path $statePath
            continue
        }

        #=================================================
        # Validate step command exists
        #=================================================
        $stepFunctionPath = "function:\$($step.command)"
        if (-not (Test-Path -Path $stepFunctionPath)) {
            $errorMessage = "Step command not found: $($step.command)"
            Write-Error -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] $errorMessage"

            $currentState.status = 'Failed'
            Save-MCDWorkflowState -State $currentState -Path $statePath
            throw [System.Management.Automation.CommandNotFoundException]::new($errorMessage)
        }

        #=================================================
        # Update progress UI
        #=================================================
        $stepPercent = [math]::Round(($stepNumber / $WorkflowObject.steps.Count) * 100, 0)

        if ($Window) {
            Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Updating progress UI: Step $stepNumber/$($WorkflowObject.steps.Count) ($stepPercent%)"

            # Auto-detect progress type (default to indeterminate)
            $isIndeterminate = $true

            Update-MCDWinPEProgress -Window $Window -StepName $step.name -StepIndex ($stepNumber - 1) -StepCount $WorkflowObject.steps.Count -Percent $stepPercent -IsIndeterminate $isIndeterminate
        }

        #=================================================
        # Execute step with retry logic
        #=================================================
        $attemptNumber = 1
        $success = $false
        $stepStatus = $currentState.steps | Where-Object { $_.command -eq $step.command } | Select-Object -First 1

        $stepLogFile = "{0:D2}_{1}.log" -f $stepNumber, $step.command
        $logFilePath = Join-Path -Path $global:MCDWorkflowContext.LogsRoot -ChildPath $stepLogFile

        while (-not $success -and $attemptNumber -le $step.rules.retry.maxAttempts) {
            Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Attempt $attemptNumber/$($step.rules.retry.maxAttempts)"

            $stepStatus.status = 'InProgress'
            $stepStatus.attempts = $attemptNumber
            $stepStatus.lastAttemptTime = [datetime](Get-Date)
            Save-MCDWorkflowState -State $currentState -Path $statePath

            try {
                # Start transcript for this step
                Start-Transcript -Path $logFilePath -Force

                $stepStartTime = Get-Date

                # Execute step command with args and parameters
                & $step.command @($step.parameters) @step.args

                $stepEndTime = Get-Date

                $stepDuration = ($stepEndTime - $stepStartTime).TotalSeconds

                Stop-Transcript

                Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Step completed in $stepDuration seconds"

                $success = $true
                $stepStatus.status = 'Completed'
                $stepStatus.duration = $stepDuration
                $stepStatus.output = "Step completed successfully"
                $stepStatus.error = $null
            }
            catch {
                $errorRecord = $_
                $errorText = $errorRecord.Exception.Message
                Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Step failed: $errorText"

                if ($attemptNumber -lt $step.rules.retry.maxAttempts) {
                    Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Step failed (attempt $attemptNumber/$($step.rules.retry.maxAttempts)), retrying in $($step.rules.retry.retryDelay)s..."

                    Start-Sleep -Seconds $step.rules.retry.retryDelay
                    $attemptNumber++
                }
                else {
                    Write-Error -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Step failed after $($step.rules.retry.maxAttempts) attempt(s): $errorText"

                    $stepStatus.status = 'Failed'
                    $stepStatus.error = $errorText
                    Save-MCDWorkflowState -State $currentState -Path $statePath

                    if ($step.rules.continueOnError -eq $false) {
                        $currentState.status = 'Failed'
                        $currentState.endTime = [datetime](Get-Date)
                        Save-MCDWorkflowState -State $currentState -Path $statePath
                        throw $errorRecord
                    }
                    else {
                        Write-Warning -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Step failed but continuing (continueOnError: true)"
                    }
                }
            }

            Save-MCDWorkflowState -State $currentState -Path $statePath
        }

        #=================================================
        # Copy WinPE logs to OS partition (before first reboot)
        #=================================================
        if ($global:MCDWorkflowIsWinPE -and $step.name -like '*Copy*Logs*') {
            Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Copying WinPE logs to OS partition..."

            $winpeLogsPath = "X:\MCD\Logs\"
            $osLogsPath = "C:\Windows\Temp\MCD\Logs\"

            if (-not (Test-Path -Path $osLogsPath)) {
                New-Item -Path $osLogsPath -ItemType Directory -Force | Out-Null
            }

            if (Test-Path -Path $winpeLogsPath) {
                try {
                    $logFiles = Get-ChildItem -Path $winpeLogsPath -Filter '*.log' -ErrorAction Stop
                    foreach ($logFile in $logFiles) {
                        $destPath = Join-Path -Path $osLogsPath -ChildPath $logFile.Name
                        Copy-Item -Path $logFile.FullName -Destination $destPath -Force
                    }

                    Write-MCDLog -Level Information -Message "Copied $($logFiles.Count) log file(s) from $winpeLogsPath to $osLogsPath"
                    Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Copied $($logFiles.Count) log file(s) to OS partition"
                }
                catch {
                    Write-Warning -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Failed to copy WinPE logs: $_"
                }
            }
        }
    }

    #=================================================
    # Workflow completed successfully
    #=================================================
    $currentState.status = 'Completed'
    $currentState.endTime = [datetime](Get-Date)
    Save-MCDWorkflowState -State $currentState -Path $statePath

    Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Workflow completed successfully"
    Write-MCDLog -Level Information -Message "Workflow '$($WorkflowObject.name)' completed successfully"

    if ($Window) {
        Update-MCDWinPEProgress -Window $Window -StepName 'Completed' -StepIndex $WorkflowObject.steps.Count -StepCount $WorkflowObject.steps.Count -Percent 100 -IsIndeterminate $false
    }

    $Message = "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] End"
    Write-Verbose -Message $Message
    Write-Debug -Message $Message
    #=================================================
}

function Save-MCDWorkflowState {
    <#
    .SYNOPSIS
    Saves workflow state to JSON file.

    .DESCRIPTION
    Internal helper function to save workflow state to State.json file.

    .PARAMETER State
    Hashtable containing workflow state.

    .PARAMETER Path
    Path to save state file.
    #>
    param(
        [Parameter(Mandatory = $true)]
        $State,

        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )

    try {
        $State | ConvertTo-Json -Depth 10 | Out-File -FilePath $Path -Encoding utf8 -Force
    }
    catch {
        Write-Warning -Message "[$(Get-Date -Format s)] [Save-MCDWorkflowState] Failed to save state: $_"
    }
}
