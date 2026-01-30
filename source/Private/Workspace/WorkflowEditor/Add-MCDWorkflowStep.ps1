<#
.SYNOPSIS
Adds a new step to a workflow at the specified position.

.DESCRIPTION
Creates a new StepModel with the specified name and command, then adds it to
the workflow's steps list. By default, steps are added to the end of the
workflow. Use the Position parameter to insert at a specific index.

.PARAMETER Workflow
The WorkflowEditorModel object to add the step to.

.PARAMETER StepName
The display name for the step.

.PARAMETER Command
The PowerShell function name to execute for this step. Should be a Step-MCD*
function or custom step function.

.PARAMETER Description
Optional description of what this step does.

.PARAMETER Position
Optional index position where the step should be inserted. If not specified,
the step is added to the end of the workflow.

.EXAMPLE
Add-MCDWorkflowStep -Workflow $workflow -StepName 'Prepare Disk' -Command 'Step-MCDPrepareDisk'

Adds a new step to the end of the workflow.

.EXAMPLE
Add-MCDWorkflowStep -Workflow $workflow -StepName 'Validate' -Command 'Step-MCDValidateSelection' -Position 0

Inserts a new step at the beginning of the workflow.
#>
function Add-MCDWorkflowStep
{
    [CmdletBinding()]
    [OutputType([StepModel])]
    param
    (
        [Parameter(Mandatory = $true)]
        [WorkflowEditorModel]
        $Workflow,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $StepName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Command,

        [Parameter()]
        [string]
        $Description,

        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int]
        $Position = -1
    )

    Write-MCDLog -Level Verbose -Message "Adding step '$StepName' with command '$Command'..."

    # Create the new step
    $step = [StepModel]::new($StepName, $Command)

    if ($Description)
    {
        $step.Description = $Description
    }

    # Add to workflow
    if ($Position -ge 0 -and $Position -lt $Workflow.Steps.Count)
    {
        # Insert at specific position
        $Workflow.Steps.Insert($Position, $step)
        Write-MCDLog -Level Info -Message "Inserted step '$StepName' at position $Position."
    }
    else
    {
        # Add to end
        $Workflow.AddStep($step)
        Write-MCDLog -Level Info -Message "Added step '$StepName' to end of workflow."
    }

    return $step
}
