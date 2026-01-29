<#
.SYNOPSIS
Initializes an MCD Workspace profile under ProgramData.

.DESCRIPTION
Creates or updates an MCD Workspace profile under %ProgramData%\MCD and
writes initial Workspace and WinPE configuration files for that profile.

.PARAMETER ProfileName
Name of the workspace profile to create or update under ProgramData.

.EXAMPLE
Start-MCDWorkspace -ProfileName Default

Creates (or updates) the Default workspace profile in ProgramData.
#>
function Start-MCDWorkspace
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $ProfileName = 'Default'
    )

    $null = Test-MCDPrerequisite -RequireFullOS

    Write-MCDLog -Level Info -Message "Initializing workspace profile '$ProfileName'."

    if ($PSCmdlet.ShouldProcess("Workspace profile '$ProfileName'", 'Initialize workspace profile'))
    {
        Initialize-MCDWorkspaceLayout -ProfileName $ProfileName
    }
}
