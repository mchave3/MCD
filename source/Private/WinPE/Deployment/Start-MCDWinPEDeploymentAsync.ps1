function Start-MCDWinPEDeploymentAsync
{
    <#
    .SYNOPSIS
    Starts the WinPE deployment runner in a background runspace.

    .DESCRIPTION
    Creates a dedicated STA runspace and runs Invoke-MCDWinPEDeployment while
    the WinPE UI message loop continues. The runner updates the UI through the
    WPF Dispatcher.

    .PARAMETER Window
    The WinPE main window that will receive progress updates via Dispatcher.

    .PARAMETER Selection
    The selection object returned by Start-MCDWizard.

    .EXAMPLE
    Start-MCDWinPEDeploymentAsync -Window $window -Selection $selection

    Starts the deployment runner in the background.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([void])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Windows.Window]
        $Window,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [pscustomobject]
        $Selection
    )

    if (-not $PSCmdlet.ShouldProcess('WinPE deployment', 'Start background deployment runner'))
    {
        return
    }

    $runspace = [RunspaceFactory]::CreateRunspace()
    $runspace.ApartmentState = 'STA'
    $runspace.ThreadOptions = 'ReuseThread'
    $runspace.Open()

    $ps = [PowerShell]::Create()
    $ps.Runspace = $runspace

    $scriptBlock = {
        param($w, $s)
        Import-Module -Name MCD -Force -ErrorAction Stop
        Invoke-MCDWinPEDeployment -Window $w -Selection $s
    }

    $null = $ps.AddScript($scriptBlock).AddArgument($Window).AddArgument($Selection)
    $null = $ps.BeginInvoke()
}
