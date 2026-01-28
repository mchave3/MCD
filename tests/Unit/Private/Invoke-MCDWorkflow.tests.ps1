BeforeAll {
    $modulePath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    Import-Module $modulePath -Force

    # Setup test directories
    $testLogsPath = Join-Path $TestDrive 'Logs'
    $testStatePath = Join-Path $TestDrive 'State.json'

    New-Item -Path $testLogsPath -ItemType Directory -Force | Out-Null
}

AfterAll {
    Remove-Module MCD -Force
}

Describe 'Invoke-MCDWorkflow' {

    Context 'Sequential Execution' {
        BeforeEach {
            $workflow = @{
                id      = 'test-sequential'
                name    = 'Sequential Test Workflow'
                version = '1.0.0'
                author  = 'Test'
                amd64   = $true
                arm64   = $true
                default = $true
                steps   = @(
                    @{
                        name        = 'Step 1'
                        description = 'First step'
                        command     = 'Write-Output'
                        args        = @('Step 1 executed')
                        parameters  = @{}
                        rules       = @{
                            skip             = $false
                            runinfullos      = $false
                            runinwinpe       = $true
                            architecture     = @('amd64', 'arm64')
                            retry            = @{
                                enabled      = $false
                                maxAttempts  = 3
                                retryDelay   = 5
                            }
                            continueOnError = $false
                        }
                    },
                    @{
                        name        = 'Step 2'
                        description = 'Second step'
                        command     = 'Write-Output'
                        args        = @('Step 2 executed')
                        parameters  = @{}
                        rules       = @{
                            skip             = $false
                            runinfullos      = $false
                            runinwinpe       = $true
                            architecture     = @('amd64', 'arm64')
                            retry            = @{
                                enabled      = $false
                                maxAttempts  = 3
                                retryDelay   = 5
                            }
                            continueOnError = $false
                        }
                    }
                )
            }

            Mock Update-MCDWinPEProgress {}
            Mock Write-MCDLog {}
            Mock Test-Path { $true } -ParameterFilter { $Path -like '*Windows\Temp\MCD*' }
        }

        It 'Should execute workflow steps sequentially' {
            $global:MCDWorkflowIsWinPE = $true
            $global:MCDWorkflowCurrentStepIndex = 0
            $global:MCDWorkflowContext = @{
                Window     = $null
                CurrentStep = $null
                LogsRoot    = $testLogsPath
                StatePath   = $testStatePath
                StartTime   = [datetime](Get-Date)
            }

            Invoke-MCDWorkflow -WorkflowObject $workflow

            # Both steps should have executed
            Should -Invoke Write-Output -Times 2
        }

        It 'Should track current step index' {
            Mock Test-Path { $true }

            Invoke-MCDWorkflow -WorkflowObject $workflow

            $global:MCDWorkflowCurrentStepIndex | Should -Be 2
        }
    }

    Context 'Skip Rules' {
        BeforeEach {
            $workflow = @{
                id      = 'test-skip'
                name    = 'Skip Test Workflow'
                version = '1.0.0'
                author  = 'Test'
                amd64   = $true
                arm64   = $true
                default = $true
                steps   = @(
                    @{
                        name        = 'Step 1 (Execute)'
                        description = 'First step'
                        command     = 'Write-Output'
                        args        = @('Step 1 executed')
                        parameters  = @{}
                        rules       = @{
                            skip             = $false
                            runinfullos      = $false
                            runinwinpe       = $true
                            architecture     = @('amd64', 'arm64')
                            retry            = @{
                                enabled      = $false
                                maxAttempts  = 3
                                retryDelay   = 5
                            }
                            continueOnError = $false
                        }
                    },
                    @{
                        name        = 'Step 2 (Skip)'
                        description = 'Second step'
                        command     = 'Write-Output'
                        args        = @('Step 2 executed')
                        parameters  = @{}
                        rules       = @{
                            skip             = $true
                            runinfullos      = $false
                            runinwinpe       = $true
                            architecture     = @('amd64', 'arm64')
                            retry            = @{
                                enabled      = $false
                                maxAttempts  = 3
                                retryDelay   = 5
                            }
                            continueOnError = $false
                        }
                    },
                    @{
                        name        = 'Step 3 (Execute)'
                        description = 'Third step'
                        command     = 'Write-Output'
                        args        = @('Step 3 executed')
                        parameters  = @{}
                        rules       = @{
                            skip             = $false
                            runinfullos      = $false
                            runinwinpe       = $true
                            architecture     = @('amd64', 'arm64')
                            retry            = @{
                                enabled      = $false
                                maxAttempts  = 3
                                retryDelay   = 5
                            }
                            continueOnError = $false
                        }
                    }
                )
            }

            Mock Update-MCDWinPEProgress {}
            Mock Write-MCDLog {}
        }

        It 'Should skip steps with skip rule set to true' {
            $global:MCDWorkflowIsWinPE = $true
            $global:MCDWorkflowCurrentStepIndex = 0
            $global:MCDWorkflowContext = @{
                Window     = $null
                CurrentStep = $null
                LogsRoot    = $testLogsPath
                StatePath   = $testStatePath
                StartTime   = [datetime](Get-Date)
            }

            Invoke-MCDWorkflow -WorkflowObject $workflow

            # Only steps 1 and 3 should execute (step 2 is skipped)
            Should -Invoke Write-Output -Times 2
        }
    }

    Context 'Architecture Filtering' {
        BeforeEach {
            $workflow = @{
                id      = 'test-arch'
                name    = 'Architecture Test Workflow'
                version = '1.0.0'
                author  = 'Test'
                amd64   = $true
                arm64   = $true
                default = $true
                steps   = @(
                    @{
                        name        = 'AMD64 Step'
                        description = 'AMD64 only step'
                        command     = 'Write-Output'
                        args        = @('AMD64 step')
                        parameters  = @{}
                        rules       = @{
                            skip             = $false
                            runinfullos      = $false
                            runinwinpe       = $true
                            architecture     = @('amd64')
                            retry            = @{
                                enabled      = $false
                                maxAttempts  = 3
                                retryDelay   = 5
                            }
                            continueOnError = $false
                        }
                    },
                    @{
                        name        = 'ARM64 Step'
                        description = 'ARM64 only step'
                        command     = 'Write-Output'
                        args        = @('ARM64 step')
                        parameters  = @{}
                        rules       = @{
                            skip             = $false
                            runinfullos      = $false
                            runinwinpe       = $true
                            architecture     = @('arm64')
                            retry            = @{
                                enabled      = $false
                                maxAttempts  = 3
                                retryDelay   = 5
                            }
                            continueOnError = $false
                        }
                    }
                )
            }

            Mock Update-MCDWinPEProgress {}
            Mock Write-MCDLog {}
        }

        It 'Should skip steps that do not match current architecture' {
            Mock Get-ProcessorArchitecture { 'AMD64' }

            $global:MCDWorkflowIsWinPE = $true
            $global:MCDWorkflowCurrentStepIndex = 0
            $global:MCDWorkflowContext = @{
                Window     = $null
                CurrentStep = $null
                LogsRoot    = $testLogsPath
                StatePath   = $testStatePath
                StartTime   = [datetime](Get-Date)
            }

            Invoke-MCDWorkflow -WorkflowObject $workflow

            # Only AMD64 step should execute
            Should -Invoke Write-Output -Times 1
        }
    }

    Context 'Missing Step Validation' {
        BeforeEach {
            $workflow = @{
                id      = 'test-missing'
                name    = 'Missing Step Test Workflow'
                version = '1.0.0'
                author  = 'Test'
                amd64   = $true
                arm64   = $true
                default = $true
                steps   = @(
                    @{
                        name        = 'Valid Step'
                        description = 'Valid step'
                        command     = 'Write-Output'
                        args        = @('Valid step')
                        parameters  = @{}
                        rules       = @{
                            skip             = $false
                            runinfullos      = $false
                            runinwinpe       = $true
                            architecture     = @('amd64', 'arm64')
                            retry            = @{
                                enabled      = $false
                                maxAttempts  = 3
                                retryDelay   = 5
                            }
                            continueOnError = $false
                        }
                    },
                    @{
                        name        = 'Missing Command Step'
                        description = 'Step with missing command'
                        command     = 'Invoke-NonExistentCommand'
                        args        = @()
                        parameters  = @{}
                        rules       = @{
                            skip             = $false
                            runinfullos      = $false
                            runinwinpe       = $true
                            architecture     = @('amd64', 'arm64')
                            retry            = @{
                                enabled      = $false
                                maxAttempts  = 3
                                retryDelay   = 5
                            }
                            continueOnError = $false
                        }
                    }
                )
            }

            Mock Update-MCDWinPEProgress {}
            Mock Write-MCDLog {}
            Mock Test-Path {
                param($Path)
                $Path -notlike '*NonExistent*'
            }
        }

        It 'Should error before executing step with missing command' {
            $global:MCDWorkflowIsWinPE = $true
            $global:MCDWorkflowCurrentStepIndex = 0
            $global:MCDWorkflowContext = @{
                Window     = $null
                CurrentStep = $null
                LogsRoot    = $testLogsPath
                StatePath   = $testStatePath
                StartTime   = [datetime](Get-Date)
            }

            { Invoke-MCDWorkflow -WorkflowObject $workflow } | Should -Throw
        }
    }

    Context 'Parameter Passing' {
        BeforeEach {
            $workflow = @{
                id      = 'test-params'
                name    = 'Parameter Test Workflow'
                version = '1.0.0'
                author  = 'Test'
                amd64   = $true
                arm64   = $true
                default = $true
                steps   = @()
            }

            Mock Update-MCDWinPEProgress {}
            Mock Write-MCDLog {}
        }

        It 'Should execute step with args array' {
            $workflow.steps = @(@{
                name        = 'Args Step'
                description = 'Test args'
                command     = 'Test-ArgsFunction'
                args        = @('arg1', 'arg2', 'arg3')
                parameters  = @{}
                rules       = @{
                    skip             = $false
                    runinfullos      = $false
                    runinwinpe       = $true
                    architecture     = @('amd64', 'arm64')
                    retry            = @{
                        enabled      = $false
                        maxAttempts  = 3
                        retryDelay   = 5
                    }
                    continueOnError = $false
                }
            })

            Mock Test-ArgsFunction {}

            $global:MCDWorkflowIsWinPE = $true
            $global:MCDWorkflowCurrentStepIndex = 0
            $global:MCDWorkflowContext = @{
                Window     = $null
                CurrentStep = $null
                LogsRoot    = $testLogsPath
                StatePath   = $testStatePath
                StartTime   = [datetime](Get-Date)
            }

            Invoke-MCDWorkflow -WorkflowObject $workflow

            Should -Invoke Test-ArgsFunction -Times 1
        }

        It 'Should execute step with parameters hashtable' {
            $workflow.steps = @(@{
                name        = 'Params Step'
                description = 'Test parameters'
                command     = 'Test-ParamsFunction'
                args        = @()
                parameters  = @{
                    Param1 = 'value1'
                    Param2 = 'value2'
                }
                rules       = @{
                    skip             = $false
                    runinfullos      = $false
                    runinwinpe       = $true
                    architecture     = @('amd64', 'arm64')
                    retry            = @{
                        enabled      = $false
                        maxAttempts  = 3
                        retryDelay   = 5
                    }
                    continueOnError = $false
                }
            })

            Mock Test-ParamsFunction {}

            $global:MCDWorkflowIsWinPE = $true
            $global:MCDWorkflowCurrentStepIndex = 0
            $global:MCDWorkflowContext = @{
                Window     = $null
                CurrentStep = $null
                LogsRoot    = $testLogsPath
                StatePath   = $testStatePath
                StartTime   = [datetime](Get-Date)
            }

            Invoke-MCDWorkflow -WorkflowObject $workflow

            Should -Invoke Test-ParamsFunction -Times 1
        }

        It 'Should execute step with both args and parameters' {
            $workflow.steps = @(@{
                name        = 'Combined Step'
                description = 'Test combined'
                command     = 'Test-CombinedFunction'
                args        = @('positional1', 'positional2')
                parameters  = @{
                    Named1 = 'value1'
                    Named2 = 'value2'
                }
                rules       = @{
                    skip             = $false
                    runinfullos      = $false
                    runinwinpe       = $true
                    architecture     = @('amd64', 'arm64')
                    retry            = @{
                        enabled      = $false
                        maxAttempts  = 3
                        retryDelay   = 5
                    }
                    continueOnError = $false
                }
            })

            Mock Test-CombinedFunction {}

            $global:MCDWorkflowIsWinPE = $true
            $global:MCDWorkflowCurrentStepIndex = 0
            $global:MCDWorkflowContext = @{
                Window     = $null
                CurrentStep = $null
                LogsRoot    = $testLogsPath
                StatePath   = $testStatePath
                StartTime   = [datetime](Get-Date)
            }

            Invoke-MCDWorkflow -WorkflowObject $workflow

            Should -Invoke Test-CombinedFunction -Times 1
        }
    }

    Context 'Retry Logic' {
        BeforeEach {
            $attemptCount = 0

            $workflow = @{
                id      = 'test-retry'
                name    = 'Retry Test Workflow'
                version = '1.0.0'
                author  = 'Test'
                amd64   = $true
                arm64   = $true
                default = $true
                steps   = @(
                    @{
                        name        = 'Retry Step'
                        description = 'Test retry'
                        command     = 'Test-RetryFunction'
                        args        = @()
                        parameters  = @{}
                        rules       = @{
                            skip             = $false
                            runinfullos      = $false
                            runinwinpe       = $true
                            architecture     = @('amd64', 'arm64')
                            retry            = @{
                                enabled      = $true
                                maxAttempts  = 3
                                retryDelay   = 5
                            }
                            continueOnError = $false
                        }
                    }
                )
            }

            Mock Update-MCDWinPEProgress {}
            Mock Write-MCDLog {}

            Mock Test-RetryFunction {
                $script:attemptCount++
                if ($attemptCount -lt 2) {
                    throw "Test failure"
                }
            }

            Mock Start-Sleep {}
        }

        It 'Should retry step on failure up to maxAttempts' {
            $global:MCDWorkflowIsWinPE = $true
            $global:MCDWorkflowCurrentStepIndex = 0
            $global:MCDWorkflowContext = @{
                Window     = $null
                CurrentStep = $null
                LogsRoot    = $testLogsPath
                StatePath   = $testStatePath
                StartTime   = [datetime](Get-Date)
            }

            Invoke-MCDWorkflow -WorkflowObject $workflow

            $attemptCount | Should -Be 2
        }

        It 'Should wait retryDelay seconds between attempts' {
            $script:attemptCount = 0

            $global:MCDWorkflowIsWinPE = $true
            $global:MCDWorkflowCurrentStepIndex = 0
            $global:MCDWorkflowContext = @{
                Window     = $null
                CurrentStep = $null
                LogsRoot    = $testLogsPath
                StatePath   = $testStatePath
                StartTime   = [datetime](Get-Date)
            }

            Invoke-MCDWorkflow -WorkflowObject $workflow

            Should -Invoke Start-Sleep -Times 1 -ParameterFilter { $Seconds -eq 5 }
        }
    }

    Context 'Fail-Fast' {
        BeforeEach {
            $workflow = @{
                id      = 'test-failfast'
                name    = 'Fail-Fast Test Workflow'
                version = '1.0.0'
                author  = 'Test'
                amd64   = $true
                arm64   = $true
                default = $true
                steps   = @(
                    @{
                        name        = 'Step 1'
                        description = 'First step'
                        command     = 'Write-Output'
                        args        = @('Step 1')
                        parameters  = @{}
                        rules       = @{
                            skip             = $false
                            runinfullos      = $false
                            runinwinpe       = $true
                            architecture     = @('amd64', 'arm64')
                            retry            = @{
                                enabled      = $false
                                maxAttempts  = 3
                                retryDelay   = 5
                            }
                            continueOnError = $false
                        }
                    },
                    @{
                        name        = 'Step 2'
                        description = 'Second step'
                        command     = 'Write-Output'
                        args        = @('Step 2')
                        parameters  = @{}
                        rules       = @{
                            skip             = $false
                            runinfullos      = $false
                            runinwinpe       = $true
                            architecture     = @('amd64', 'arm64')
                            retry            = @{
                                enabled      = $false
                                maxAttempts  = 3
                                retryDelay   = 5
                            }
                            continueOnError = $false
                        }
                    }
                )
            }

            Mock Update-MCDWinPEProgress {}
            Mock Write-MCDLog {}

            Mock Write-Output {
                param($InputObject)
                if ($InputObject -eq 'Step 1') {
                    throw "Test failure in Step 1"
                }
            }
        }

        It 'Should stop execution on failure when continueOnError is false' {
            $global:MCDWorkflowIsWinPE = $true
            $global:MCDWorkflowCurrentStepIndex = 0
            $global:MCDWorkflowContext = @{
                Window     = $null
                CurrentStep = $null
                LogsRoot    = $testLogsPath
                StatePath   = $testStatePath
                StartTime   = [datetime](Get-Date)
            }

            { Invoke-MCDWorkflow -WorkflowObject $workflow } | Should -Throw
        }
    }

    Context 'Continue On Error' {
        BeforeEach {
            $workflow = @{
                id      = 'test-continue'
                name    = 'Continue Test Workflow'
                version = '1.0.0'
                author  = 'Test'
                amd64   = $true
                arm64   = $true
                default = $true
                steps   = @(
                    @{
                        name        = 'Step 1'
                        description = 'First step'
                        command     = 'Write-Output'
                        args        = @('Step 1')
                        parameters  = @{}
                        rules       = @{
                            skip             = $false
                            runinfullos      = $false
                            runinwinpe       = $true
                            architecture     = @('amd64', 'arm64')
                            retry            = @{
                                enabled      = $false
                                maxAttempts  = 3
                                retryDelay   = 5
                            }
                            continueOnError = $true
                        }
                    },
                    @{
                        name        = 'Step 2'
                        description = 'Second step'
                        command     = 'Write-Output'
                        args        = @('Step 2')
                        parameters  = @{}
                        rules       = @{
                            skip             = $false
                            runinfullos      = $false
                            runinwinpe       = $true
                            architecture     = @('amd64', 'arm64')
                            retry            = @{
                                enabled      = $false
                                maxAttempts  = 3
                                retryDelay   = 5
                            }
                            continueOnError = $false
                        }
                    }
                )
            }

            Mock Update-MCDWinPEProgress {}
            Mock Write-MCDLog {}
            Mock Write-Warning {}
        }

        It 'Should continue to next step when continueOnError is true' {
            Mock Write-Output {
                param($InputObject)
                if ($InputObject -eq 'Step 1') {
                    throw "Test failure in Step 1"
                }
            }

            $global:MCDWorkflowIsWinPE = $true
            $global:MCDWorkflowCurrentStepIndex = 0
            $global:MCDWorkflowContext = @{
                Window     = $null
                CurrentStep = $null
                LogsRoot    = $testLogsPath
                StatePath   = $testStatePath
                StartTime   = [datetime](Get-Date)
            }

            Invoke-MCDWorkflow -WorkflowObject $workflow

            # Step 2 should execute despite Step 1 failure
            Should -Invoke Write-Output -Times 2
        }
    }

    Context 'Progress UI Updates' {
        BeforeEach {
            $workflow = @{
                id      = 'test-ui'
                name    = 'UI Test Workflow'
                version = '1.0.0'
                author  = 'Test'
                amd64   = $true
                arm64   = $true
                default = $true
                steps   = @(
                    @{
                        name        = 'Step 1'
                        description = 'First step'
                        command     = 'Write-Output'
                        args        = @('Step 1')
                        parameters  = @{}
                        rules       = @{
                            skip             = $false
                            runinfullos      = $false
                            runinwinpe       = $true
                            architecture     = @('amd64', 'arm64')
                            retry            = @{
                                enabled      = $false
                                maxAttempts  = 3
                                retryDelay   = 5
                            }
                            continueOnError = $false
                        }
                    },
                    @{
                        name        = 'Step 2'
                        description = 'Second step'
                        command     = 'Write-Output'
                        args        = @('Step 2')
                        parameters  = @{}
                        rules       = @{
                            skip             = $false
                            runinfullos      = $false
                            runinwinpe       = $true
                            architecture     = @('amd64', 'arm64')
                            retry            = @{
                                enabled      = $false
                                maxAttempts  = 3
                                retryDelay   = 5
                            }
                            continueOnError = $false
                        }
                    }
                )
            }

            Mock Write-MCDLog {}
        }

        It 'Should update progress UI with step name and progress' {
            $global:MCDWorkflowIsWinPE = $true
            $global:MCDWorkflowCurrentStepIndex = 0
            $global:MCDWorkflowContext = @{
                Window     = @{ Dispatcher = @{ Invoke = {} } }
                CurrentStep = $null
                LogsRoot    = $testLogsPath
                StatePath   = $testStatePath
                StartTime   = [datetime](Get-Date)
            }

            Invoke-MCDWorkflow -WorkflowObject $workflow

            Should -Invoke Update-MCDWinPEProgress -Times 2
        }
    }

    Context 'State Persistence' {
        BeforeEach {
            $workflow = @{
                id      = 'test-state'
                name    = 'State Test Workflow'
                version = '1.0.0'
                author  = 'Test'
                amd64   = $true
                arm64   = $true
                default = $true
                steps   = @(
                    @{
                        name        = 'Step 1'
                        description = 'First step'
                        command     = 'Write-Output'
                        args        = @('Step 1')
                        parameters  = @{}
                        rules       = @{
                            skip             = $false
                            runinfullos      = $false
                            runinwinpe       = $true
                            architecture     = @('amd64', 'arm64')
                            retry            = @{
                                enabled      = $false
                                maxAttempts  = 3
                                retryDelay   = 5
                            }
                            continueOnError = $false
                        }
                    }
                )
            }

            Mock Update-MCDWinPEProgress {}
            Mock Write-MCDLog {}
            Mock ConvertTo-Json {}
        }

        It 'Should persist state to C:\Windows\Temp\MCD\State.json' {
            Mock Out-File {}

            $global:MCDWorkflowIsWinPE = $true
            $global:MCDWorkflowCurrentStepIndex = 0
            $global:MCDWorkflowContext = @{
                Window     = $null
                CurrentStep = $null
                LogsRoot    = $testLogsPath
                StatePath   = $testStatePath
                StartTime   = [datetime](Get-Date)
            }

            Invoke-MCDWorkflow -WorkflowObject $workflow

            Should -Invoke Out-File -Times 1 -ParameterFilter {
                $FilePath -like '*Windows\Temp\MCD\State.json'
            }
        }
    }
}
