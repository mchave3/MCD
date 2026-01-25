function Get-MCDConfig
{
    <#
    .SYNOPSIS
    Loads an MCD configuration object from ProgramData.

    .DESCRIPTION
    Loads a JSON configuration file for a specific profile name from
    %ProgramData%\MCD\Profiles\<ProfileName> and returns it as a PowerShell
    object. This is used by both Workspace and WinPE flows.

    .PARAMETER ConfigName
    Name of the configuration file to load (Workspace or WinPE).

    .PARAMETER ProfileName
    Workspace profile name to load the configuration from under ProgramData.

    .EXAMPLE
    Get-MCDConfig -ConfigName Workspace -ProfileName Default

    Loads the Workspace configuration for the Default profile.
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Workspace', 'WinPE')]
        [string]
        $ConfigName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $ProfileName = 'Default'
    )

    $context = Get-MCDExecutionContext
    $profileRoot = Join-Path -Path $context.ProfilesRoot -ChildPath $ProfileName
    $configPath = Join-Path -Path $profileRoot -ChildPath "$ConfigName.json"

    if (-not (Test-Path -Path $configPath))
    {
        return $null
    }

    Get-Content -Path $configPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
}
