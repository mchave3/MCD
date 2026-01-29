<#
.SYNOPSIS
Loads workflow definitions from module and USB profile directories.

.DESCRIPTION
Scans for workflow JSON files in the module's Workflows directory and optionally
from a USB profile directory. Returns parsed workflow objects sorted with the
default workflow first, then alphabetically by name. Invalid JSON files are
skipped with a warning. Missing step commands are warned about but do not cause
failures.

.PARAMETER ProfileName
Optional profile name to load a custom workflow from USB profile directory.
When specified, the function looks for workflow.json in the profile folder.

.PARAMETER Architecture
Optional architecture filter (amd64 or arm64). When specified, only workflows
supporting the given architecture are returned.

.EXAMPLE
Initialize-MCDWorkflowTasks

Loads all default workflows from the module's Workflows directory.

.EXAMPLE
Initialize-MCDWorkflowTasks -ProfileName 'CustomProfile'

Loads workflows from the module and the CustomProfile USB profile.

.EXAMPLE
Initialize-MCDWorkflowTasks -Architecture 'amd64'

Loads only workflows that support the amd64 architecture.
#>
function Initialize-MCDWorkflowTasks
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Tasks is the correct domain term for workflow tasks')]
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $ProfileName,

        [Parameter()]
        [ValidateSet('amd64', 'arm64')]
        [string]
        $Architecture
    )

    $context = Get-MCDExecutionContext
    $moduleBase = $context.ModuleBase
    $workflows = @()

    # Search order:
    # 1. <ModuleBase>\Private\Workflow\Data\*.json (canonical location)
    # 2. <ModuleBase>\Workflows\*.json (fallback for unit tests that mock ModuleBase)
    $workflowSearchPaths = @(
        (Join-Path -Path $moduleBase -ChildPath 'Private\Workflow\Data'),
        (Join-Path -Path $moduleBase -ChildPath 'Workflows')
    )

    foreach ($workflowsDir in $workflowSearchPaths)
    {
        Write-Verbose -Message "Looking for workflows in: $workflowsDir"

        if (Test-Path -Path $workflowsDir)
        {
            $workflowFiles = Get-ChildItem -Path $workflowsDir -Filter '*.json' -File -ErrorAction SilentlyContinue
            foreach ($file in $workflowFiles)
            {
                $workflow = Read-MCDWorkflowFile -Path $file.FullName
                if ($null -ne $workflow)
                {
                    $workflows += $workflow
                }
            }
        }
        else
        {
            Write-Verbose -Message "Workflows directory not found: $workflowsDir"
        }
    }

    # Load custom workflow from USB profile if ProfileName specified
    if ($ProfileName)
    {
        $profilesRoot = $context.ProfilesRoot
        if ($profilesRoot)
        {
            $profileWorkflowPath = Join-Path -Path $profilesRoot -ChildPath $ProfileName
            $profileWorkflowPath = Join-Path -Path $profileWorkflowPath -ChildPath 'workflow.json'
            Write-Verbose -Message "Looking for profile workflow: $profileWorkflowPath"

            if (Test-Path -Path $profileWorkflowPath)
            {
                $workflow = Read-MCDWorkflowFile -Path $profileWorkflowPath
                if ($null -ne $workflow)
                {
                    $workflows += $workflow
                }
            }
            else
            {
                Write-Verbose -Message "Profile workflow not found: $profileWorkflowPath"
            }
        }
    }

    # Validate step commands exist
    foreach ($workflow in $workflows)
    {
        if ($workflow.steps)
        {
            foreach ($step in $workflow.steps)
            {
                if ($step.command)
                {
                    $cmd = Get-Command -Name $step.command -ErrorAction SilentlyContinue
                    if (-not $cmd)
                    {
                        Write-Warning -Message "Step command '$($step.command)' not found for workflow '$($workflow.name)'."
                    }
                }
            }
        }
    }

    # Filter by architecture if specified
    if ($Architecture)
    {
        Write-Verbose -Message "Filtering workflows by architecture: $Architecture"
        $workflows = $workflows | Where-Object { $_.$Architecture -eq $true }
    }

    # Sort: default first (sorted by name), then non-default (sorted by name)
    $defaultWorkflows = $workflows | Where-Object { $_.default -eq $true } | Sort-Object -Property name
    $nonDefaultWorkflows = $workflows | Where-Object { $_.default -ne $true } | Sort-Object -Property name

    $sortedWorkflows = @()
    if ($defaultWorkflows)
    {
        $sortedWorkflows += $defaultWorkflows
    }
    if ($nonDefaultWorkflows)
    {
        $sortedWorkflows += $nonDefaultWorkflows
    }

    return $sortedWorkflows
}
