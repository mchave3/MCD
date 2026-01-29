<#
.SYNOPSIS
Reads and parses a single workflow JSON file.

.DESCRIPTION
Attempts to read and parse a workflow JSON file. Returns the parsed object on
success, or $null if the file contains invalid JSON (with a warning emitted).

.PARAMETER Path
Full path to the workflow JSON file.

.EXAMPLE
Read-MCDWorkflowFile -Path 'C:\Workflows\Default.json'

Reads and parses the Default.json workflow file.
#>
function Read-MCDWorkflowFile
{
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )

    try
    {
        $content = Get-Content -Path $Path -Raw -ErrorAction Stop
        $workflow = $content | ConvertFrom-Json -ErrorAction Stop
        Write-Verbose -Message "Successfully loaded workflow from: $Path"
        return $workflow
    }
    catch
    {
        Write-Warning -Message "Failed to parse workflow file '$Path': $($_.Exception.Message)"
        return $null
    }
}
