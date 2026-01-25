function Write-MCDLog
{
    <#
    .SYNOPSIS
    Writes a log entry to the MCD log file.

    .DESCRIPTION
    Writes a timestamped log line to a UTF-8 log file. If no explicit log path is
    provided, the function uses the default MCD LogsRoot for the current runtime
    context (WinPE vs full Windows).

    .PARAMETER Level
    Log level used to tag the message in the log file and in verbose output.

    .PARAMETER Message
    The message text to write as a single log line.

    .PARAMETER Path
    Optional explicit path to the log file to write to.

    .EXAMPLE
    Write-MCDLog -Level Info -Message 'Workspace initialized.'

    Writes an informational log entry to the default MCD log file.
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Info', 'Warning', 'Error', 'Debug', 'Verbose')]
        [string]
        $Level,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Message,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path
    )

    $context = Get-MCDExecutionContext
    if (-not $Path)
    {
        $Path = Join-Path -Path $context.LogsRoot -ChildPath 'MCD.log'
    }

    $logDirectory = Split-Path -Path $Path -Parent
    if (-not (Test-Path -Path $logDirectory))
    {
        $null = New-Item -Path $logDirectory -ItemType Directory -Force
    }

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = '{0} [{1}] {2}' -f $timestamp, $Level.ToUpperInvariant(), $Message
    Add-Content -Path $Path -Value $line -Encoding UTF8

    switch ($Level)
    {
        'Error'
        {
            Write-Error -Message $Message -ErrorAction Continue
        }
        'Warning'
        {
            Write-Warning -Message $Message
        }
        'Verbose'
        {
            Write-Verbose -Message $Message
        }
        'Debug'
        {
            Write-Debug -Message $Message
        }
        default
        {
            Write-Verbose -Message $Message
        }
    }
}
