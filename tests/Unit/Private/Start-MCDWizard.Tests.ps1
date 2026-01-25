BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\.." | Convert-Path
    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }
    $script:moduleName = $ProjectName
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

Describe 'Start-MCDWizard' {
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

            Should -Invoke Import-MCDWinPEXaml -Times 0
        }
    }
}
