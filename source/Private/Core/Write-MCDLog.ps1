function Write-MCDLog
{
    <#
      .SYNOPSIS
      Writes a log message to the MCD log file and verbose output.

      .DESCRIPTION
      This function provides unified logging for the MCD module. It writes messages
      to both the verbose output stream and optionally to a log file. The function
      is designed to work in both full Windows and WinPE environments.

      .EXAMPLE
      Write-MCDLog -Message 'Starting workspace initialization'

      Writes an Info level message to the log.

      .EXAMPLE
      Write-MCDLog -Message 'Failed to connect' -Level Error -Path 'C:\Logs\mcd.log'

      Writes an Error level message to a specific log file.

      .PARAMETER Message
      The message to log. This parameter is mandatory and accepts pipeline input.

      .PARAMETER Level
      The severity level of the log message. Valid values are Trace, Debug, Info, Warn, Error.
      Defaults to Info.

      .PARAMETER Path
      The path to the log file. If not specified, logging to file is skipped unless
      a default log path is configured.

      .PARAMETER NoFile
      If specified, skips writing to the log file and only outputs to verbose stream.
      Useful for testing or when file system access is not available.
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]
        $Message,

        [Parameter()]
        [ValidateSet('Trace', 'Debug', 'Info', 'Warn', 'Error')]
        [string]
        $Level = 'Info',

        [Parameter()]
        [string]
        $Path,

        [Parameter()]
        [switch]
        $NoFile
    )

    process
    {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $logEntry = "[$timestamp] [$Level] $Message"

        # Always write to verbose output
        Write-Verbose -Message $logEntry

        # Write to file if path is specified and NoFile is not set
        if (-not $NoFile -and -not [string]::IsNullOrEmpty($Path))
        {
            try
            {
                # Ensure log directory exists
                $logDir = Split-Path -Path $Path -Parent
                if (-not [string]::IsNullOrEmpty($logDir) -and -not (Test-Path -Path $logDir))
                {
                    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
                }

                # Append to log file
                Add-Content -Path $Path -Value $logEntry -Encoding UTF8 -ErrorAction Stop
            }
            catch
            {
                # If we can't write to file, write a warning but don't fail
                Write-Warning -Message "Failed to write to log file '$Path': $($_.Exception.Message)"
            }
        }
    }
}
