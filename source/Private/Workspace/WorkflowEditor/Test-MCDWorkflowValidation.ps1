<#
.SYNOPSIS
Validates a workflow structure and optionally verifies command existence.

.DESCRIPTION
Performs validation on a WorkflowEditorModel to ensure it meets the required
schema specifications. Checks for required fields like name, valid architectures,
and proper step structure. Optionally validates that all step commands exist
as PowerShell functions.

.PARAMETER Workflow
The WorkflowEditorModel object to validate.

.PARAMETER ValidateCommands
If specified, also validates that each step's command exists as a PowerShell
function. This is useful for catching typos or missing custom step functions.

.EXAMPLE
$workflow = New-MCDWorkflow -Name 'Test'
Test-MCDWorkflowValidation -Workflow $workflow

Validates the workflow structure and returns a validation result.

.EXAMPLE
Test-MCDWorkflowValidation -Workflow $workflow -ValidateCommands

Validates the workflow including checking that all step commands exist.
#>
function Test-MCDWorkflowValidation
{
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param
    (
        [Parameter(Mandatory = $true)]
        [WorkflowEditorModel]
        $Workflow,

        [Parameter()]
        [switch]
        $ValidateCommands
    )

    Write-MCDLog -Level Verbose -Message "Validating workflow '$($Workflow.Name)'..."

    $errors = @()
    $isValid = $true

    # Validate required fields
    if ([string]::IsNullOrWhiteSpace($Workflow.Name))
    {
        $errors += 'Name is required.'
        $isValid = $false
    }

    if ([string]::IsNullOrWhiteSpace($Workflow.Id))
    {
        $errors += 'Id is required.'
        $isValid = $false
    }

    # Validate at least one architecture is enabled
    if (-not $Workflow.Amd64 -and -not $Workflow.Arm64)
    {
        $errors += 'At least one architecture (amd64 or arm64) must be enabled.'
        $isValid = $false
    }

    # Validate steps if any exist
    if ($Workflow.Steps -and $Workflow.Steps.Count -gt 0)
    {
        $stepIndex = 0
        foreach ($step in $Workflow.Steps)
        {
            # Validate step name
            if ([string]::IsNullOrWhiteSpace($step.Name))
            {
                $errors += "Step at index $stepIndex: Name is required."
                $isValid = $false
            }

            # Validate step command
            if ([string]::IsNullOrWhiteSpace($step.Command))
            {
                $errors += "Step '$($step.Name)' at index $stepIndex: Command is required."
                $isValid = $false
            }
            elseif ($ValidateCommands)
            {
                # Check if command exists
                $cmd = Get-Command -Name $step.Command -ErrorAction SilentlyContinue
                if (-not $cmd)
                {
                    $errors += "Step '$($step.Name)': Command '$($step.Command)' not found."
                    $isValid = $false
                }
            }

            # Validate step rules architecture
            if ($step.Rules -and $step.Rules.Architecture)
            {
                foreach ($arch in $step.Rules.Architecture)
                {
                    if ($arch -notin @('amd64', 'arm64'))
                    {
                        $errors += "Step '$($step.Name)': Invalid architecture '$arch'. Must be 'amd64' or 'arm64'."
                        $isValid = $false
                    }
                }
            }

            $stepIndex++
        }
    }

    $result = [PSCustomObject]@{
        IsValid = $isValid
        Errors  = $errors
    }

    if ($isValid)
    {
        Write-MCDLog -Level Verbose -Message 'Workflow validation passed.'
    }
    else
    {
        Write-MCDLog -Level Warning -Message "Workflow validation failed with $($errors.Count) error(s)."
    }

    return $result
}
