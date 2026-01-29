function Invoke-MCDWorkflow
{
    <#
    .SYNOPSIS
    Executes an MCD workflow by running steps sequentially.

    .DESCRIPTION
    Executes a workflow object by iterating through its steps array and running each
    step command. Handles skip rules, architecture filtering, environment checks
    (WinPE vs Full OS), retry logic, and progress UI updates. Persists workflow state
    to disk after each step completion.

    Steps are skipped based on rules:
    - rules.skip = true => skip
    - rules.architecture does not contain current architecture => skip
    - rules.runinwinpe = false and running in WinPE => skip
    - rules.runinfullos = false and running in Full OS => skip

    Retry behavior (when rules.retry.enabled = true):
    - Retries up to rules.retry.maxAttempts times on failure
    - Waits rules.retry.retryDelay seconds between attempts

    Error handling:
    - If rules.continueOnError = true, logs error and continues
    - If rules.continueOnError = false, throws and stops workflow

    .PARAMETER WorkflowObject
    The workflow object (hashtable or PSCustomObject) containing workflow metadata
    and steps array. Typically returned by Initialize-MCDWorkflowTasks.

    .PARAMETER Window
    Optional WPF Window for progress UI updates. When provided, calls
    Update-MCDWinPEProgress with step information.

    .EXAMPLE
    $workflow = Initialize-MCDWorkflowTasks | Select-Object -First 1
    Invoke-MCDWorkflow -WorkflowObject $workflow

    Executes the first available workflow without UI updates.

    .EXAMPLE
    Invoke-MCDWorkflow -WorkflowObject $workflow -Window $progressWindow

    Executes the workflow with progress UI updates.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '', Justification = 'OSDCloud pattern: workflow context shared via globals')]
    [CmdletBinding()]
    [OutputType([void])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [object]
        $WorkflowObject,

        [Parameter()]
        [object]
        $Window
    )

    # Get execution context
    $context = Get-MCDExecutionContext

    # Initialize global workflow variables (OSDCloud pattern)
    [System.Boolean]$global:MCDWorkflowIsWinPE = $context.IsWinPE
    [int]$global:MCDWorkflowCurrentStepIndex = 0
    [hashtable]$global:MCDWorkflowContext = @{
        Window      = $Window
        CurrentStep = $null
        LogsRoot    = $context.LogsRoot
        StatePath   = 'C:\Windows\Temp\MCD\State.json'
        StartTime   = [datetime](Get-Date)
    }

    # Get steps array
    $steps = $WorkflowObject.steps
    if (-not $steps -or $steps.Count -eq 0)
    {
        Write-MCDLog -Level Warning -Message 'Workflow has no steps to execute.'
        return
    }

    $stepCount = $steps.Count
    $stateDirectory = 'C:\Windows\Temp\MCD'

    # Initialize state tracking
    $workflowState = @{
        workflowName     = $WorkflowObject.name
        startTime        = $global:MCDWorkflowContext.StartTime.ToString('o')
        currentStepIndex = 0
        steps            = @()
    }

    # Process each step sequentially
    for ($i = 0; $i -lt $stepCount; $i++)
    {
        $step = $steps[$i]
        $stepIndex = $i + 1  # 1-based index for display
        $stepName = $step.name
        $stepCommand = $step.command
        $stepRules = $step.rules

        # Update global context
        $global:MCDWorkflowCurrentStepIndex = $stepIndex
        $global:MCDWorkflowContext.CurrentStep = $step

        Write-MCDLog -Level Info -Message "Processing step $stepIndex of $stepCount`: $stepName"

        # Initialize step state
        $stepState = @{
            name            = $stepName
            command         = $stepCommand
            status          = 'Pending'
            attempts        = 0
            lastAttemptTime = $null
            output          = $null
        }

        #region Skip Rule Checks

        # Check skip rule
        if ($stepRules.skip -eq $true)
        {
            Write-MCDLog -Level Info -Message "Skipping step '$stepName': skip rule is true"
            $stepState.status = 'Skipped'
            $stepState.output = 'Skipped by rule: skip = true'
            $workflowState.steps += $stepState
            $workflowState.currentStepIndex = $stepIndex
            Save-MCDWorkflowState -State $workflowState -StateDirectory $stateDirectory
            continue
        }

        # Check architecture rule
        $currentArch = $context.Architecture
        if (-not $currentArch)
        {
            # Default to amd64 if not specified (for testing)
            $currentArch = 'amd64'
        }
        if ($stepRules.architecture -and $stepRules.architecture.Count -gt 0)
        {
            if ($stepRules.architecture -notcontains $currentArch)
            {
                Write-MCDLog -Level Info -Message "Skipping step '$stepName': architecture mismatch (requires: $($stepRules.architecture -join ', '), current: $currentArch)"
                $stepState.status = 'Skipped'
                $stepState.output = "Skipped by rule: architecture mismatch"
                $workflowState.steps += $stepState
                $workflowState.currentStepIndex = $stepIndex
                Save-MCDWorkflowState -State $workflowState -StateDirectory $stateDirectory
                continue
            }
        }

        # Check environment rules (WinPE vs Full OS)
        $isWinPE = $context.IsWinPE
        if ($isWinPE)
        {
            # Running in WinPE - check runinwinpe rule
            if ($stepRules.runinwinpe -eq $false)
            {
                Write-MCDLog -Level Info -Message "Skipping step '$stepName': not configured to run in WinPE"
                $stepState.status = 'Skipped'
                $stepState.output = 'Skipped by rule: runinwinpe = false'
                $workflowState.steps += $stepState
                $workflowState.currentStepIndex = $stepIndex
                Save-MCDWorkflowState -State $workflowState -StateDirectory $stateDirectory
                continue
            }
        }
        else
        {
            # Running in Full OS - check runinfullos rule
            if ($stepRules.runinfullos -eq $false)
            {
                Write-MCDLog -Level Info -Message "Skipping step '$stepName': not configured to run in Full OS"
                $stepState.status = 'Skipped'
                $stepState.output = 'Skipped by rule: runinfullos = false'
                $workflowState.steps += $stepState
                $workflowState.currentStepIndex = $stepIndex
                Save-MCDWorkflowState -State $workflowState -StateDirectory $stateDirectory
                continue
            }
        }

        #endregion Skip Rule Checks

        #region Validate Command Exists

        $commandInfo = Get-Command -Name $stepCommand -ErrorAction SilentlyContinue
        if (-not $commandInfo)
        {
            $errorMessage = "Step command not found: $stepCommand"
            Write-MCDLog -Level Error -Message $errorMessage

            if ($stepRules.continueOnError -eq $true)
            {
                $stepState.status = 'Failed'
                $stepState.output = $errorMessage
                $workflowState.steps += $stepState
                $workflowState.currentStepIndex = $stepIndex
                Save-MCDWorkflowState -State $workflowState -StateDirectory $stateDirectory
                continue
            }
            else
            {
                throw $errorMessage
            }
        }

        #endregion Validate Command Exists

        #region Update Progress UI

        if ($null -ne $Window)
        {
            $percent = [math]::Floor((($stepIndex - 1) / $stepCount) * 100)
            Update-MCDWinPEProgress -Window $Window -StepName $stepName -StepIndex $stepIndex -StepCount $stepCount -Percent $percent
        }

        #endregion Update Progress UI

        #region Execute Step with Retry

        $retryEnabled = $stepRules.retry.enabled -eq $true
        $maxAttempts = if ($retryEnabled -and $stepRules.retry.maxAttempts) { $stepRules.retry.maxAttempts } else { 1 }
        $retryDelay = if ($retryEnabled -and $stepRules.retry.retryDelay) { $stepRules.retry.retryDelay } else { 0 }

        $attemptNumber = 1
        $success = $false
        $lastError = $null

        while (-not $success -and $attemptNumber -le $maxAttempts)
        {
            $stepState.attempts = $attemptNumber
            $stepState.lastAttemptTime = (Get-Date).ToString('o')

            try
            {
                Write-MCDLog -Level Info -Message "Executing step '$stepName' (attempt $attemptNumber of $maxAttempts)"

                # Build parameters and args for splatting
                $parameters = @{}
                if ($step.parameters -and $step.parameters -is [hashtable])
                {
                    $parameters = $step.parameters
                }
                elseif ($step.parameters -and $step.parameters -is [System.Collections.IDictionary])
                {
                    $parameters = @{} + $step.parameters
                }
                elseif ($step.parameters)
                {
                    # Convert PSCustomObject to hashtable if needed
                    $parameters = @{}
                    foreach ($prop in $step.parameters.PSObject.Properties)
                    {
                        $parameters[$prop.Name] = $prop.Value
                    }
                }

                $stepArgs = @()
                if ($step.args -and $step.args.Count -gt 0)
                {
                    $stepArgs = $step.args
                }

                # Execute the command
                if ($stepArgs.Count -gt 0 -and $parameters.Count -gt 0)
                {
                    & $stepCommand @parameters @stepArgs
                }
                elseif ($stepArgs.Count -gt 0)
                {
                    & $stepCommand @stepArgs
                }
                elseif ($parameters.Count -gt 0)
                {
                    & $stepCommand @parameters
                }
                else
                {
                    & $stepCommand
                }

                $success = $true
                $stepState.status = 'Completed'
                Write-MCDLog -Level Info -Message "Step '$stepName' completed successfully"
            }
            catch
            {
                $lastError = $_
                Write-MCDLog -Level Warning -Message "Step '$stepName' failed (attempt $attemptNumber of $maxAttempts): $($_.Exception.Message)"

                if ($attemptNumber -lt $maxAttempts)
                {
                    Write-MCDLog -Level Info -Message "Retrying step '$stepName' in $retryDelay seconds..."
                    Start-Sleep -Seconds $retryDelay
                }

                $attemptNumber++
            }
        }

        #endregion Execute Step with Retry

        #region Handle Step Failure

        if (-not $success)
        {
            $stepState.status = 'Failed'
            $stepState.output = $lastError.Exception.Message

            if ($stepRules.continueOnError -eq $true)
            {
                Write-MCDLog -Level Error -Message "Step '$stepName' failed after $maxAttempts attempt(s), continuing due to continueOnError=true"
            }
            else
            {
                $workflowState.steps += $stepState
                $workflowState.currentStepIndex = $stepIndex
                Save-MCDWorkflowState -State $workflowState -StateDirectory $stateDirectory

                # Re-throw the last error
                throw $lastError
            }
        }

        #endregion Handle Step Failure

        # Update state and persist
        $workflowState.steps += $stepState
        $workflowState.currentStepIndex = $stepIndex
        Save-MCDWorkflowState -State $workflowState -StateDirectory $stateDirectory
    }

    Write-MCDLog -Level Info -Message "Workflow '$($WorkflowObject.name)' completed successfully"
}
