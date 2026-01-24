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

Describe 'Set-MCDConfig' {
    Context 'When saving configuration' {
        It 'Should save configuration to file' {
            InModuleScope -ModuleName $dscModuleName {
                $configPath = Join-Path -Path $TestDrive -ChildPath 'save.json'
                $config = [MCDConfig]::new()
                $config.Version = '5.0'

                Set-MCDConfig -Config $config -Path $configPath

                Test-Path -Path $configPath | Should -BeTrue
            }
        }

        It 'Should save correct JSON content' {
            InModuleScope -ModuleName $dscModuleName {
                $configPath = Join-Path -Path $TestDrive -ChildPath 'content.json'
                $config = [MCDConfig]::new()
                $config.Version = '6.0'
                $config.WorkspacePath = 'E:\CustomPath'

                Set-MCDConfig -Config $config -Path $configPath

                $content = Get-Content -Path $configPath -Raw | ConvertFrom-Json
                $content.Version | Should -Be '6.0'
                $content.WorkspacePath | Should -Be 'E:\CustomPath'
            }
        }

        It 'Should create parent directory if needed' {
            InModuleScope -ModuleName $dscModuleName {
                $configPath = Join-Path -Path $TestDrive -ChildPath 'nested\dir\config.json'
                $config = [MCDConfig]::new()

                Set-MCDConfig -Config $config -Path $configPath

                Test-Path -Path $configPath | Should -BeTrue
            }
        }

        It 'Should accept config from pipeline' {
            InModuleScope -ModuleName $dscModuleName {
                $configPath = Join-Path -Path $TestDrive -ChildPath 'pipeline.json'
                $config = [MCDConfig]::new()

                { $config | Set-MCDConfig -Path $configPath } | Should -Not -Throw

                Test-Path -Path $configPath | Should -BeTrue
            }
        }
    }

    Context 'When WhatIf is specified' {
        It 'Should support WhatIf parameter' {
            InModuleScope -ModuleName $dscModuleName {
                (Get-Command -Name 'Set-MCDConfig').Parameters.ContainsKey('WhatIf') | Should -BeTrue
            }
        }

        It 'Should not write file when WhatIf is used' {
            InModuleScope -ModuleName $dscModuleName {
                $configPath = Join-Path -Path $TestDrive -ChildPath 'whatif.json'
                $config = [MCDConfig]::new()

                Set-MCDConfig -Config $config -Path $configPath -WhatIf

                Test-Path -Path $configPath | Should -BeFalse
            }
        }
    }
}
