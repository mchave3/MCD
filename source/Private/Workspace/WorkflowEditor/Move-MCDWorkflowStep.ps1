<#
.SYNOPSIS
Moves a step within a workflow from one position to another.

.DESCRIPTION
Reorders steps within a workflow by moving a step from one index position to
another. This is used by the workflow editor UI to allow users to reorder
steps via drag-and-drop or up/down buttons.

.PARAMETER Workflow
The WorkflowEditorModel object containing the steps to reorder.

.PARAMETER FromIndex
The current index position of the step to move (0-based).

.PARAMETER ToIndex
The target index position where the step should be moved (0-based).

.EXAMPLE
Move-MCDWorkflowStep -Workflow $workflow -FromIndex 0 -ToIndex 2

Moves the first step to the third position in the workflow.

.EXAMPLE
Move-MCDWorkflowStep -Workflow $workflow -FromIndex 3 -ToIndex 0

Moves the fourth step to the first position in the workflow.
#>
function Move-MCDWorkflowStep
{
    [CmdletBinding()]
    [OutputType([void])]
    param
    (
        [Parameter(Mandatory = $true)]
        [WorkflowEditorModel]
        $Workflow,

        [Parameter(Mandatory = $true)]
        [ValidateRange(0, [int]::MaxValue)]
        [int]
        $FromIndex,

        [Parameter(Mandatory = $true)]
        [ValidateRange(0, [int]::MaxValue)]
        [int]
        $ToIndex
    )

    Write-MCDLog -Level Verbose -Message "Moving step from index $FromIndex to index $ToIndex..."

    # Validate indices
    if ($FromIndex -ge $Workflow.Steps.Count)
    {
        throw "FromIndex $FromIndex is out of range. Workflow has $($Workflow.Steps.Count) steps."
    }

    if ($ToIndex -ge $Workflow.Steps.Count)
    {
        throw "ToIndex $ToIndex is out of range. Workflow has $($Workflow.Steps.Count) steps."
    }

    # Use the built-in MoveStep method from WorkflowEditorModel
    $stepName = $Workflow.Steps[$FromIndex].Name
    $Workflow.MoveStep($FromIndex, $ToIndex)

    Write-MCDLog -Level Info -Message "Moved step '$stepName' from position $FromIndex to $ToIndex."
}
