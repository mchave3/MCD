<#
.SYNOPSIS
Returns runtime context information for the MCD module.

.DESCRIPTION
Returns a context object describing the current runtime environment (WinPE vs
full Windows) as well as key MCD paths such as ProgramData roots and the XAML
folder shipped with the module.

.EXAMPLE
Get-MCDExecutionContext

Returns the current MCD execution context.
#>
function Get-MCDExecutionContext
{
    [CmdletBinding()]
    param ()

    $isWinPE = ($env:SystemDrive -eq 'X:')

    $moduleBase = $MyInvocation.MyCommand.Module.ModuleBase
    if (-not $moduleBase)
    {
        $moduleBase = (Get-Module -Name 'MCD' -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty ModuleBase)
    }
    if (-not $moduleBase)
    {
        $moduleBase = $PSScriptRoot
    }

    $programDataRoot = Join-Path -Path $env:ProgramData -ChildPath 'MCD'
    $winpeRoot = Join-Path -Path $env:SystemDrive -ChildPath 'MCD'

    $dataRoot = if ($isWinPE)
    {
        $winpeRoot
    }
    else
    {
        $programDataRoot
    }

    [PSCustomObject]@{
        IsWinPE          = $isWinPE
        DataRoot         = $dataRoot
        LogsRoot         = (Join-Path -Path $dataRoot -ChildPath 'Logs')
        ProfilesRoot     = (Join-Path -Path $programDataRoot -ChildPath 'Profiles')
        WorkspacesRoot   = (Join-Path -Path $programDataRoot -ChildPath 'Workspaces')
        ModuleBase       = $moduleBase
        XamlRoot         = (Join-Path -Path $moduleBase -ChildPath 'Xaml')
    }
}
