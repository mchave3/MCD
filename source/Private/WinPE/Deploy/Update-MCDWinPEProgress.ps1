function Update-MCDWinPEProgress
{
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

    $stepCounter = $Window.FindName('StepCounterText')
    if ($stepCounter)
    {
        $stepCounter.Text = "Step: $StepIndex of $StepCount"
    }

    $currentStep = $Window.FindName('CurrentStepText')
    if ($currentStep)
    {
        $currentStep.Text = $StepName
    }

    $progress = $Window.FindName('DeploymentProgressBar')
    if ($progress)
    {
        $progress.IsIndeterminate = [bool]$Indeterminate
        $progress.Value = $Percent
    }

    $percentText = $Window.FindName('ProgressPercentText')
    if ($percentText)
    {
        $percentText.Text = "${Percent} %"
    }
}
