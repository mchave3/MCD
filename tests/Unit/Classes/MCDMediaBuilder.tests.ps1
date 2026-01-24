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

Describe 'MCDMediaBuilder' {
    Context 'Type creation' {
        It 'Has created a type named MCDMediaBuilder' {
            InModuleScope -ModuleName $dscModuleName {
                'MCDMediaBuilder' -as [Type] | Should -BeOfType [Type]
            }
        }
    }

    Context 'Constructors' {
        It 'Has a default constructor' {
            InModuleScope -ModuleName $dscModuleName {
                $instance = [MCDMediaBuilder]::new()
                $instance | Should -Not -BeNullOrEmpty
                $instance.GetType().Name | Should -Be 'MCDMediaBuilder'
            }
        }

        It 'Can be constructed with workspace' {
            InModuleScope -ModuleName $dscModuleName {
                $config = [MCDConfig]::new()
                $config.WorkspacePath = $TestDrive
                $workspace = [MCDWorkspace]::new('BuilderTest', $config)
                $workspace.Initialize()

                $instance = [MCDMediaBuilder]::new($workspace)

                $instance.Workspace | Should -Be $workspace
                $instance.OutputPath | Should -Be $workspace.MediaPath
            }
        }

        It 'Can be constructed with workspace and custom output path' {
            InModuleScope -ModuleName $dscModuleName {
                $config = [MCDConfig]::new()
                $config.WorkspacePath = $TestDrive
                $workspace = [MCDWorkspace]::new('BuilderTest2', $config)
                $workspace.Initialize()

                $customOutput = Join-Path -Path $TestDrive -ChildPath 'CustomOutput'
                $instance = [MCDMediaBuilder]::new($workspace, $customOutput)

                $instance.OutputPath | Should -Be $customOutput
            }
        }
    }

    Context 'Validate method' {
        It 'Returns false when workspace is null' {
            InModuleScope -ModuleName $dscModuleName {
                $instance = [MCDMediaBuilder]::new()

                $instance.Validate() | Should -BeFalse
            }
        }

        It 'Returns false when output path is empty' {
            InModuleScope -ModuleName $dscModuleName {
                $config = [MCDConfig]::new()
                $config.WorkspacePath = $TestDrive
                $workspace = [MCDWorkspace]::new('ValidateTest', $config)
                $workspace.Initialize()

                $instance = [MCDMediaBuilder]::new()
                $instance.Workspace = $workspace
                $instance.OutputPath = ''

                $instance.Validate() | Should -BeFalse
            }
        }

        It 'Returns true when properly configured' {
            InModuleScope -ModuleName $dscModuleName {
                $config = [MCDConfig]::new()
                $config.WorkspacePath = $TestDrive
                $workspace = [MCDWorkspace]::new('ValidateTest2', $config)
                $workspace.Initialize()

                $instance = [MCDMediaBuilder]::new($workspace)

                $instance.Validate() | Should -BeTrue
            }
        }
    }

    Context 'CreateUSB method' {
        It 'Throws when disk number is empty' {
            InModuleScope -ModuleName $dscModuleName {
                $config = [MCDConfig]::new()
                $config.WorkspacePath = $TestDrive
                $workspace = [MCDWorkspace]::new('USBTest', $config)
                $workspace.Initialize()
                $instance = [MCDMediaBuilder]::new($workspace)

                { $instance.CreateUSB('') } | Should -Throw
            }
        }

        It 'Throws when disk number is invalid format' {
            InModuleScope -ModuleName $dscModuleName {
                $config = [MCDConfig]::new()
                $config.WorkspacePath = $TestDrive
                $workspace = [MCDWorkspace]::new('USBTest2', $config)
                $workspace.Initialize()
                $instance = [MCDMediaBuilder]::new($workspace)

                { $instance.CreateUSB('abc') } | Should -Throw
            }
        }

        It 'Throws when workspace is not configured' {
            InModuleScope -ModuleName $dscModuleName {
                $instance = [MCDMediaBuilder]::new()

                { $instance.CreateUSB('1') } | Should -Throw
            }
        }

        It 'Does not throw with valid parameters' {
            InModuleScope -ModuleName $dscModuleName {
                $config = [MCDConfig]::new()
                $config.WorkspacePath = $TestDrive
                $workspace = [MCDWorkspace]::new('USBTest3', $config)
                $workspace.Initialize()
                $instance = [MCDMediaBuilder]::new($workspace)

                # This should validate without throwing (actual USB creation is scaffolded)
                { $instance.CreateUSB('1') } | Should -Not -Throw
            }
        }
    }

    Context 'CreateISO method' {
        It 'Throws when output path is empty' {
            InModuleScope -ModuleName $dscModuleName {
                $config = [MCDConfig]::new()
                $config.WorkspacePath = $TestDrive
                $workspace = [MCDWorkspace]::new('ISOTest', $config)
                $workspace.Initialize()
                $instance = [MCDMediaBuilder]::new($workspace)

                { $instance.CreateISO('') } | Should -Throw
            }
        }

        It 'Throws when output path has wrong extension' {
            InModuleScope -ModuleName $dscModuleName {
                $config = [MCDConfig]::new()
                $config.WorkspacePath = $TestDrive
                $workspace = [MCDWorkspace]::new('ISOTest2', $config)
                $workspace.Initialize()
                $instance = [MCDMediaBuilder]::new($workspace)

                $badPath = Join-Path -Path $TestDrive -ChildPath 'output.zip'
                { $instance.CreateISO($badPath) } | Should -Throw
            }
        }

        It 'Throws when parent directory does not exist' {
            InModuleScope -ModuleName $dscModuleName {
                $config = [MCDConfig]::new()
                $config.WorkspacePath = $TestDrive
                $workspace = [MCDWorkspace]::new('ISOTest3', $config)
                $workspace.Initialize()
                $instance = [MCDMediaBuilder]::new($workspace)

                $badPath = Join-Path -Path $TestDrive -ChildPath 'NonExistent\output.iso'
                { $instance.CreateISO($badPath) } | Should -Throw
            }
        }

        It 'Does not throw with valid parameters' {
            InModuleScope -ModuleName $dscModuleName {
                $config = [MCDConfig]::new()
                $config.WorkspacePath = $TestDrive
                $workspace = [MCDWorkspace]::new('ISOTest4', $config)
                $workspace.Initialize()
                $instance = [MCDMediaBuilder]::new($workspace)

                $validPath = Join-Path -Path $TestDrive -ChildPath 'output.iso'
                { $instance.CreateISO($validPath) } | Should -Not -Throw
            }
        }
    }

    Context 'GetWinPESourcePath method' {
        It 'Returns null when workspace is null' {
            InModuleScope -ModuleName $dscModuleName {
                $instance = [MCDMediaBuilder]::new()

                $instance.GetWinPESourcePath() | Should -BeNullOrEmpty
            }
        }

        It 'Returns correct path when workspace is set' {
            InModuleScope -ModuleName $dscModuleName {
                $config = [MCDConfig]::new()
                $config.WorkspacePath = $TestDrive
                $workspace = [MCDWorkspace]::new('WinPETest', $config)
                $workspace.Initialize()
                $instance = [MCDMediaBuilder]::new($workspace)

                $result = $instance.GetWinPESourcePath()

                $result | Should -Be (Join-Path -Path $workspace.TemplatePath -ChildPath 'WinPE')
            }
        }
    }

    Context 'ToString method' {
        It 'Returns a descriptive string' {
            InModuleScope -ModuleName $dscModuleName {
                $config = [MCDConfig]::new()
                $config.WorkspacePath = $TestDrive
                $workspace = [MCDWorkspace]::new('ToStringTest', $config)
                $instance = [MCDMediaBuilder]::new($workspace)

                $result = $instance.ToString()

                $result | Should -Match 'MCDMediaBuilder'
                $result | Should -Match 'ToStringTest'
            }
        }
    }
}
