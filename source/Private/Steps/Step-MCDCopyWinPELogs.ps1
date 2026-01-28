function Step-MCDCopyWinPELogs {
    <#
    .SYNOPSIS
    Copies WinPE logs to the OS partition before reboot.

    .DESCRIPTION
    Copies all log files from the WinPE RAM disk (X:\MCD\Logs\)
    to the OS partition (C:\Windows\Temp\MCD\Logs\). This step runs
    immediately before a reboot to preserve logs from the WinPE session. Ensures
    logs are available in the full Windows environment for troubleshooting.

    .PARAMETER OsPartitionDrive
    OS partition drive letter (default: "C:").

    .EXAMPLE
    Step-MCDCopyWinPELogs

    Copies WinPE logs to OS partition.

    .OUTPUTS
    System.Boolean
    Returns $true on success.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[A-Z]:')]
        [string]
        $OsPartitionDrive = "C:"
    )

    process {
        Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Copying WinPE logs to OS partition..."

        $winpeLogsPath = "X:\MCD\Logs\"
        $osLogsPath = "$OsPartitionDrive\Windows\Temp\MCD\Logs\"

        try {
            # Check if WinPE logs exist
            if (-not (Test-Path -Path $winpeLogsPath)) {
                Write-Warning -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] WinPE logs directory not found: $winpeLogsPath"
                return $true
            }

            # Create destination directory
            if (-not (Test-Path -Path $osLogsPath)) {
                Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Creating logs directory: $osLogsPath"
                New-Item -Path $osLogsPath -ItemType Directory -Force | Out-Null
            }

            # Copy all log files
            $logFiles = Get-ChildItem -Path $winpeLogsPath -Filter '*.log' -ErrorAction Stop

            foreach ($logFile in $logFiles) {
                $destPath = Join-Path -Path $osLogsPath -ChildPath $logFile.Name
                Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Copying: $($logFile.Name)"
                Copy-Item -Path $logFile.FullName -Destination $destPath -Force
            }

            Write-Verbose -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Copied $($logFiles.Count) log file(s) from $winpeLogsPath to $osLogsPath"
            Write-MCDLog -Level Information -Message "Copied $($logFiles.Count) log file(s) from WinPE to OS partition"

            return $true
        }
        catch {
            Write-Error -Message "[$(Get-Date -Format s)] [$($MyInvocation.MyCommand.Name)] Failed to copy WinPE logs: $_"
            Write-MCDLog -Level Error -Message "WinPE logs copy failed: $_"
            throw
        }
    }
}
