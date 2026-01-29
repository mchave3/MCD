
BeforeAll {
    # Determine module path in output directory
    $projectRoot = "$PSScriptRoot\..\..\.." | Convert-Path
    $modulePath = Join-Path $projectRoot 'output\module\MCD\0.0.1\MCD.psd1'
    
    if (-not (Test-Path $modulePath)) {
        Throw "Module not found at $modulePath. Run build first."
    }
    
    Import-Module $modulePath -Force -ErrorAction Stop
    $script:moduleName = 'MCD'
}

Describe 'Start-MCDWizard' {
    Context 'Workflow Selection' {
        # Mock Xaml related functions locally for this Context if needed or globally
        # (Assuming InModuleScope handles internal function mocking)

        It 'Should select default workflow when no custom workflows are found' {
            InModuleScope $script:moduleName {
                # Mock Xaml and controls
                Mock Import-MCDWinPEXaml -MockWith {
                    $mockWindow = [PSCustomObject]@{
                        Tag = $null
                        DialogResult = $true
                    }
                    $mockWindow | Add-Member -MemberType ScriptMethod -Name Close -Value { }
                    $mockWindow | Add-Member -MemberType ScriptMethod -Name ShowDialog -Value { return $true }
                    
                    $mockWindow | Add-Member -MemberType ScriptMethod -Name FindName -Value {
                        param($Name)
                        if ($Name -eq 'WorkflowCombo') { return $null } # Hidden/Not found
                        if ($Name -eq 'WizardOkButton') { 
                            $btn = [PSCustomObject]@{ 
                                IsEnabled = $true
                            }
                            $btn | Add-Member -MemberType ScriptMethod -Name Add_Click -Value { param($Block) & $Block }
                            return $btn 
                        }
                        if ($Name -eq 'ComputerLanguageCombo') { 
                            $cmb = [PSCustomObject]@{ ItemsSource = @(); SelectedItem = "en-US"; SelectedIndex = 0 }
                            $cmb | Add-Member -MemberType ScriptMethod -Name Add_SelectionChanged -Value { param($b) }
                            return $cmb
                        }
                        if ($Name -eq 'OperatingSystemCombo') { 
                            $cmb = [PSCustomObject]@{ ItemsSource = @(); SelectedItem = [PSCustomObject]@{ DisplayName = "Windows 10"; AllowedLanguages = "en-US" }; SelectedIndex = 0 }
                            $cmb | Add-Member -MemberType ScriptMethod -Name Add_SelectionChanged -Value { param($b) }
                            return $cmb
                        }
                        if ($Name -eq 'DriverPackCombo') { 
                            $cmb = [PSCustomObject]@{ ItemsSource = @(); SelectedItem = "DriverPack1"; SelectedIndex = 0 }
                            $cmb | Add-Member -MemberType ScriptMethod -Name Add_SelectionChanged -Value { param($b) }
                            return $cmb
                        }
                        if ($Name -eq 'TargetDiskCombo') { 
                            $cmb = [PSCustomObject]@{ ItemsSource = @(); SelectedItem = [PSCustomObject]@{ DisplayName = "Disk 0" }; SelectedIndex = 0 }
                            $cmb | Add-Member -MemberType ScriptMethod -Name Add_SelectionChanged -Value { param($b) }
                            return $cmb
                        }
                        $other = [PSCustomObject]@{ Visibility = "Visible"; Text = ""; IsChecked = $false }
                        $other | Add-Member -MemberType ScriptMethod -Name Add_Click -Value { param($b) }
                        return $other
                    }
                    return $mockWindow
                }

                Mock Get-MCDTargetDiskCandidate -MockWith { @([PSCustomObject]@{ DisplayName = "Disk 0" }) }
                Mock Get-MCDExternalVolume -MockWith { @() }
                Mock Initialize-MCDWorkflowTasks -MockWith {
                    @([PSCustomObject]@{ Name = "Default Workflow"; default = $true })
                }

                $workspaceConfig = [PSCustomObject]@{
                    ProfileName = "TestProfile"
                    WizardOptions = [PSCustomObject]@{
                        ComputerLanguages = @("en-US")
                        OperatingSystems = @([PSCustomObject]@{ DisplayName = "Windows 10"; AllowedLanguages = "en-US" })
                        DriverPacks = @("DriverPack1")
                    }
                }
                $winpeConfig = [PSCustomObject]@{ DiskPolicy = $null }

                $result = Start-MCDWizard -WorkspaceConfig $workspaceConfig -WinPEConfig $winpeConfig -XamlRoot 'C:\MCD\Xaml'
                
                $result.Workflow | Should -Not -BeNullOrEmpty
                $result.Workflow.Name | Should -Be "Default Workflow"
            }
        }

            It 'Should populate workflow dropdown when custom workflows exist' {
            InModuleScope $script:moduleName {
                Mock Get-MCDTargetDiskCandidate -MockWith { @([PSCustomObject]@{ DisplayName = "Disk 0" }) }
                
                Mock Get-MCDExternalVolume -MockWith { 
                    @([PSCustomObject]@{ Root = "E:\" }) 
                }

                # Mock Join-Path - allow real Join-Path to work or simple mock
                # Join-Path is safe to run on strings
                
                # Mock Test-Path to simulate profile existence
                Mock Test-Path -MockWith { 
                    param($Path)
                    if ($Path -like "*MCD\Profiles*") { return $true }
                    return $false 
                }

                # Mock Get-ChildItem to find workflow files
                Mock Get-ChildItem -MockWith {
                    return @([PSCustomObject]@{ FullName = "E:\MCD\Profiles\Custom\workflow.json" })
                }
                
                # Mock Get-Content to read workflow content
                Mock Get-Content -MockWith {
                    return '{ "Name": "Custom Workflow", "default": false }'
                }

                # Mock built-in workflows
                Mock Initialize-MCDWorkflowTasks -MockWith {
                     @([PSCustomObject]@{ Name = "Default Workflow"; default = $true })
                }

                # Mock Xaml - Use script scope to ensure visibility inside ScriptMethod callbacks
                $script:mockWorkflowCombo = [PSCustomObject]@{ 
                    ItemsSource = $null
                    SelectedIndex = -1
                    Visibility = "Collapsed"
                    SelectedItem = $null
                }
                $script:mockWorkflowCombo | Add-Member -MemberType ScriptMethod -Name Add_SelectionChanged -Value { param($b) }
                
                Mock Import-MCDWinPEXaml -MockWith {
                    $mockWindow = [PSCustomObject]@{
                        Tag = $null
                        DialogResult = $true
                    }
                    $mockWindow | Add-Member -MemberType ScriptMethod -Name Close -Value { }
                    $mockWindow | Add-Member -MemberType ScriptMethod -Name ShowDialog -Value { return $true }
                    
                    $mockWindow | Add-Member -MemberType ScriptMethod -Name FindName -Value {
                        param($Name)
                        if ($Name -eq 'WorkflowCombo') { return $script:mockWorkflowCombo }
                        # ... other checks ...
                        if ($Name -eq 'WizardOkButton') { 
                            $btn = [PSCustomObject]@{ 
                                IsEnabled = $true
                            }
                            $btn | Add-Member -MemberType ScriptMethod -Name Add_Click -Value { param($Block) & $Block }
                            return $btn 
                        }
                        if ($Name -eq 'ComputerLanguageCombo') { 
                            $cmb = [PSCustomObject]@{ ItemsSource = @(); SelectedItem = "en-US"; SelectedIndex = 0 }
                            $cmb | Add-Member -MemberType ScriptMethod -Name Add_SelectionChanged -Value { param($b) }
                            return $cmb
                        }
                        if ($Name -eq 'OperatingSystemCombo') { 
                            $cmb = [PSCustomObject]@{ ItemsSource = @(); SelectedItem = [PSCustomObject]@{ DisplayName = "Windows 10"; AllowedLanguages = "en-US" }; SelectedIndex = 0 }
                            $cmb | Add-Member -MemberType ScriptMethod -Name Add_SelectionChanged -Value { param($b) }
                            return $cmb
                        }
                        if ($Name -eq 'DriverPackCombo') { 
                            $cmb = [PSCustomObject]@{ ItemsSource = @(); SelectedItem = "DriverPack1"; SelectedIndex = 0 }
                            $cmb | Add-Member -MemberType ScriptMethod -Name Add_SelectionChanged -Value { param($b) }
                            return $cmb
                        }
                        if ($Name -eq 'TargetDiskCombo') { 
                            $cmb = [PSCustomObject]@{ ItemsSource = @(); SelectedItem = [PSCustomObject]@{ DisplayName = "Disk 0" }; SelectedIndex = 0 }
                            $cmb | Add-Member -MemberType ScriptMethod -Name Add_SelectionChanged -Value { param($b) }
                            return $cmb
                        }
                        $other = [PSCustomObject]@{ Visibility = "Visible"; Text = ""; IsChecked = $false }
                        $other | Add-Member -MemberType ScriptMethod -Name Add_Click -Value { param($b) }
                        return $other
                    }
                    return $mockWindow
                }
                
                # Pre-select to simulate user interaction - MUST BE DONE AFTER MOCK DEFINITION BUT BEFORE CALL
                # Wait, the logic is: 
                # 1. Start-MCDWizard calls Import-MCDWinPEXaml
                # 2. Start-MCDWizard calls FindName -> gets our $mockWorkflowCombo
                # 3. Start-MCDWizard sets ItemsSource
                # 4. Start-MCDWizard checks SelectedItem. If null, sets default.
                
                # We want SelectedItem to NOT be null when step 4 happens.
                # So we must set it on $mockWorkflowCombo *before* step 4.
                # Since $mockWorkflowCombo is defined outside the mock scope, we can set it here.
                $customWf = [PSCustomObject]@{ Name = "Custom Workflow"; default = $false }
                $script:mockWorkflowCombo.SelectedItem = $customWf
                
                $workspaceConfig = [PSCustomObject]@{
                    ProfileName = "TestProfile"
                    WizardOptions = [PSCustomObject]@{
                        ComputerLanguages = @("en-US")
                        OperatingSystems = @([PSCustomObject]@{ DisplayName = "Windows 10"; AllowedLanguages = "en-US" })
                        DriverPacks = @("DriverPack1")
                    }
                }
                $winpeConfig = [PSCustomObject]@{ DiskPolicy = $null }

                $result = Start-MCDWizard -WorkspaceConfig $workspaceConfig -WinPEConfig $winpeConfig -XamlRoot 'C:\MCD\Xaml'

                $script:mockWorkflowCombo.ItemsSource | Should -Not -BeNullOrEmpty
                # Should have Default + Custom = 2
                $script:mockWorkflowCombo.ItemsSource.Count | Should -Be 2
                
                # Check that our simulated selection was returned
                $result.Workflow.Name | Should -Be "Custom Workflow"
            }
        }
    }
    
    It 'Returns defaults when NoUI is specified' {
        InModuleScope $script:moduleName {
            Mock Import-MCDWinPEXaml
            Mock Get-MCDTargetDiskCandidate -MockWith {
                @(
                    [PSCustomObject]@{ DiskNumber = 0; DisplayName = 'Disk 0' }
                )
            }

            $workspaceConfig = [PSCustomObject]@{
                ProfileName   = 'Default'
                WizardOptions = [PSCustomObject]@{
                    ComputerLanguages = @('fr-FR', 'en-US')
                    OperatingSystems  = @(
                        [PSCustomObject]@{ Id = 'Win11-23H2'; DisplayName = 'Windows 11 23H2' }
                    )
                    DriverPacks       = @('Auto', 'Dell')
                }
            }
            $winpeConfig = [PSCustomObject]@{}

            $selection = Start-MCDWizard -WorkspaceConfig $workspaceConfig -WinPEConfig $winpeConfig -XamlRoot 'X:\\Xaml' -NoUI

            $selection.ComputerLanguage | Should -Be 'fr-FR'
            $selection.OperatingSystem.Id | Should -Be 'Win11-23H2'
            $selection.DriverPack | Should -Be 'Auto'
            $selection.TargetDisk.DiskNumber | Should -Be 0
            
            # NOTE: Logic for default workflow in NoUI mode is not strictly required by current task description 
            # but good to have if we modify NoUI block. 
            # Task description says: "Existing OS/language/driver/disk selection behavior remains unchanged."
            # It doesn't explicitly mandate Workflow in NoUI, but for consistency it should likely be there.
            # We will focus on UI path first as per requirements.
            
            Should -Invoke Import-MCDWinPEXaml -Times 0
        }
    }
}
