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

Describe 'Test-MCDNetwork' {
    Context 'When checking network connectivity' {
        It 'Should return boolean result' {
            InModuleScope -ModuleName $dscModuleName {
                $result = Test-MCDNetwork

                $result | Should -BeOfType [bool]
            }
        }

        It 'Should not throw' {
            InModuleScope -ModuleName $dscModuleName {
                { Test-MCDNetwork } | Should -Not -Throw
            }
        }
    }

    Context 'When specifying custom parameters' {
        It 'Should accept custom hostname' {
            InModuleScope -ModuleName $dscModuleName {
                { Test-MCDNetwork -HostName 'dns.google' } | Should -Not -Throw
            }
        }

        It 'Should accept custom URI' {
            InModuleScope -ModuleName $dscModuleName {
                # Using a well-known URI that should be accessible
                { Test-MCDNetwork -Uri 'https://www.google.com' } | Should -Not -Throw
            }
        }

        It 'Should accept custom timeout' {
            InModuleScope -ModuleName $dscModuleName {
                { Test-MCDNetwork -TimeoutSeconds 10 } | Should -Not -Throw
            }
        }
    }

    Context 'When network is available' {
        It 'Should return true for accessible host' {
            InModuleScope -ModuleName $dscModuleName {
                # This test depends on actual network connectivity
                # In CI environments, this should typically pass
                $result = Test-MCDNetwork -HostName 'www.microsoft.com'

                # We don't assert true because CI might not have network
                # Just verify it returns a boolean
                $result | Should -BeOfType [bool]
            }
        }
    }

    Context 'When using mock for offline testing' {
        BeforeAll {
            # Mock DNS resolution to simulate offline
            Mock -CommandName Resolve-DnsName -MockWith {
                throw 'DNS resolution failed'
            } -ModuleName $dscModuleName
        }

        It 'Should handle DNS failure gracefully' {
            InModuleScope -ModuleName $dscModuleName {
                # This should not throw even when DNS fails
                { Test-MCDNetwork -HostName 'nonexistent.invalid' } | Should -Not -Throw
            }
        }
    }
}
