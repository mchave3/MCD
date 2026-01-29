function Invoke-MCDWinPEDeployment
{
    <#
    .SYNOPSIS
    Runs the WinPE deployment workflow steps using the workflow executor.

    .DESCRIPTION
    Executes the deployment workflow via Invoke-MCDWorkflow while updating the WinPE
    UI. The workflow is retrieved from the Selection object (set by the wizard) or
    falls back to the default workflow loaded by Initialize-MCDWorkflowTasks.

    .PARAMETER Window
    The WinPE main window that will be updated during the deployment workflow.

    .PARAMETER Selection
    The selection object returned by Start-MCDWizard including OS, language, and Workflow.

    .EXAMPLE
    Invoke-MCDWinPEDeployment -Window $window -Selection $selection

    Runs the deployment workflow specified in the selection.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '', Justification = 'OSDCloud pattern: workflow context shared via globals')]
    [CmdletBinding()]
    [OutputType([void])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Windows.Window]
        $Window,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [pscustomobject]
        $Selection
    )

    $osName = $null
    $osId = $null
    if ($Selection.OperatingSystem)
    {
        $osName = $Selection.OperatingSystem.DisplayName
        $osId = $Selection.OperatingSystem.Id
    }
    Write-MCDLog -Level Info -Message ("Deployment selection: OS='{0}' ({1}), Language='{2}', DriverPack='{3}'" -f $osName, $osId, $Selection.ComputerLanguage, $Selection.DriverPack)

    # Determine the workflow to execute
    $workflow = $Selection.Workflow
    if (-not $workflow)
    {
        Write-MCDLog -Level Info -Message 'No workflow in selection; loading default workflow via Initialize-MCDWorkflowTasks'
        # Force array semantics for Windows PowerShell 5.1 where single PSCustomObject
        # results do not have a .Count property.
        $allWorkflows = @(Initialize-MCDWorkflowTasks)
        $workflow = $allWorkflows | Where-Object { $_.default -eq $true } | Select-Object -First 1
        if (-not $workflow -and $allWorkflows.Count -gt 0)
        {
            $workflow = $allWorkflows | Select-Object -First 1
        }
    }

    if (-not $workflow)
    {
        $errorMessage = 'No workflow available to execute'
        Write-MCDLog -Level Error -Message $errorMessage
        $Window.Dispatcher.Invoke([action]{
                Update-MCDWinPEProgress -Window $Window -StepName "Failed: $errorMessage" -StepIndex 1 -StepCount 1 -Percent 0
            })
        throw $errorMessage
    }

    Write-MCDLog -Level Info -Message "Executing workflow: $($workflow.name)"

    try
    {
        # Execute the workflow - Update-MCDWinPEProgress is now Dispatcher-safe
        Invoke-MCDWorkflow -WorkflowObject $workflow -Window $Window

        # Update UI to show completion
        $stepCount = if ($workflow.steps) { $workflow.steps.Count } else { 1 }
        $Window.Dispatcher.Invoke([action]{
                Update-MCDWinPEProgress -Window $Window -StepName 'Completed' -StepIndex $stepCount -StepCount $stepCount -Percent 100
            })
    }
    catch
    {
        $errorMessage = $_.Exception.Message
        Write-MCDLog -Level Error -Message "Workflow execution failed: $errorMessage"

        $stepIndex = if ($global:MCDWorkflowCurrentStepIndex) { $global:MCDWorkflowCurrentStepIndex } else { 1 }
        $stepCount = if ($workflow.steps) { $workflow.steps.Count } else { 1 }
        $Window.Dispatcher.Invoke([action]{
                Update-MCDWinPEProgress -Window $Window -StepName "Failed: $errorMessage" -StepIndex $stepIndex -StepCount $stepCount -Percent 0
            })

        throw
    }
}
