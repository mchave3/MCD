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

Describe 'MCDWorkspace' {
    Context 'Type creation' {
        It 'Has created a type named MCDWorkspace' {
            InModuleScope -ModuleName $dscModuleName {
                'MCDWorkspace' -as [Type] | Should -BeOfType [Type]
            }
        }
    }

    Context 'Constructors' {
        It 'Has a default constructor' {
            InModuleScope -ModuleName $dscModuleName {
                $instance = [MCDWorkspace]::new()
                $instance | Should -Not -BeNullOrEmpty
                $instance.GetType().Name | Should -Be 'MCDWorkspace'
            }
        }

        It 'Default constructor sets Name to Default' {
            InModuleScope -ModuleName $dscModuleName {
                $instance = [MCDWorkspace]::new()
                $instance.Name | Should -Be 'Default'
            }
        }

        It 'Can be constructed with name and config' {
            InModuleScope -ModuleName $dscModuleName {
                $config = [MCDConfig]::new()
                $config.WorkspacePath = $TestDrive
                $instance = [MCDWorkspace]::new('TestWorkspace', $config)

                $instance.Name | Should -Be 'TestWorkspace'
                $instance.Config | Should -Be $config
            }
        }

        It 'Sets paths correctly when constructed with config' {
            InModuleScope -ModuleName $dscModuleName {
                $config = [MCDConfig]::new()
                $config.WorkspacePath = $TestDrive
                $instance = [MCDWorkspace]::new('MyWorkspace', $config)

                $instance.Path | Should -Be (Join-Path -Path $TestDrive -ChildPath 'Workspaces\MyWorkspace')
                $instance.TemplatePath | Should -Be (Join-Path -Path $TestDrive -ChildPath 'Workspaces\MyWorkspace\Template')
                $instance.MediaPath | Should -Be (Join-Path -Path $TestDrive -ChildPath 'Workspaces\MyWorkspace\Media')
            }
        }
    }

    Context 'Initialize method' {
        It 'Creates workspace directory structure' {
            InModuleScope -ModuleName $dscModuleName {
                $config = [MCDConfig]::new()
                $config.WorkspacePath = $TestDrive
                $instance = [MCDWorkspace]::new('InitTest', $config)

                $instance.Initialize()

                Test-Path -Path $instance.Path | Should -BeTrue
                Test-Path -Path (Join-Path -Path $instance.Path -ChildPath 'Template') | Should -BeTrue
                Test-Path -Path (Join-Path -Path $instance.Path -ChildPath 'Media') | Should -BeTrue
                Test-Path -Path (Join-Path -Path $instance.Path -ChildPath 'Logs') | Should -BeTrue
                Test-Path -Path (Join-Path -Path $instance.Path -ChildPath 'Cache') | Should -BeTrue
            }
        }

        It 'Throws when path is not configured' {
            InModuleScope -ModuleName $dscModuleName {
                $instance = [MCDWorkspace]::new()

                { $instance.Initialize() } | Should -Throw
            }
        }
    }

    Context 'Validate method' {
        It 'Returns false when config is null' {
            InModuleScope -ModuleName $dscModuleName {
                $instance = [MCDWorkspace]::new()

                $instance.Validate() | Should -BeFalse
            }
        }

        It 'Returns false when path is empty' {
            InModuleScope -ModuleName $dscModuleName {
                $instance = [MCDWorkspace]::new()
                $instance.Config = [MCDConfig]::new()

                $instance.Validate() | Should -BeFalse
            }
        }

        It 'Returns false when directory does not exist' {
            InModuleScope -ModuleName $dscModuleName {
                $config = [MCDConfig]::new()
                $config.WorkspacePath = $TestDrive
                $instance = [MCDWorkspace]::new('NonExistent', $config)

                $instance.Validate() | Should -BeFalse
            }
        }

        It 'Returns true after successful initialization' {
            InModuleScope -ModuleName $dscModuleName {
                $config = [MCDConfig]::new()
                $config.WorkspacePath = $TestDrive
                $instance = [MCDWorkspace]::new('ValidTest', $config)
                $instance.Initialize()

                $instance.Validate() | Should -BeTrue
            }
        }
    }

    Context 'Helper methods' {
        BeforeEach {
            InModuleScope -ModuleName $dscModuleName {
                $script:config = [MCDConfig]::new()
                $script:config.WorkspacePath = $TestDrive
                $script:instance = [MCDWorkspace]::new('HelperTest', $script:config)
            }
        }

        It 'GetConfigPath returns correct path' {
            InModuleScope -ModuleName $dscModuleName {
                $result = $script:instance.GetConfigPath()
                $result | Should -Be (Join-Path -Path $script:instance.Path -ChildPath 'workspace.json')
            }
        }

        It 'GetLogsPath returns correct path' {
            InModuleScope -ModuleName $dscModuleName {
                $result = $script:instance.GetLogsPath()
                $result | Should -Be (Join-Path -Path $script:instance.Path -ChildPath 'Logs')
            }
        }

        It 'GetCachePath returns correct path' {
            InModuleScope -ModuleName $dscModuleName {
                $result = $script:instance.GetCachePath()
                $result | Should -Be (Join-Path -Path $script:instance.Path -ChildPath 'Cache')
            }
        }
    }

    Context 'ToString method' {
        It 'Returns a descriptive string' {
            InModuleScope -ModuleName $dscModuleName {
                $config = [MCDConfig]::new()
                $config.WorkspacePath = $TestDrive
                $instance = [MCDWorkspace]::new('ToStringTest', $config)
                $result = $instance.ToString()

                $result | Should -Match 'MCDWorkspace'
                $result | Should -Match 'ToStringTest'
            }
        }
    }
}
