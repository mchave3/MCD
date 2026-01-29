<#
.SYNOPSIS
Saves workflow state to the state file.

.DESCRIPTION
Internal helper function to persist workflow state to the state JSON file.
Ensures the target directory exists and writes state as UTF-8 JSON.

.PARAMETER State
The state hashtable to save.

.PARAMETER StateDirectory
The directory containing the state file.

.EXAMPLE
Save-MCDWorkflowState -State $state -StateDirectory 'C:\Windows\Temp\MCD'

Saves the workflow state to C:\Windows\Temp\MCD\State.json.
#>
function Save-MCDWorkflowState
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [hashtable]
        $State,

        [Parameter(Mandatory = $true)]
        [string]
        $StateDirectory
    )

    $statePath = Join-Path -Path $StateDirectory -ChildPath 'State.json'

    # Ensure directory exists - only create if Test-Path returns false
    if (-not (Test-Path -Path $StateDirectory))
    {
        $null = New-Item -Path $StateDirectory -ItemType Directory -Force
    }

    # Convert to JSON and save
    $stateJson = $State | ConvertTo-Json -Depth 10
    Set-Content -Path $statePath -Value $stateJson -Encoding UTF8
}
