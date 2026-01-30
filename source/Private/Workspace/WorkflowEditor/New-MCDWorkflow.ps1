<#
.SYNOPSIS
Creates a new workflow with default settings for the MCD Workspace editor.

.DESCRIPTION
Creates a new WorkflowEditorModel instance with the specified name and optional
metadata. The workflow is initialized with default settings supporting both
amd64 and arm64 architectures, version 1.0.0, and an empty steps list. This
function is used by the Workspace UI to create new workflows before adding
steps and saving to disk.

.PARAMETER Name
The name of the workflow. This is a required parameter that identifies the
workflow in the editor and profile directory.

.PARAMETER Description
Optional description of what this workflow does. Should be descriptive enough
to help users understand the workflow's purpose (40+ characters recommended).

.PARAMETER Author
Optional author name or organization that created the workflow.

.PARAMETER Amd64
Whether this workflow supports x64 architecture. Defaults to true.

.PARAMETER Arm64
Whether this workflow supports ARM64 architecture. Defaults to true.

.EXAMPLE
New-MCDWorkflow -Name 'Custom Deployment'

Creates a new workflow named 'Custom Deployment' with default settings.

.EXAMPLE
New-MCDWorkflow -Name 'Enterprise Deployment' -Description 'Standard deployment for enterprise workstations.' -Author 'IT Team'

Creates a new workflow with full metadata.
#>
function New-MCDWorkflow
{
    [CmdletBinding()]
    [OutputType([WorkflowEditorModel])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Description,

        [Parameter()]
        [string]
        $Author,

        [Parameter()]
        [bool]
        $Amd64 = $true,

        [Parameter()]
        [bool]
        $Arm64 = $true
    )

    Write-MCDLog -Level Verbose -Message "Creating new workflow: $Name"

    $workflow = [WorkflowEditorModel]::new($Name)

    if ($Description)
    {
        $workflow.Description = $Description
    }

    if ($Author)
    {
        $workflow.Author = $Author
    }

    $workflow.Amd64 = $Amd64
    $workflow.Arm64 = $Arm64

    Write-MCDLog -Level Info -Message "Created workflow '$Name' with ID: $($workflow.Id)"

    return $workflow
}
