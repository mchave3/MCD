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

Describe 'Test-MCDPrerequisite' {
    Context 'When checking PowerShell version' {
        It 'Should return boolean result' {
            InModuleScope -ModuleName $dscModuleName {
                $result = Test-MCDPrerequisite -SkipAdminCheck

                $result | Should -BeOfType [bool]
            }
        }

        It 'Should not throw' {
            InModuleScope -ModuleName $dscModuleName {
                { Test-MCDPrerequisite -SkipAdminCheck } | Should -Not -Throw
            }
        }
    }

    Context 'When checking mode parameter' {
        It 'Should accept Workspace mode' {
            InModuleScope -ModuleName $dscModuleName {
                { Test-MCDPrerequisite -Mode Workspace -SkipAdminCheck } | Should -Not -Throw
            }
        }

        It 'Should accept WinPE mode' {
            InModuleScope -ModuleName $dscModuleName {
                { Test-MCDPrerequisite -Mode WinPE -SkipAdminCheck } | Should -Not -Throw
            }
        }

        It 'Should accept Auto mode' {
            InModuleScope -ModuleName $dscModuleName {
                { Test-MCDPrerequisite -Mode Auto -SkipAdminCheck } | Should -Not -Throw
            }
        }

        It 'Should reject invalid mode' {
            InModuleScope -ModuleName $dscModuleName {
                { Test-MCDPrerequisite -Mode 'InvalidMode' -SkipAdminCheck } | Should -Throw
            }
        }
    }

    Context 'When SkipAdminCheck is specified' {
        It 'Should have SkipAdminCheck parameter' {
            InModuleScope -ModuleName $dscModuleName {
                (Get-Command -Name 'Test-MCDPrerequisite').Parameters.ContainsKey('SkipAdminCheck') | Should -BeTrue
            }
        }

        It 'Should check admin when SkipAdminCheck is not specified' {
            InModuleScope -ModuleName $dscModuleName {
                # This test may pass or fail depending on actual admin status
                # The important thing is it doesn't throw
                { Test-MCDPrerequisite } | Should -Not -Throw
            }
        }
    }

    Context 'When in full Windows environment' {
        It 'Should detect non-WinPE environment correctly' {
            InModuleScope -ModuleName $dscModuleName {
                # In a normal test environment, we should be in full Windows
                # This is a sanity check that the detection logic runs
                { Test-MCDPrerequisite -Mode Auto -SkipAdminCheck } | Should -Not -Throw
            }
        }
    }
}
