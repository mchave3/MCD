<#
.SYNOPSIS
Removes a step from a workflow at the specified index position.

.DESCRIPTION
Removes the step at the specified index position from the workflow's steps
list. Returns the removed step object for potential undo operations or
confirmation display.

.PARAMETER Workflow
The WorkflowEditorModel object to remove the step from.

.PARAMETER Index
The index position of the step to remove (0-based).

.EXAMPLE
Remove-MCDWorkflowStep -Workflow $workflow -Index 2

Removes the third step from the workflow.

.EXAMPLE
$removed = Remove-MCDWorkflowStep -Workflow $workflow -Index 0
Write-Host "Removed step: $($removed.Name)"

Removes the first step and displays its name.
#>
function Remove-MCDWorkflowStep
{
    [CmdletBinding()]
    [OutputType([StepModel])]
    param
    (
        [Parameter(Mandatory = $true)]
        [WorkflowEditorModel]
        $Workflow,

        [Parameter(Mandatory = $true)]
        [ValidateRange(0, [int]::MaxValue)]
        [int]
        $Index
    )

    Write-MCDLog -Level Verbose -Message "Removing step at index $Index..."

    # Validate index
    if ($Index -ge $Workflow.Steps.Count)
    {
        throw "Index $Index is out of range. Workflow has $($Workflow.Steps.Count) steps."
    }

    # Get the step before removing
    $step = $Workflow.Steps[$Index]
    $stepName = $step.Name

    # Remove the step
    $Workflow.RemoveStep($Index)

    Write-MCDLog -Level Info -Message "Removed step '$stepName' from position $Index."

    return $step
}
