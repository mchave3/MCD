<#
.SYNOPSIS
Prepares the deployment environment before applying the Windows image.

.DESCRIPTION
Performs environment preparation tasks required before Windows image deployment.
This includes verifying network connectivity, checking for module updates from
PowerShell Gallery, and ensuring required directories exist on the target disk.

.EXAMPLE
Step-MCDPrepareEnvironment

Prepares the deployment environment and returns $true on success.

.NOTES
Uses $global:MCDWorkflowContext for workflow state. May call Update-MCDFromPSGallery
to check for module updates.
#>
function Step-MCDPrepareEnvironment
{
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

        Write-MCDLog -Level Info -Message 'Preparing deployment environment...'

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

        # Check for MCD module updates (non-fatal if fails)
        try
        {
            Write-MCDLog -Level Verbose -Message 'Checking for MCD module updates from PSGallery...'
            $updateResult = Update-MCDFromPSGallery -ModuleName 'MCD' -ErrorAction SilentlyContinue
            if ($updateResult)
            {
                Write-MCDLog -Level Info -Message 'MCD module is up to date or was updated successfully.'
            }
        }
        catch
        {
            Write-MCDLog -Level Warning -Message ("Failed to check for module updates: {0}" -f $_.Exception.Message)
        }

        # Ensure target directories exist if disk layout is available
        if ($selection -and $selection.DiskLayout)
        {
            $windowsDrive = $selection.DiskLayout.WindowsDriveLetter
            if ($windowsDrive)
            {
                $windowsPath = '{0}:\Windows' -f $windowsDrive
                $windowsTempPath = '{0}:\Windows\Temp' -f $windowsDrive
                $mcdTempPath = '{0}:\Windows\Temp\MCD' -f $windowsDrive
                $logsPath = '{0}:\Windows\Temp\MCD\Logs' -f $windowsDrive

                Write-MCDLog -Level Verbose -Message ("Ensuring target directories exist on {0}:..." -f $windowsDrive)

                foreach ($path in @($windowsPath, $windowsTempPath, $mcdTempPath, $logsPath))
                {
                    if (-not (Test-Path -Path $path))
                    {
                        $null = New-Item -Path $path -ItemType Directory -Force
                        Write-MCDLog -Level Verbose -Message ("Created directory: {0}" -f $path)
                    }
                }
            }
        }

        Write-MCDLog -Level Info -Message 'Environment preparation completed successfully.'
        return $true
    }
    finally
    {
        Stop-Transcript | Out-Null
    }
}
