function Invoke-MCDWinPEDeployment
{
    <#
    .SYNOPSIS
    Runs the WinPE deployment workflow steps (non-destructive baseline).

    .DESCRIPTION
    Executes a sequence of deployment steps while updating the WinPE UI. This is
    a safe baseline runner that performs only non-destructive actions (logging
    and validation). Disk partitioning and applying images will be added once
    the target disk selection policy is defined.

    .PARAMETER Window
    The WinPE main window that will be updated during the deployment workflow.

    .PARAMETER Selection
    The selection object returned by Start-MCDWizard including OS and language.

    .EXAMPLE
    Invoke-MCDWinPEDeployment -Window $window -Selection $selection

    Runs the baseline deployment runner.
    #>
    [CmdletBinding()]
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

    $osName = $null
    $osId = $null
    if ($Selection.OperatingSystem)
    {
        $osName = $Selection.OperatingSystem.DisplayName
        $osId = $Selection.OperatingSystem.Id
    }
    Write-MCDLog -Level Info -Message ("Deployment selection: OS='{0}' ({1}), Language='{2}', DriverPack='{3}'" -f $osName, $osId, $Selection.ComputerLanguage, $Selection.DriverPack)

    $steps = @(
        @{ Name = 'Validating selection'; Action = { return $true } },
        @{ Name = 'Preparing disk'; Action = {
                if (-not $Selection.TargetDisk)
                {
                    Write-MCDLog -Level Verbose -Message 'No TargetDisk provided; skipping disk preparation.'
                    return $true
                }

                $diskNumber = $Selection.TargetDisk.DiskNumber
                if ($null -eq $diskNumber)
                {
                    Write-MCDLog -Level Verbose -Message 'TargetDisk does not include DiskNumber; skipping disk preparation.'
                    return $true
                }

                $diskPolicy = $null
                if ($Selection.WinPEConfig -and $Selection.WinPEConfig.DiskPolicy)
                {
                    $diskPolicy = $Selection.WinPEConfig.DiskPolicy
                }
                if (-not $diskPolicy)
                {
                    $diskPolicy = [pscustomobject]@{ AllowDestructiveActions = $false }
                }

                $layout = Initialize-MCDTargetDisk -DiskNumber $diskNumber -DiskPolicy $diskPolicy
                $Selection | Add-Member -NotePropertyName DiskLayout -NotePropertyValue $layout -Force
                return $true
            } },
        @{ Name = 'Preparing deployment environment'; Action = { return $true } },
        @{ Name = 'Ready to deploy (imaging steps pending)'; Action = { return $true } }
    )

    $stepCount = $steps.Count
    for ($i = 0; $i -lt $stepCount; $i++)
    {
        $step = $steps[$i]
        $stepIndex = $i + 1
        $percent = [math]::Floor(($stepIndex - 1) / [double]$stepCount * 100)

        $Window.Dispatcher.Invoke([action]{
                Update-MCDWinPEProgress -Window $Window -StepName $step.Name -StepIndex $stepIndex -StepCount $stepCount -Percent $percent -Indeterminate
            })
        Write-MCDLog -Level Info -Message "Deploy step [$stepIndex/$stepCount]: $($step.Name)"

        try
        {
            & $step.Action | Out-Null
        }
        catch
        {
            $errorMessage = $_.Exception.Message
            Write-MCDLog -Level Error -Message "Deploy step failed: $errorMessage"

            $Window.Dispatcher.Invoke([action]{
                    Update-MCDWinPEProgress -Window $Window -StepName "Failed: $errorMessage" -StepIndex $stepIndex -StepCount $stepCount -Percent $percent
                })

            throw
        }
        Start-Sleep -Milliseconds 200
    }

    $Window.Dispatcher.Invoke([action]{
            Update-MCDWinPEProgress -Window $Window -StepName 'Completed (baseline)' -StepIndex $stepCount -StepCount $stepCount -Percent 100
        })
}
