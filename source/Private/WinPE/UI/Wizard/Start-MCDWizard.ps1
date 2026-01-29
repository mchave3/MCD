function Start-MCDWizard
{
    <#
    .SYNOPSIS
    Starts the MCD WinPE wizard to collect deployment selections.

    .DESCRIPTION
    Loads wizard option sets from the Workspace configuration for a profile and
    shows a WPF wizard window. The wizard returns a selection object containing
    the selected computer language, operating system id, and driver pack.

    .PARAMETER WorkspaceConfig
    Workspace configuration object (typically loaded from Get-MCDConfig).

    .PARAMETER XamlRoot
    Root directory containing the WinPE XAML files.

    .PARAMETER WinPEConfig
    WinPE configuration object (typically loaded from Get-MCDConfig).

    .PARAMETER NoUI
    Disables the wizard UI and returns default selections.

    .EXAMPLE
    Start-MCDWizard -WorkspaceConfig $workspaceConfig -WinPEConfig $winpeConfig -XamlRoot $context.XamlRoot

    Starts the wizard and returns a selection object.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'selectedWorkflow', Justification = 'Variable used for validation logic within scriptblock')]
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([pscustomobject])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [pscustomobject]
        $WorkspaceConfig,

        [Parameter()]
        [ValidateNotNull()]
        [pscustomobject]
        $WinPEConfig,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $XamlRoot,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $NoUI
    )

    $options = $WorkspaceConfig.WizardOptions
    if (-not $options)
    {
        $options = [PSCustomObject]@{}
    }

    $computerLanguages = @()
    if ($options.ComputerLanguages)
    {
        $computerLanguages = @($options.ComputerLanguages)
    }

    $operatingSystems = @()
    if ($options.OperatingSystems)
    {
        $operatingSystems = @($options.OperatingSystems)
    }

    $driverPacks = @()
    if ($options.DriverPacks)
    {
        $driverPacks = @($options.DriverPacks)
    }

    $diskExcludeBusTypes = @('USB')
    if ($WinPEConfig.DiskPolicy -and $WinPEConfig.DiskPolicy.ExcludeBusTypes)
    {
        $diskExcludeBusTypes = @($WinPEConfig.DiskPolicy.ExcludeBusTypes)
    }

    # Force array semantics for Windows PowerShell 5.1 where single PSCustomObject
    # results do not have a .Count property.
    $diskCandidates = @(Get-MCDTargetDiskCandidate -ExcludeBusTypes $diskExcludeBusTypes)

    # Workflow discovery
    $builtInWorkflows = Initialize-MCDWorkflowTasks
    $customWorkflows = @()

    $volumes = Get-MCDExternalVolume
    foreach ($vol in $volumes)
    {
        $profilePath = Join-Path -Path $vol.Root -ChildPath 'MCD\Profiles'
        if (Test-Path -Path $profilePath)
        {
            $customWorkflowFiles = Get-ChildItem -Path $profilePath -Filter 'workflow.json' -Recurse -File -ErrorAction SilentlyContinue
            foreach ($file in $customWorkflowFiles)
            {
                try
                {
                    $content = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
                    $wf = $content | ConvertFrom-Json -ErrorAction Stop
                    $customWorkflows += $wf
                }
                catch
                {
                    Write-Warning -Message "Skipping invalid workflow JSON at '$($file.FullName)': $($_.Exception.Message)"
                }
            }
        }
    }

    $allWorkflows = @()
    if ($builtInWorkflows) { $allWorkflows += $builtInWorkflows }
    if ($customWorkflows) { $allWorkflows += $customWorkflows }

    # Ensure default is first
    $defaultWorkflow = $allWorkflows | Where-Object { $_.default -eq $true } | Select-Object -First 1
    if (-not $defaultWorkflow)
    {
        $defaultWorkflow = $builtInWorkflows | Select-Object -First 1
    }

    if ($NoUI)
    {
        $os = $operatingSystems | Select-Object -First 1
        $disk = $diskCandidates | Select-Object -First 1
        return [PSCustomObject]@{
            Workflow         = $defaultWorkflow
            ComputerLanguage = ($computerLanguages | Select-Object -First 1)
            OperatingSystem  = $os
            DriverPack       = ($driverPacks | Select-Object -First 1)
            TargetDisk       = $disk
        }
    }

    $relativeXaml = 'WinPE\\WizardWindow.xaml'
    if ($WinPEConfig.XamlWizardWindowRelativePath)
    {
        $relativeXaml = [string]$WinPEConfig.XamlWizardWindowRelativePath
    }

    $xamlPath = Join-Path -Path $XamlRoot -ChildPath $relativeXaml
    $window = Import-MCDWinPEXaml -XamlPath $xamlPath

    $workflowCombo = $window.FindName('WorkflowCombo')
    $workflowLabel = $window.FindName('WorkflowLabel')
    $languageCombo = $window.FindName('ComputerLanguageCombo')
    $osCombo = $window.FindName('OperatingSystemCombo')
    $driverCombo = $window.FindName('DriverPackCombo')
    $diskCombo = $window.FindName('TargetDiskCombo')
    $confirmWipe = $window.FindName('ConfirmWipeCheckBox')
    $statusText = $window.FindName('WizardStatusText')
    $okButton = $window.FindName('WizardOkButton')
    $cancelButton = $window.FindName('WizardCancelButton')

    if ($workflowCombo)
    {
        if ($customWorkflows.Count -gt 0)
        {
            if ($workflowLabel) { $workflowLabel.Visibility = 'Visible' }
            $workflowCombo.Visibility = 'Visible'
            $workflowCombo.ItemsSource = $allWorkflows
            # Select default or first available if nothing is selected
            if (-not $workflowCombo.SelectedItem)
            {
                if ($defaultWorkflow)
                {
                     $workflowCombo.SelectedItem = $defaultWorkflow
                }
                elseif ($allWorkflows.Count -gt 0)
                {
                     $workflowCombo.SelectedIndex = 0
                }
            }
        }
        else
        {
            if ($workflowLabel) { $workflowLabel.Visibility = 'Collapsed' }
            $workflowCombo.Visibility = 'Collapsed'
        }
    }

    if ($languageCombo)
    {
        $languageCombo.ItemsSource = $computerLanguages
        if ($computerLanguages.Count -gt 0)
        {
            $languageCombo.SelectedIndex = 0
        }
    }

    if ($osCombo)
    {
        $osCombo.ItemsSource = $operatingSystems
        if ($operatingSystems.Count -gt 0)
        {
            $osCombo.SelectedIndex = 0
        }
    }

    if ($driverCombo)
    {
        $driverCombo.ItemsSource = $driverPacks
        if ($driverPacks.Count -gt 0)
        {
            $driverCombo.SelectedIndex = 0
        }
    }

    if ($diskCombo)
    {
        $diskCombo.ItemsSource = $diskCandidates
        if ($diskCandidates.Count -gt 0)
        {
            $diskCombo.SelectedIndex = 0
        }
    }

    $requireConfirm = $false
    if ($diskCandidates.Count -ge 2)
    {
        $requireConfirm = $true
    }
    if ($WinPEConfig.DiskPolicy -and ($null -ne $WinPEConfig.DiskPolicy.RequireConfirmIfMultiple))
    {
        if ($diskCandidates.Count -ge 2)
        {
            $requireConfirm = [bool]$WinPEConfig.DiskPolicy.RequireConfirmIfMultiple
        }
    }

    if ($confirmWipe)
    {
        $confirmWipe.Visibility = if ($requireConfirm) { 'Visible' } else { 'Collapsed' }
    }

    if ($statusText)
    {
        $statusText.Text = "Profile: $($WorkspaceConfig.ProfileName)"
    }

    $validate = {
        $selectedWorkflow = if ($workflowCombo -and $workflowCombo.Visibility -eq 'Visible') { $workflowCombo.SelectedItem } else { $defaultWorkflow }
        $selectedLanguage = if ($languageCombo) { $languageCombo.SelectedItem } else { $null }
        $selectedOS = if ($osCombo) { $osCombo.SelectedItem } else { $null }
        $selectedDisk = if ($diskCombo) { $diskCombo.SelectedItem } else { $null }
        $confirmed = if ($confirmWipe) { [bool]$confirmWipe.IsChecked } else { $true }

        $message = $null
        $canStart = $true

        if (-not $selectedOS)
        {
            $canStart = $false
            $message = 'Select an operating system.'
        }

        if ($canStart -and (-not $selectedDisk))
        {
            $canStart = $false
            $message = 'Select a target disk.'
        }

        if ($canStart -and $selectedLanguage -and $selectedOS.AllowedLanguages)
        {
            if ($selectedLanguage -notin @($selectedOS.AllowedLanguages))
            {
                $canStart = $false
                $message = "Language '$selectedLanguage' is not allowed for '$($selectedOS.DisplayName)'."
            }
        }

        if ($canStart -and $requireConfirm -and (-not $confirmed))
        {
            $canStart = $false
            $message = 'Confirmation is required before continuing.'
        }

        if ($okButton)
        {
            $okButton.IsEnabled = $canStart
        }
        if ($statusText)
        {
            $statusText.Text = if ($message) { $message } else { "Profile: $($WorkspaceConfig.ProfileName)" }
        }
    }

    if ($workflowCombo)
    {
        $workflowCombo.Add_SelectionChanged({ & $validate })
    }
    if ($languageCombo)
    {
        $languageCombo.Add_SelectionChanged({ & $validate })
    }
    if ($osCombo)
    {
        $osCombo.Add_SelectionChanged({ & $validate })
    }
    if ($diskCombo)
    {
        $diskCombo.Add_SelectionChanged({ & $validate })
    }
    if ($confirmWipe)
    {
        $confirmWipe.Add_Click({ & $validate })
    }
    & $validate

    if ($okButton)
    {
        $okButton.Add_Click({
                $selection = [PSCustomObject]@{
                    Workflow         = if ($workflowCombo -and $workflowCombo.Visibility -eq 'Visible') { $workflowCombo.SelectedItem } else { $defaultWorkflow }
                    ComputerLanguage = if ($languageCombo) { $languageCombo.SelectedItem } else { $null }
                    OperatingSystem  = if ($osCombo) { $osCombo.SelectedItem } else { $null }
                    DriverPack       = if ($driverCombo) { $driverCombo.SelectedItem } else { $null }
                    TargetDisk       = if ($diskCombo) { $diskCombo.SelectedItem } else { $null }
                }
                $window.Tag = $selection
                $window.DialogResult = $true
                $window.Close()
            })
    }

    if ($cancelButton)
    {
        $cancelButton.Add_Click({
                $window.DialogResult = $false
                $window.Close()
            })
    }

    if ($PSCmdlet.ShouldProcess($relativeXaml, 'Show wizard window'))
    {
        $null = $window.ShowDialog()
    }

    if (-not $window.DialogResult)
    {
        throw 'Wizard was cancelled.'
    }

    $window.Tag
}
