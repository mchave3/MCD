<#
.SYNOPSIS
Saves a workflow to the specified profile directory as workflow.json.

.DESCRIPTION
Validates the workflow and saves it to the profile directory as workflow.json.
The workflow is serialized to JSON format matching the MCD workflow schema.
Creates the profile directory if it does not exist. Supports ShouldProcess
for WhatIf and Confirm operations.

.PARAMETER Workflow
The WorkflowEditorModel object to save. Must be a valid workflow with at least
a name and one enabled architecture.

.PARAMETER ProfileName
The name of the profile directory where the workflow will be saved. The workflow
is saved to %ProgramData%\MCD\Profiles\<ProfileName>\workflow.json.

.EXAMPLE
$workflow = New-MCDWorkflow -Name 'Custom Deployment'
Save-MCDWorkflow -Workflow $workflow -ProfileName 'Default'

Saves the workflow to the Default profile directory.

.EXAMPLE
Save-MCDWorkflow -Workflow $workflow -ProfileName 'Custom' -WhatIf

Shows what would happen if the workflow were saved without actually saving.
#>
function Save-MCDWorkflow
{
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    [OutputType([void])]
    param
    (
        [Parameter(Mandatory = $true)]
        [WorkflowEditorModel]
        $Workflow,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ProfileName
    )

    Write-MCDLog -Level Verbose -Message "Saving workflow '$($Workflow.Name)' to profile '$ProfileName'..."

    # Validate workflow before saving
    try
    {
        $Workflow.Validate()
    }
    catch
    {
        throw "Workflow validation failed: $($_.Exception.Message)"
    }

    # Get profiles root from execution context
    $context = Get-MCDExecutionContext
    $profilesRoot = $context.ProfilesRoot
    if (-not $profilesRoot)
    {
        $profilesRoot = Join-Path -Path $env:ProgramData -ChildPath 'MCD\Profiles'
    }

    $profilePath = Join-Path -Path $profilesRoot -ChildPath $ProfileName
    $workflowPath = Join-Path -Path $profilePath -ChildPath 'workflow.json'

    # Create profile directory if it doesn't exist
    if (-not (Test-Path -Path $profilePath))
    {
        Write-MCDLog -Level Verbose -Message "Creating profile directory: $profilePath"
        $null = New-Item -Path $profilePath -ItemType Directory -Force
    }

    # Convert workflow to JSON
    $json = $Workflow.ToJson()

    # Save to file
    if ($PSCmdlet.ShouldProcess($workflowPath, 'Save workflow'))
    {
        Set-Content -Path $workflowPath -Value $json -Encoding UTF8 -Force
        Write-MCDLog -Level Info -Message "Saved workflow to: $workflowPath"
    }
}
