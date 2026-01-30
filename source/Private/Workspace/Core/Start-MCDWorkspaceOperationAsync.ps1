<#
.SYNOPSIS
Starts a background operation in an STA runspace without blocking the UI thread.

.DESCRIPTION
Creates a dedicated STA runspace and executes the provided ScriptBlock asynchronously.
Returns a PSCustomObject containing the PowerShell instance, Runspace, and AsyncResult
so the caller can track progress or wait for completion. Logs start/stop events using
Write-MCDLog. This pattern keeps WPF UI responsive during long-running operations.

.PARAMETER ScriptBlock
The script block to execute in the background runspace.

.PARAMETER ArgumentList
Optional array of arguments to pass to the script block.

.EXAMPLE
$handle = Start-MCDWorkspaceOperationAsync -ScriptBlock { param($path) Get-ChildItem -Path $path } -ArgumentList 'C:\Windows'
# Later: $handle.PowerShell.EndInvoke($handle.AsyncResult)

Starts a background operation that lists files and returns a handle to track it.

.EXAMPLE
$handle = Start-MCDWorkspaceOperationAsync -ScriptBlock { Start-Sleep -Seconds 5; 'Done' }
while (-not $handle.AsyncResult.IsCompleted) { Start-Sleep -Milliseconds 100 }
$result = $handle.PowerShell.EndInvoke($handle.AsyncResult)

Starts a long-running operation and polls for completion.
#>
function Start-MCDWorkspaceOperationAsync
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([pscustomobject])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory = $false)]
        [object[]]
        $ArgumentList
    )

    if (-not $PSCmdlet.ShouldProcess('Background operation', 'Start async workspace operation'))
    {
        return
    }

    Write-MCDLog -Message 'Starting background workspace operation' -Level 'Verbose'

    $runspace = [RunspaceFactory]::CreateRunspace()
    $runspace.ApartmentState = 'STA'
    $runspace.ThreadOptions = 'ReuseThread'
    $runspace.Open()

    $ps = [PowerShell]::Create()
    $ps.Runspace = $runspace

    $null = $ps.AddScript($ScriptBlock)

    if ($ArgumentList)
    {
        foreach ($arg in $ArgumentList)
        {
            $null = $ps.AddArgument($arg)
        }
    }

    $asyncResult = $ps.BeginInvoke()

    Write-MCDLog -Message 'Background operation started successfully' -Level 'Verbose'

    return [pscustomobject]@{
        PowerShell  = $ps
        Runspace    = $runspace
        AsyncResult = $asyncResult
    }
}
