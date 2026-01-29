<#
.SYNOPSIS
Copies WinPE logs to the target OS partition for preservation.

.DESCRIPTION
Copies log files from the WinPE logs directory (X:\MCD\Logs\) to the target
OS partition (default C:\Windows\Temp\MCD\Logs\) so they persist after reboot.
This step should run after disk preparation and before or after Windows image
deployment.

.PARAMETER OsPartitionDrive
The drive letter of the OS partition to copy logs to. Defaults to 'C'.

.EXAMPLE
Step-MCDCopyWinPELogs

Copies logs from X:\MCD\Logs\ to C:\Windows\Temp\MCD\Logs\.

.EXAMPLE
Step-MCDCopyWinPELogs -OsPartitionDrive 'W'

Copies logs from X:\MCD\Logs\ to W:\Windows\Temp\MCD\Logs\.

.NOTES
This step only runs in WinPE. In Full OS, it completes successfully without
action. Uses $global:MCDWorkflowContext for workflow state.
#>
function Step-MCDCopyWinPELogs
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Logs is the correct term for copying multiple log files')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '', Justification = 'OSDCloud pattern: workflow context shared via globals')]
    [CmdletBinding()]
    [OutputType([bool])]
    param
    (
        [Parameter()]
        [ValidatePattern('^[A-Z]$')]
        [string]
        $OsPartitionDrive = 'C'
    )

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

        Write-MCDLog -Level Info -Message 'Copying WinPE logs to target OS partition...'

        # Only copy logs when running in WinPE
        if (-not $global:MCDWorkflowIsWinPE)
        {
            Write-MCDLog -Level Verbose -Message 'Not running in WinPE; skipping log copy.'
            return $true
        }

        # Try to get OS partition drive from disk layout if available
        $selection = $null
        if ($global:MCDWorkflowContext.CurrentStep.parameters.Selection)
        {
            $selection = $global:MCDWorkflowContext.CurrentStep.parameters.Selection
        }
        elseif ($global:MCDWorkflowContext.Selection)
        {
            $selection = $global:MCDWorkflowContext.Selection
        }

        if ($selection -and $selection.DiskLayout -and $selection.DiskLayout.WindowsDriveLetter)
        {
            $OsPartitionDrive = $selection.DiskLayout.WindowsDriveLetter
            Write-MCDLog -Level Verbose -Message ("Using WindowsDriveLetter from DiskLayout: {0}" -f $OsPartitionDrive)
        }

        # Source and destination paths
        $sourcePath = 'X:\MCD\Logs'
        $destinationPath = '{0}:\Windows\Temp\MCD\Logs' -f $OsPartitionDrive

        # Check if source exists and has files
        if (-not (Test-Path -Path $sourcePath))
        {
            Write-MCDLog -Level Warning -Message ("WinPE logs source path does not exist: {0}" -f $sourcePath)
            return $true
        }

        $logFiles = Get-ChildItem -Path $sourcePath -Filter '*.log' -File -ErrorAction SilentlyContinue
        if (-not $logFiles -or $logFiles.Count -eq 0)
        {
            Write-MCDLog -Level Verbose -Message 'No log files found in WinPE logs directory.'
            return $true
        }

        # Ensure destination directory exists
        if (-not (Test-Path -Path $destinationPath))
        {
            $null = New-Item -Path $destinationPath -ItemType Directory -Force
            Write-MCDLog -Level Verbose -Message ("Created destination directory: {0}" -f $destinationPath)
        }

        # Copy log files
        $copiedCount = 0
        foreach ($logFile in $logFiles)
        {
            try
            {
                $destFile = Join-Path -Path $destinationPath -ChildPath $logFile.Name
                Copy-Item -Path $logFile.FullName -Destination $destFile -Force
                $copiedCount++
                Write-MCDLog -Level Verbose -Message ("Copied: {0}" -f $logFile.Name)
            }
            catch
            {
                Write-MCDLog -Level Warning -Message ("Failed to copy {0}: {1}" -f $logFile.Name, $_.Exception.Message)
            }
        }

        Write-MCDLog -Level Info -Message ("Copied {0} log file(s) to {1}" -f $copiedCount, $destinationPath)
        return $true
    }
    finally
    {
        Stop-Transcript | Out-Null
    }
}
