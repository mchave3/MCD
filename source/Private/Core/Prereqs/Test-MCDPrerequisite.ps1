<#
.SYNOPSIS
Validates runtime prerequisites for MCD operations.

.DESCRIPTION
Performs lightweight prerequisite checks for MCD operations, such as
verifying whether the current session is running in WinPE or full Windows
and optionally verifying administrator rights.

.PARAMETER RequireWinPE
Requires the current runtime to be WinPE (SystemDrive = X:).

.PARAMETER RequireFullOS
Requires the current runtime to be full Windows (not WinPE).

.PARAMETER RequireAdministrator
Requires the current process to run with administrator rights.

.EXAMPLE
Test-MCDPrerequisite -RequireFullOS -RequireAdministrator

Ensures the command is executed on full Windows with admin rights.
#>
function Test-MCDPrerequisite
{
    [CmdletBinding()]
    [OutputType([bool])]
    param
    (
        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $RequireWinPE,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $RequireFullOS,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $RequireAdministrator
    )

    $context = Get-MCDExecutionContext

    if ($RequireWinPE -and (-not $context.IsWinPE))
    {
        throw 'This operation must be executed from WinPE.'
    }

    if ($RequireFullOS -and $context.IsWinPE)
    {
        throw 'This operation must be executed on full Windows (not WinPE).'
    }

    if ($RequireAdministrator)
    {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object -TypeName Security.Principal.WindowsPrincipal -ArgumentList $identity
        $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        if (-not $isAdmin)
        {
            throw 'Administrator rights are required for this operation.'
        }
    }

    return $true
}
