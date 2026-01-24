# Suppressing this rule because Script Analyzer does not understand Pester's syntax.
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Suppressing this rule because Script Analyzer does not understand Pester syntax.')]
param ()

BeforeAll {
    $script:dscModuleName = 'MCD'

    Import-Module -Name $script:dscModuleName
}

AfterAll {
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}

Describe 'Get-MCDConfig' {
    Context 'When loading configuration from file' {
        It 'Should load configuration from valid JSON file' {
            InModuleScope -ModuleName $dscModuleName {
                # Create a test config file
                $configPath = Join-Path -Path $TestDrive -ChildPath 'config.json'
                $configData = @{
                    Version       = '2.0'
                    WorkspacePath = 'D:\TestMCD'
                    Defaults      = @{}
                    Logging       = @{ Level = 'Debug'; FileName = 'test.log' }
                } | ConvertTo-Json
                Set-Content -Path $configPath -Value $configData

                $result = Get-MCDConfig -Path $configPath

                $result | Should -Not -BeNullOrEmpty
                $result.Version | Should -Be '2.0'
                $result.WorkspacePath | Should -Be 'D:\TestMCD'
            }
        }

        It 'Should throw when file does not exist' {
            InModuleScope -ModuleName $dscModuleName {
                $fakePath = Join-Path -Path $TestDrive -ChildPath 'nonexistent.json'

                { Get-MCDConfig -Path $fakePath } | Should -Throw
            }
        }

        It 'Should return MCDConfig type' {
            InModuleScope -ModuleName $dscModuleName {
                $configPath = Join-Path -Path $TestDrive -ChildPath 'typetest.json'
                $config = [MCDConfig]::new()
                $config.Save($configPath)

                $result = Get-MCDConfig -Path $configPath

                $result.GetType().Name | Should -Be 'MCDConfig'
            }
        }
    }

    Context 'When CreateIfMissing is specified' {
        It 'Should create new config when file does not exist' {
            InModuleScope -ModuleName $dscModuleName {
                $configPath = Join-Path -Path $TestDrive -ChildPath 'newconfig.json'

                $result = Get-MCDConfig -Path $configPath -CreateIfMissing

                $result | Should -Not -BeNullOrEmpty
                $result.Version | Should -Be '1.0'
            }
        }

        It 'Should save the new config file' {
            InModuleScope -ModuleName $dscModuleName {
                $configPath = Join-Path -Path $TestDrive -ChildPath 'savedconfig.json'

                Get-MCDConfig -Path $configPath -CreateIfMissing

                Test-Path -Path $configPath | Should -BeTrue
            }
        }

        It 'Should load existing config when file exists' {
            InModuleScope -ModuleName $dscModuleName {
                $configPath = Join-Path -Path $TestDrive -ChildPath 'existing.json'
                $config = [MCDConfig]::new()
                $config.Version = '3.0'
                $config.Save($configPath)

                $result = Get-MCDConfig -Path $configPath -CreateIfMissing

                $result.Version | Should -Be '3.0'
            }
        }
    }
}
