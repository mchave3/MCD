BeforeAll {
    $script:dscModuleName = 'MCD'

    Import-Module -Name $script:dscModuleName
}

AfterAll {
    # Unload the module being tested so that it doesn't impact any other tests.
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}

Describe 'Start-MCDWorkspace' {
    BeforeAll {
        # Mock private functions to avoid side effects
        Mock -CommandName Test-MCDPrerequisite -MockWith {
            return $true
        } -ModuleName $dscModuleName

        Mock -CommandName Get-MCDConfig -MockWith {
            InModuleScope -ModuleName $dscModuleName {
                $config = [MCDConfig]::new()
                $config.WorkspacePath = $TestDrive
                return $config
            }
        } -ModuleName $dscModuleName
    }

    Context 'When checking command parameters' {
        It 'Should have Name parameter' {
            (Get-Command -Name 'Start-MCDWorkspace').Parameters.ContainsKey('Name') | Should -BeTrue
        }

        It 'Should have ConfigPath parameter' {
            (Get-Command -Name 'Start-MCDWorkspace').Parameters.ContainsKey('ConfigPath') | Should -BeTrue
        }

        It 'Should have NoGui parameter' {
            (Get-Command -Name 'Start-MCDWorkspace').Parameters.ContainsKey('NoGui') | Should -BeTrue
        }

        It 'Should support WhatIf parameter' {
            (Get-Command -Name 'Start-MCDWorkspace').Parameters.ContainsKey('WhatIf') | Should -BeTrue
        }

        It 'Should support Confirm parameter' {
            (Get-Command -Name 'Start-MCDWorkspace').Parameters.ContainsKey('Confirm') | Should -BeTrue
        }
    }

    Context 'When running with NoGui' {
        It 'Should return MCDWorkspace object' {
            # Create the test path outside InModuleScope
            $testWorkspacePath = Join-Path -Path $TestDrive -ChildPath 'WorkspaceTest1'
            New-Item -Path $testWorkspacePath -ItemType Directory -Force | Out-Null

            InModuleScope -ModuleName $dscModuleName -Parameters @{ wsPath = $testWorkspacePath } {
                param($wsPath)

                Mock -CommandName Get-MCDConfig -MockWith {
                    $config = [MCDConfig]::new()
                    $config.WorkspacePath = $wsPath
                    return $config
                }

                Mock -CommandName Test-MCDPrerequisite -MockWith { return $true }

                $result = Start-MCDWorkspace -Name 'TestWS' -NoGui -Confirm:$false

                $result | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should call Test-MCDPrerequisite' {
            Start-MCDWorkspace -Name 'TestWS2' -NoGui -Confirm:$false

            Should -Invoke -CommandName Test-MCDPrerequisite -ModuleName $dscModuleName
        }

        It 'Should call Get-MCDConfig' {
            Start-MCDWorkspace -Name 'TestWS3' -NoGui -Confirm:$false

            Should -Invoke -CommandName Get-MCDConfig -ModuleName $dscModuleName
        }
    }

    Context 'When WhatIf is specified' {
        It 'Should not create workspace directories with WhatIf' {
            # Create the test path outside InModuleScope
            $testPath = Join-Path -Path $TestDrive -ChildPath 'WhatIfTest'

            InModuleScope -ModuleName $dscModuleName -Parameters @{ wsPath = $testPath } {
                param($wsPath)

                Mock -CommandName Get-MCDConfig -MockWith {
                    $config = [MCDConfig]::new()
                    $config.WorkspacePath = $wsPath
                    return $config
                }

                Mock -CommandName Test-MCDPrerequisite -MockWith { return $true }

                Start-MCDWorkspace -Name 'WhatIfWS' -NoGui -WhatIf

                # With WhatIf, the workspace subdirectory should not be created
                $workspacePath = Join-Path -Path $wsPath -ChildPath 'Workspaces\WhatIfWS'
                Test-Path -Path $workspacePath | Should -BeFalse
            }
        }
    }

    Context 'When prerequisites fail' {
        It 'Should throw when prerequisites check fails' {
            Mock -CommandName Test-MCDPrerequisite -MockWith {
                return $false
            } -ModuleName $dscModuleName

            { Start-MCDWorkspace -Name 'FailTest' -NoGui } | Should -Throw
        }
    }
}
