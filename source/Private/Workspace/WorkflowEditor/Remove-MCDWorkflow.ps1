<#
.SYNOPSIS
Removes a workflow file from the specified profile directory.

.DESCRIPTION
Deletes the workflow.json file from the specified profile directory. This is
a destructive operation that cannot be undone. The function supports ShouldProcess
for WhatIf and Confirm operations to prevent accidental deletion.

.PARAMETER ProfileName
The name of the profile directory containing the workflow to remove. The workflow
is expected at %ProgramData%\MCD\Profiles\<ProfileName>\workflow.json.

.EXAMPLE
Remove-MCDWorkflow -ProfileName 'OldProfile'

Removes the workflow.json file from the OldProfile directory.

.EXAMPLE
Remove-MCDWorkflow -ProfileName 'Custom' -WhatIf

Shows what would happen if the workflow were removed without actually deleting.
#>
function Remove-MCDWorkflow
{
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    [OutputType([void])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ProfileName
    )

    Write-MCDLog -Level Verbose -Message "Removing workflow from profile '$ProfileName'..."

    # Get profiles root from execution context
    $context = Get-MCDExecutionContext
    $profilesRoot = $context.ProfilesRoot
    if (-not $profilesRoot)
    {
        $profilesRoot = Join-Path -Path $env:ProgramData -ChildPath 'MCD\Profiles'
    }

    $profilePath = Join-Path -Path $profilesRoot -ChildPath $ProfileName
    $workflowPath = Join-Path -Path $profilePath -ChildPath 'workflow.json'

    # Check if workflow exists
    if (-not (Test-Path -Path $workflowPath))
    {
        throw "Workflow not found at: $workflowPath"
    }

    # Remove the file
    if ($PSCmdlet.ShouldProcess($workflowPath, 'Remove workflow'))
    {
        Remove-Item -Path $workflowPath -Force
        Write-MCDLog -Level Info -Message "Removed workflow from: $workflowPath"
    }
}
