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

Describe 'MCDDeployment' {
    Context 'Type creation' {
        It 'Has created a type named MCDDeployment' {
            InModuleScope -ModuleName $dscModuleName {
                'MCDDeployment' -as [Type] | Should -BeOfType [Type]
            }
        }
    }

    Context 'Constructors' {
        It 'Has a default constructor' {
            InModuleScope -ModuleName $dscModuleName {
                $instance = [MCDDeployment]::new()
                $instance | Should -Not -BeNullOrEmpty
                $instance.GetType().Name | Should -Be 'MCDDeployment'
            }
        }

        It 'Default constructor generates a SessionId' {
            InModuleScope -ModuleName $dscModuleName {
                $instance = [MCDDeployment]::new()
                $instance.SessionId | Should -Not -BeNullOrEmpty
                # Verify it's a valid GUID format
                { [guid]::Parse($instance.SessionId) } | Should -Not -Throw
            }
        }

        It 'Default constructor sets default working path' {
            InModuleScope -ModuleName $dscModuleName {
                $instance = [MCDDeployment]::new()
                $instance.WorkingPath | Should -Be 'X:\MCD'
            }
        }

        It 'Can be constructed with config' {
            InModuleScope -ModuleName $dscModuleName {
                $config = [MCDConfig]::new()
                $instance = [MCDDeployment]::new($config)

                $instance.Config | Should -Be $config
            }
        }

        It 'Can be constructed with config and custom working path' {
            InModuleScope -ModuleName $dscModuleName {
                $config = [MCDConfig]::new()
                $instance = [MCDDeployment]::new($config, 'D:\Deploy')

                $instance.WorkingPath | Should -Be 'D:\Deploy'
            }
        }

        It 'Initializes default deployment steps' {
            InModuleScope -ModuleName $dscModuleName {
                $instance = [MCDDeployment]::new()

                $instance.Steps | Should -Not -BeNullOrEmpty
                $instance.Steps.ContainsKey('01-Initialize') | Should -BeTrue
                $instance.Steps.ContainsKey('04-Image') | Should -BeTrue
                $instance.Steps.ContainsKey('07-Cleanup') | Should -BeTrue
            }
        }
    }

    Context 'Initialize method' {
        It 'Creates working directory structure' {
            InModuleScope -ModuleName $dscModuleName {
                $config = [MCDConfig]::new()
                $instance = [MCDDeployment]::new($config, $TestDrive)

                $instance.Initialize()

                Test-Path -Path $TestDrive | Should -BeTrue
                Test-Path -Path (Join-Path -Path $TestDrive -ChildPath 'Logs') | Should -BeTrue
                Test-Path -Path (Join-Path -Path $TestDrive -ChildPath 'Temp') | Should -BeTrue
            }
        }
    }

    Context 'LogStep method' {
        It 'Adds log entries to step' {
            InModuleScope -ModuleName $dscModuleName {
                $config = [MCDConfig]::new()
                $instance = [MCDDeployment]::new($config, $TestDrive)
                $instance.Initialize()

                $instance.LogStep('01-Initialize', 'Test message')

                $instance.Steps['01-Initialize'].Logs.Count | Should -BeGreaterThan 0
                $instance.Steps['01-Initialize'].Logs[-1] | Should -Match 'Test message'
            }
        }

        It 'Creates step if it does not exist' {
            InModuleScope -ModuleName $dscModuleName {
                $config = [MCDConfig]::new()
                $instance = [MCDDeployment]::new($config, $TestDrive)
                $instance.Initialize()

                $instance.LogStep('99-CustomStep', 'Custom message')

                $instance.Steps.ContainsKey('99-CustomStep') | Should -BeTrue
            }
        }

        It 'Writes to log file' {
            InModuleScope -ModuleName $dscModuleName {
                $uniquePath = Join-Path -Path $TestDrive -ChildPath ([guid]::NewGuid().ToString())
                $config = [MCDConfig]::new()
                $instance = [MCDDeployment]::new($config, $uniquePath)
                $instance.Initialize()

                $instance.LogStep('01-Initialize', 'File log test')

                $logFile = Join-Path -Path $uniquePath -ChildPath 'Logs\01-Initialize.log'
                Test-Path -Path $logFile | Should -BeTrue
                Get-Content -Path $logFile | Should -Match 'File log test'
            }
        }
    }

    Context 'StartStep and CompleteStep methods' {
        It 'StartStep sets status to InProgress' {
            InModuleScope -ModuleName $dscModuleName {
                $config = [MCDConfig]::new()
                $instance = [MCDDeployment]::new($config, $TestDrive)
                $instance.Initialize()

                $instance.StartStep('01-Initialize')

                $instance.Steps['01-Initialize'].Status | Should -Be 'InProgress'
                $instance.Steps['01-Initialize'].StartTime | Should -Not -BeNullOrEmpty
            }
        }

        It 'CompleteStep sets status to Completed on success' {
            InModuleScope -ModuleName $dscModuleName {
                $config = [MCDConfig]::new()
                $instance = [MCDDeployment]::new($config, $TestDrive)
                $instance.Initialize()

                $instance.StartStep('01-Initialize')
                $instance.CompleteStep('01-Initialize', $true)

                $instance.Steps['01-Initialize'].Status | Should -Be 'Completed'
                $instance.Steps['01-Initialize'].EndTime | Should -Not -BeNullOrEmpty
            }
        }

        It 'CompleteStep sets status to Failed on failure' {
            InModuleScope -ModuleName $dscModuleName {
                $config = [MCDConfig]::new()
                $instance = [MCDDeployment]::new($config, $TestDrive)
                $instance.Initialize()

                $instance.StartStep('03-Format')
                $instance.CompleteStep('03-Format', $false)

                $instance.Steps['03-Format'].Status | Should -Be 'Failed'
            }
        }
    }

    Context 'GetCurrentStep method' {
        It 'Returns null when no step is in progress' {
            InModuleScope -ModuleName $dscModuleName {
                $instance = [MCDDeployment]::new()

                $instance.GetCurrentStep() | Should -BeNullOrEmpty
            }
        }

        It 'Returns the step name when a step is in progress' {
            InModuleScope -ModuleName $dscModuleName {
                $config = [MCDConfig]::new()
                $instance = [MCDDeployment]::new($config, $TestDrive)
                $instance.Initialize()
                $instance.StartStep('04-Image')

                $instance.GetCurrentStep() | Should -Be '04-Image'
            }
        }
    }

    Context 'GetElapsedTime method' {
        It 'Returns a TimeSpan' {
            InModuleScope -ModuleName $dscModuleName {
                $instance = [MCDDeployment]::new()
                Start-Sleep -Milliseconds 100

                $elapsed = $instance.GetElapsedTime()

                $elapsed | Should -BeOfType [TimeSpan]
                $elapsed.TotalMilliseconds | Should -BeGreaterThan 50
            }
        }
    }

    Context 'ToString method' {
        It 'Returns a descriptive string' {
            InModuleScope -ModuleName $dscModuleName {
                $instance = [MCDDeployment]::new()
                $result = $instance.ToString()

                $result | Should -Match 'MCDDeployment'
                $result | Should -Match $instance.SessionId
            }
        }
    }
}
