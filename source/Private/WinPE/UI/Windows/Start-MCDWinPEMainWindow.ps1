<#
.SYNOPSIS
Shows the MCD WinPE main window.

.DESCRIPTION
Opens the provided WPF Window as a modal dialog. This function acts as a
small wrapper to make the UI entry point mockable during unit tests.

.PARAMETER Window
The WPF Window instance to display as a modal dialog.

.EXAMPLE
Start-MCDWinPEMainWindow -Window $window

Shows the provided WinPE window.
#>
function Start-MCDWinPEMainWindow
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([void])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Windows.Window]
        $Window
    )

    if ($PSCmdlet.ShouldProcess('WinPE UI', 'Show main window'))
    {
        $null = $Window.ShowDialog()
    }
}
