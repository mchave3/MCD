function Step-MCDCompleteDeployment
{
    <#
    .SYNOPSIS
    Completes the Windows deployment workflow and triggers reboot if needed.

    .DESCRIPTION
    Final step in the Windows deployment workflow. Performs cleanup tasks,
    logs workflow completion summary, and optionally triggers a reboot to boot
    into the newly deployed Windows installation.

    .EXAMPLE
    Step-MCDCompleteDeployment

    Completes the deployment and returns $true on success.

    .NOTES
    Uses $global:MCDWorkflowContext for workflow state. In WinPE, this step
    may trigger wpeutil reboot to boot into the deployed OS.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '', Justification = 'OSDCloud pattern: workflow context shared via globals')]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Determine logs root
    $logsRoot = $global:MCDWorkflowContext.LogsRoot
    if (-not $logsRoot)
    {
        if ($global:MCDWorkflowIsWinPE)
        {
            $logsRoot = 'X:\MCD\Logs'
        }
        else
        {
            $logsRoot = 'C:\Windows\Temp\MCD\Logs'
        }
    }

    # Ensure logs directory exists
    if (-not (Test-Path -Path $logsRoot))
    {
        $null = New-Item -Path $logsRoot -ItemType Directory -Force
    }

    # Build transcript path
    $stepIndex = $global:MCDWorkflowCurrentStepIndex
    $functionName = $MyInvocation.MyCommand.Name -replace '^Step-', ''
    $transcriptPath = Join-Path -Path $logsRoot -ChildPath ('{0:D2}_{1}.log' -f $stepIndex, $functionName)

    try
    {
        Start-Transcript -Path $transcriptPath -Force | Out-Null

        Write-MCDLog -Level Info -Message 'Completing Windows deployment...'

        # Calculate workflow duration
        $startTime = $global:MCDWorkflowContext.StartTime
        $endTime = Get-Date
        $duration = $null
        if ($startTime)
        {
            $duration = $endTime - $startTime
            Write-MCDLog -Level Info -Message ("Workflow duration: {0:hh\:mm\:ss}" -f $duration)
        }

        # Get selection for summary logging
        $selection = $null
        if ($global:MCDWorkflowContext.CurrentStep.parameters.Selection)
        {
            $selection = $global:MCDWorkflowContext.CurrentStep.parameters.Selection
        }
        elseif ($global:MCDWorkflowContext.Selection)
        {
            $selection = $global:MCDWorkflowContext.Selection
        }

        if ($selection -and $selection.OperatingSystem)
        {
            $osName = $selection.OperatingSystem.DisplayName
            Write-MCDLog -Level Info -Message ("Deployment completed: {0}" -f $osName)
        }

        # Log completion summary
        Write-MCDLog -Level Info -Message 'Deployment workflow completed successfully.'

        # In WinPE, we might trigger a reboot here
        # Currently disabled as this should be controlled by the workflow configuration
        if ($global:MCDWorkflowIsWinPE)
        {
            Write-MCDLog -Level Info -Message 'Running in WinPE. Reboot should be triggered by workflow configuration.'
            # Uncomment below to enable automatic reboot:
            # wpeutil reboot
        }

        return $true
    }
    finally
    {
        Stop-Transcript | Out-Null
    }
}
