function Step-MCDValidateSelection
{
    <#
    .SYNOPSIS
    Validates the deployment selection before proceeding with the workflow.

    .DESCRIPTION
    Validates that the global MCDWorkflowContext contains a valid selection object
    with the required properties for deployment. Checks that an operating system
    has been selected and that all required properties are present. Uses global
    workflow variables set by Invoke-MCDWorkflow.

    .EXAMPLE
    Step-MCDValidateSelection

    Validates the current workflow selection and returns $true on success.

    .NOTES
    This step reads from $global:MCDWorkflowContext.CurrentStep.parameters.Selection
    or falls back to the selection stored in the workflow context. Uses Start-Transcript
    for per-step logging.
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

        Write-MCDLog -Level Info -Message 'Validating deployment selection...'

        # Get selection from workflow context
        $selection = $null
        if ($global:MCDWorkflowContext.CurrentStep.parameters.Selection)
        {
            $selection = $global:MCDWorkflowContext.CurrentStep.parameters.Selection
        }
        elseif ($global:MCDWorkflowContext.Selection)
        {
            $selection = $global:MCDWorkflowContext.Selection
        }

        if (-not $selection)
        {
            throw 'No deployment selection found in workflow context.'
        }

        # Validate operating system selection
        if (-not $selection.OperatingSystem)
        {
            throw 'No operating system selected for deployment.'
        }

        $osName = $selection.OperatingSystem.DisplayName
        $osId = $selection.OperatingSystem.Id
        if (-not $osId)
        {
            throw 'Operating system selection is missing Id property.'
        }

        Write-MCDLog -Level Info -Message ("Validated selection: OS='{0}' ({1}), Language='{2}'" -f $osName, $osId, $selection.ComputerLanguage)

        # Validate target disk if provided
        if ($selection.TargetDisk)
        {
            $diskNumber = $selection.TargetDisk.DiskNumber
            if ($null -eq $diskNumber)
            {
                Write-MCDLog -Level Warning -Message 'TargetDisk provided but missing DiskNumber property.'
            }
            else
            {
                Write-MCDLog -Level Info -Message ("Target disk validated: DiskNumber={0}" -f $diskNumber)
            }
        }
        else
        {
            Write-MCDLog -Level Verbose -Message 'No target disk specified in selection.'
        }

        Write-MCDLog -Level Info -Message 'Selection validation completed successfully.'
        return $true
    }
    finally
    {
        Stop-Transcript | Out-Null
    }
}
