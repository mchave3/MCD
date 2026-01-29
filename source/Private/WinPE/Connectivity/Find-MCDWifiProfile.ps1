<#
.SYNOPSIS
Searches external volumes for a Wi-Fi XML profile.

.DESCRIPTION
Searches external filesystem volumes for Wi-Fi XML profile files using a set
of relative path patterns (e.g. MCD\Config\WiFi\*.xml). Returns the first
matching profile path.

.PARAMETER RelativePaths
One or more relative path patterns to search for on each external volume.

.EXAMPLE
Find-MCDWifiProfile -RelativePaths @('MCD\\Config\\WiFi\\WiFiProfile.xml','MCD\\Config\\WiFi\\*.xml')

Returns the first matching Wi-Fi XML profile path.
#>
function Find-MCDWifiProfile
{
    [CmdletBinding()]
    [OutputType([string])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $RelativePaths
    )

    foreach ($drive in (Get-MCDExternalVolume))
    {
        foreach ($pattern in $RelativePaths)
        {
            $candidate = Join-Path -Path $drive.Root -ChildPath $pattern

            $items = Get-ChildItem -Path $candidate -File -ErrorAction SilentlyContinue
            foreach ($item in $items)
            {
                return $item.FullName
            }
        }
    }

    return $null
}
