<#
.SYNOPSIS
Returns the list of available step commands for workflow creation.

.DESCRIPTION
Retrieves all available Step-MCD* functions from the module that can be used
in workflow definitions. Each step includes its name, command, and description
extracted from the function's help content. This palette is used by the
workflow editor UI to allow users to add steps to their workflows.

.PARAMETER IncludeCustom
If specified, also includes custom step functions from the profile's Steps
directory if available.

.EXAMPLE
Get-MCDWorkflowStepPalette

Returns all built-in Step-MCD* functions as step palette entries.

.EXAMPLE
Get-MCDWorkflowStepPalette -IncludeCustom

Returns both built-in and custom step functions from the current profile.
#>
function Get-MCDWorkflowStepPalette
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Palette contains multiple items')]
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param
    (
        [Parameter()]
        [switch]
        $IncludeCustom
    )

    Write-MCDLog -Level Verbose -Message 'Retrieving workflow step palette...'

    $palette = @()

    # Get all Step-MCD* functions from the module
    $stepCommands = Get-Command -Name 'Step-MCD*' -CommandType Function -ErrorAction SilentlyContinue

    foreach ($cmd in $stepCommands)
    {
        $help = Get-Help -Name $cmd.Name -ErrorAction SilentlyContinue

        $stepName = $cmd.Name -replace '^Step-MCD', ''
        # Add spaces before capital letters for display name
        $displayName = $stepName -creplace '([a-z])([A-Z])', '$1 $2'

        $description = if ($help.Synopsis -and $help.Synopsis -ne $cmd.Name)
        {
            $help.Synopsis
        }
        else
        {
            "Executes the $($cmd.Name) step."
        }

        $palette += [PSCustomObject]@{
            Name        = $displayName
            Command     = $cmd.Name
            Description = $description
            Category    = 'Built-in'
        }
    }

    Write-MCDLog -Level Verbose -Message "Found $($palette.Count) built-in step commands."

    # Sort alphabetically by name
    $palette = $palette | Sort-Object -Property Name

    return $palette
}
