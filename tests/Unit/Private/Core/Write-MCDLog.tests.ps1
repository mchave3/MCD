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

Describe 'Write-MCDLog' {
    Context 'When writing to verbose output' {
        It 'Should not throw with valid message' {
            InModuleScope -ModuleName $dscModuleName {
                { Write-MCDLog -Message 'Test message' -NoFile } | Should -Not -Throw
            }
        }

        It 'Should accept pipeline input' {
            InModuleScope -ModuleName $dscModuleName {
                { 'Pipeline message' | Write-MCDLog -NoFile } | Should -Not -Throw
            }
        }

        It 'Should accept all valid log levels' {
            InModuleScope -ModuleName $dscModuleName {
                { Write-MCDLog -Message 'Trace' -Level Trace -NoFile } | Should -Not -Throw
                { Write-MCDLog -Message 'Debug' -Level Debug -NoFile } | Should -Not -Throw
                { Write-MCDLog -Message 'Info' -Level Info -NoFile } | Should -Not -Throw
                { Write-MCDLog -Message 'Warn' -Level Warn -NoFile } | Should -Not -Throw
                { Write-MCDLog -Message 'Error' -Level Error -NoFile } | Should -Not -Throw
            }
        }
    }

    Context 'When writing to a log file' {
        It 'Should create log file if it does not exist' {
            InModuleScope -ModuleName $dscModuleName {
                $logPath = Join-Path -Path $TestDrive -ChildPath 'test.log'

                Write-MCDLog -Message 'Test message' -Path $logPath

                Test-Path -Path $logPath | Should -BeTrue
            }
        }

        It 'Should append to existing log file' {
            InModuleScope -ModuleName $dscModuleName {
                $logPath = Join-Path -Path $TestDrive -ChildPath 'append.log'

                Write-MCDLog -Message 'First message' -Path $logPath
                Write-MCDLog -Message 'Second message' -Path $logPath

                $content = Get-Content -Path $logPath
                $content.Count | Should -Be 2
            }
        }

        It 'Should include timestamp in log entry' {
            InModuleScope -ModuleName $dscModuleName {
                $logPath = Join-Path -Path $TestDrive -ChildPath 'timestamp.log'

                Write-MCDLog -Message 'Timestamp test' -Path $logPath

                $content = Get-Content -Path $logPath
                $content | Should -Match '\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]'
            }
        }

        It 'Should include log level in log entry' {
            InModuleScope -ModuleName $dscModuleName {
                $logPath = Join-Path -Path $TestDrive -ChildPath 'level.log'

                Write-MCDLog -Message 'Level test' -Level Error -Path $logPath

                $content = Get-Content -Path $logPath
                $content | Should -Match '\[Error\]'
            }
        }

        It 'Should create parent directory if it does not exist' {
            InModuleScope -ModuleName $dscModuleName {
                $logPath = Join-Path -Path $TestDrive -ChildPath 'subdir\nested.log'

                Write-MCDLog -Message 'Nested test' -Path $logPath

                Test-Path -Path $logPath | Should -BeTrue
            }
        }
    }

    Context 'When NoFile is specified' {
        It 'Should not create a log file even with path specified' {
            InModuleScope -ModuleName $dscModuleName {
                $logPath = Join-Path -Path $TestDrive -ChildPath 'nofile.log'

                Write-MCDLog -Message 'NoFile test' -Path $logPath -NoFile

                Test-Path -Path $logPath | Should -BeFalse
            }
        }
    }
}
