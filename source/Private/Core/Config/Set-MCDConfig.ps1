<#
.SYNOPSIS
Writes an MCD configuration object to ProgramData.

.DESCRIPTION
Serializes a hashtable to JSON and writes it to
%ProgramData%\MCD\Profiles\<ProfileName>\<ConfigName>.json. This is used by
the Workspace flow to create/update a profile configuration.

.PARAMETER ConfigName
Name of the configuration file to write (Workspace or WinPE).

.PARAMETER Data
Hashtable that will be serialized to JSON and written to disk.

.PARAMETER ProfileName
Workspace profile name to store the configuration under ProgramData.

.EXAMPLE
Set-MCDConfig -ConfigName WinPE -ProfileName Default -Data @{ PreferPSGalleryUpdate = $true }

Writes the WinPE configuration for the Default profile.
#>
function Set-MCDConfig
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Workspace', 'WinPE')]
        [string]
        $ConfigName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [hashtable]
        $Data,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $ProfileName = 'Default'
    )

    $context = Get-MCDExecutionContext
    $profileRoot = Join-Path -Path $context.ProfilesRoot -ChildPath $ProfileName
    $configPath = Join-Path -Path $profileRoot -ChildPath "$ConfigName.json"

    if (-not (Test-Path -Path $profileRoot))
    {
        $null = New-Item -Path $profileRoot -ItemType Directory -Force
    }

    if ($PSCmdlet.ShouldProcess($configPath, 'Write configuration file'))
    {
        $Data | ConvertTo-Json -Depth 20 | Out-File -FilePath $configPath -Encoding utf8 -Width 2000 -Force
        Get-Item -Path $configPath
    }
}
