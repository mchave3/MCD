function Get-MCDExternalVolume
{
    <#
    .SYNOPSIS
    Returns mounted filesystem roots that are likely external media in WinPE.

    .DESCRIPTION
    Returns filesystem PSDrives except C: (if present) and X: (WinPE RAM drive).
    This is used to search for configuration payloads (e.g. Wi-Fi profiles) on
    USB or other attached volumes.

    .EXAMPLE
    Get-MCDExternalVolume

    Returns a list of PSDrive objects for external volumes.
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSDriveInfo[]])]
    param ()

    Get-PSDrive -PSProvider FileSystem |
        Where-Object {
            $_.Name -ne 'X' -and $_.Name -ne 'C'
        }
}
