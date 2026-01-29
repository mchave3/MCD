<#
.SYNOPSIS
Updates the WinPE deployment UI with step and progress information.

.DESCRIPTION
Updates named WPF controls in the WinPE ProgressWindow.xaml (progress bar,
current step text, step counter, and percent text). This provides the
foundation for a TSBackground-like experience.

.PARAMETER Window
The main WPF Window instance that contains the named UI controls.

.PARAMETER StepName
Friendly name of the current step.

.PARAMETER StepIndex
1-based index of the current step.

.PARAMETER StepCount
Total number of steps in the overall deployment workflow.

.PARAMETER Percent
Percent complete for the overall workflow (0-100).

.PARAMETER Indeterminate
When set, displays an indeterminate progress bar.

.EXAMPLE
Update-MCDWinPEProgress -Window $window -StepName 'Downloading image' -StepIndex 2 -StepCount 5 -Percent 20

Updates the UI to reflect step 2 of 5 at 20%.
#>
function Update-MCDWinPEProgress
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([void])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Windows.Window]
        $Window,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $StepName,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 999)]
        [int]
        $StepIndex,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 999)]
        [int]
        $StepCount,

        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 100)]
        [int]
        $Percent,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $Indeterminate
    )

    if (-not $PSCmdlet.ShouldProcess('WinPE UI', 'Update progress'))
    {
        return
    }

    # UI update logic as a scriptblock for Dispatcher-safe handling
    $updateScript = {
        param($w, $name, $idx, $cnt, $pct, $indet)
        $stepCounter = $w.FindName('StepCounterText')
        if ($stepCounter)
        {
            $stepCounter.Text = "Step: $idx of $cnt"
        }

        $currentStep = $w.FindName('CurrentStepText')
        if ($currentStep)
        {
            $currentStep.Text = $name
        }

        $progress = $w.FindName('DeploymentProgressBar')
        if ($progress)
        {
            $progress.IsIndeterminate = [bool]$indet
            $progress.Value = $pct
        }

        $percentText = $w.FindName('ProgressPercentText')
        if ($percentText)
        {
            $percentText.Text = "$pct %"
        }
    }

    # Check if we need Dispatcher invocation (running on background thread)
    if ($Window.Dispatcher -and -not $Window.Dispatcher.CheckAccess())
    {
        # Create Action delegate that captures our values for Dispatcher.Invoke
        $updateAction = [System.Action]{
            & $updateScript $Window $StepName $StepIndex $StepCount $Percent $Indeterminate
        }
        $Window.Dispatcher.Invoke($updateAction)
    }
    else
    {
        # Direct execution on UI thread
        & $updateScript $Window $StepName $StepIndex $StepCount $Percent $Indeterminate
    }
}
