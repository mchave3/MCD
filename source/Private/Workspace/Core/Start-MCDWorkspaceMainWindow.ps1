<#
.SYNOPSIS
Shows the MCD Workspace main window.

.DESCRIPTION
Opens the provided WPF Window as a modal dialog. This function acts as a
small wrapper to make the UI entry point mockable during unit tests.
Logs the operation using Write-MCDLog.

.PARAMETER Window
The WPF Window instance to display as a modal dialog.

.EXAMPLE
Start-MCDWorkspaceMainWindow -Window $window

Shows the provided Workspace window.
#>
function Start-MCDWorkspaceMainWindow
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

    if ($PSCmdlet.ShouldProcess('Workspace UI', 'Show main window'))
    {
        Write-MCDLog -Message 'Showing Workspace main window' -Level 'Verbose'
        $null = $Window.ShowDialog()
        Write-MCDLog -Message 'Workspace main window closed' -Level 'Verbose'
    }
}
