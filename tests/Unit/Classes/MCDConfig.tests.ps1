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

Describe 'MCDConfig' {
    Context 'Type creation' {
        It 'Has created a type named MCDConfig' {
            InModuleScope -ModuleName $dscModuleName {
                'MCDConfig' -as [Type] | Should -BeOfType [Type]
            }
        }
    }

    Context 'Constructors' {
        It 'Has a default constructor' {
            InModuleScope -ModuleName $dscModuleName {
                $instance = [MCDConfig]::new()
                $instance | Should -Not -BeNullOrEmpty
                $instance.GetType().Name | Should -Be 'MCDConfig'
            }
        }

        It 'Can be constructed with a custom workspace path' {
            InModuleScope -ModuleName $dscModuleName {
                $customPath = 'C:\CustomMCD'
                $instance = [MCDConfig]::new($customPath)
                $instance.WorkspacePath | Should -Be $customPath
            }
        }
    }

    Context 'Properties' {
        BeforeEach {
            InModuleScope -ModuleName $dscModuleName {
                $script:instance = [MCDConfig]::new()
            }
        }

        It 'Has a Version property with default value' {
            InModuleScope -ModuleName $dscModuleName {
                $script:instance.Version | Should -Be '1.0'
            }
        }

        It 'Has a WorkspacePath property with default value' {
            InModuleScope -ModuleName $dscModuleName {
                $script:instance.WorkspacePath | Should -Be (Join-Path -Path $env:ProgramData -ChildPath 'MCD')
            }
        }

        It 'Has a Defaults property as hashtable' {
            InModuleScope -ModuleName $dscModuleName {
                $script:instance.Defaults | Should -BeOfType [hashtable]
            }
        }

        It 'Has a Logging property with Level and FileName' {
            InModuleScope -ModuleName $dscModuleName {
                $script:instance.Logging | Should -BeOfType [hashtable]
                $script:instance.Logging.Level | Should -Be 'Info'
                $script:instance.Logging.FileName | Should -Be 'mcd.log'
            }
        }
    }

    Context 'Save and Load methods' {
        It 'Can save configuration to a file' {
            InModuleScope -ModuleName $dscModuleName {
                $instance = [MCDConfig]::new()
                $testPath = Join-Path -Path $TestDrive -ChildPath 'config.json'

                { $instance.Save($testPath) } | Should -Not -Throw

                Test-Path -Path $testPath | Should -BeTrue
            }
        }

        It 'Can load configuration from a file' {
            InModuleScope -ModuleName $dscModuleName {
                $instance = [MCDConfig]::new()
                $instance.Version = '2.0'
                $testPath = Join-Path -Path $TestDrive -ChildPath 'config.json'
                $instance.Save($testPath)

                $loaded = [MCDConfig]::Load($testPath)

                $loaded.Version | Should -Be '2.0'
            }
        }

        It 'Round-trips configuration correctly' {
            InModuleScope -ModuleName $dscModuleName {
                $original = [MCDConfig]::new()
                $original.Version = '3.0'
                $original.WorkspacePath = 'D:\TestMCD'
                $original.Logging.Level = 'Debug'

                $testPath = Join-Path -Path $TestDrive -ChildPath 'roundtrip.json'
                $original.Save($testPath)
                $loaded = [MCDConfig]::Load($testPath)

                $loaded.Version | Should -Be $original.Version
                $loaded.WorkspacePath | Should -Be $original.WorkspacePath
                $loaded.Logging.Level | Should -Be $original.Logging.Level
            }
        }

        It 'Throws when loading from non-existent file' {
            InModuleScope -ModuleName $dscModuleName {
                $fakePath = Join-Path -Path $TestDrive -ChildPath 'nonexistent.json'

                { [MCDConfig]::Load($fakePath) } | Should -Throw
            }
        }

        It 'Creates parent directory when saving' {
            InModuleScope -ModuleName $dscModuleName {
                $instance = [MCDConfig]::new()
                $testPath = Join-Path -Path $TestDrive -ChildPath 'subdir\config.json'

                { $instance.Save($testPath) } | Should -Not -Throw

                Test-Path -Path $testPath | Should -BeTrue
            }
        }
    }

    Context 'ToString method' {
        It 'Returns a descriptive string' {
            InModuleScope -ModuleName $dscModuleName {
                $instance = [MCDConfig]::new()
                $result = $instance.ToString()

                $result | Should -Match 'MCDConfig'
                $result | Should -Match '1.0'
            }
        }
    }
}
