BeforeAll {
    $modulePath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    Import-Module $modulePath -Force

    # Setup test directories
    $testWorkflowsPath = Join-Path $TestDrive 'Workflows'
    $testStepsPath = Join-Path $TestDrive 'Steps'
    $testUsbPath = Join-Path $TestDrive 'USB'

    New-Item -Path $testWorkflowsPath -ItemType Directory -Force | Out-Null
    New-Item -Path $testStepsPath -ItemType Directory -Force | Out-Null
    New-Item -Path $testUsbPath -ItemType Directory -Force | Out-Null
}

AfterAll {
    Remove-Module MCD -Force
}

Describe 'Initialize-MCDWorkflowTasks' {

    Context 'Default Workflow Loading' {
        BeforeEach {
            # Create a valid default workflow
            $defaultWorkflow = @{
                id          = 'test-default-uuid'
                name        = 'Default Test Workflow'
                description = 'Test default workflow'
                version     = '1.0.0'
                author      = 'Test'
                amd64       = $true
                arm64       = $true
                default     = $true
                steps       = @(
                    @{
                        name        = 'Test Step 1'
                        description = 'Test step'
                        command     = 'Test-Step1'
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

            $workflowPath = Join-Path $testWorkflowsPath 'Default.json'
            $defaultWorkflow | ConvertTo-Json -Depth 10 | Out-File -FilePath $workflowPath -Encoding utf8
        }

        It 'Should load default workflow from module path' {
            # Mock the module path to point to test drive
            Mock Get-MyInvocation { @{
                MyCommand = @{
                    Module = @{
                        ModuleBase = $TestDrive
                    }
                }
            } }

            $result = Initialize-MCDWorkflowTasks -Name 'default'

            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -BeGreaterOrEqual 1
            $result[0].name | Should -Be 'Default Test Workflow'
        }

        It 'Should return workflow object with correct structure' {
            Mock Get-MyInvocation { @{
                MyCommand = @{
                    Module = @{
                        ModuleBase = $TestDrive
                    }
                }
            } }

            $result = Initialize-MCDWorkflowTasks -Name 'default'

            $result[0].PSObject.Properties.Name | Should -Contain 'id'
            $result[0].PSObject.Properties.Name | Should -Contain 'name'
            $result[0].PSObject.Properties.Name | Should -Contain 'steps'
            $result[0].steps | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Custom Workflow Loading from USB' {
        BeforeEach {
            # Create USB profile structure
            $profilePath = Join-Path $testUsbPath 'Profiles\TestProfile'
            $profileWorkflowPath = Join-Path $profilePath 'workflow.json'

            New-Item -Path $profilePath -ItemType Directory -Force | Out-Null

            $customWorkflow = @{
                id          = 'test-custom-uuid'
                name        = 'Custom Test Workflow'
                description = 'Test custom workflow'
                version     = '1.0.0'
                author      = 'Test'
                amd64       = $true
                arm64       = $false
                default     = $false
                steps       = @()
            }

            $customWorkflow | ConvertTo-Json -Depth 10 | Out-File -FilePath $profileWorkflowPath -Encoding utf8
        }

        It 'Should load custom workflows from USB profiles' {
            Mock Get-MCDExternalVolume { $testUsbPath }

            $result = Initialize-MCDWorkflowTasks -ProfileName 'TestProfile'

            $result | Should -Not -BeNullOrEmpty
            $result[0].name | Should -Be 'Custom Test Workflow'
        }
    }

    Context 'Architecture Filtering' {
        BeforeEach {
            # Create workflows with different architecture support
            $amd64Workflow = @{
                id      = 'test-amd64'
                name    = 'AMD64 Workflow'
                version = '1.0.0'
                author  = 'Test'
                amd64   = $true
                arm64   = $false
                default = $false
                steps   = @()
            }

            $arm64Workflow = @{
                id      = 'test-arm64'
                name    = 'ARM64 Workflow'
                version = '1.0.0'
                author  = 'Test'
                amd64   = $false
                arm64   = $true
                default = $false
                steps   = @()
            }

            $bothWorkflow = @{
                id      = 'test-both'
                name    = 'Both Workflow'
                version = '1.0.0'
                author  = 'Test'
                amd64   = $true
                arm64   = $true
                default = $false
                steps   = @()
            }

            $amd64Workflow | ConvertTo-Json -Depth 10 | Out-File -FilePath (Join-Path $testWorkflowsPath 'AMD64.json') -Encoding utf8
            $arm64Workflow | ConvertTo-Json -Depth 10 | Out-File -FilePath (Join-Path $testWorkflowsPath 'ARM64.json') -Encoding utf8
            $bothWorkflow | ConvertTo-Json -Depth 10 | Out-File -FilePath (Join-Path $testWorkflowsPath 'Both.json') -Encoding utf8
        }

        It 'Should filter workflows by amd64 architecture' {
            Mock Get-MyInvocation { @{
                MyCommand = @{
                    Module = @{
                        ModuleBase = $TestDrive
                    }
                }
            } }

            $result = Initialize-MCDWorkflowTasks -Architecture 'amd64'

            $result.Count | Should -Be 2
            $result.name | Should -Contain 'AMD64 Workflow'
            $result.name | Should -Contain 'Both Workflow'
            $result.name | Should -Not -Contain 'ARM64 Workflow'
        }

        It 'Should filter workflows by arm64 architecture' {
            Mock Get-MyInvocation { @{
                MyCommand = @{
                    Module = @{
                        ModuleBase = $TestDrive
                    }
                }
            } }

            $result = Initialize-MCDWorkflowTasks -Architecture 'arm64'

            $result.Count | Should -Be 2
            $result.name | Should -Contain 'ARM64 Workflow'
            $result.name | Should -Contain 'Both Workflow'
            $result.name | Should -Not -Contain 'AMD64 Workflow'
        }
    }

    Context 'Step Validation' {
        BeforeEach {
            # Create workflow with missing step
            $invalidWorkflow = @{
                id      = 'test-invalid'
                name    = 'Invalid Workflow'
                version = '1.0.0'
                author  = 'Test'
                amd64   = $true
                arm64   = $true
                default = $false
                steps   = @(
                    @{
                        name        = 'Missing Step'
                        description = 'Step with missing command'
                        command     = 'Invoke-MissingStep'
                        args        = @()
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
                    }
                )
            }

            $workflowPath = Join-Path $testWorkflowsPath 'Invalid.json'
            $invalidWorkflow | ConvertTo-Json -Depth 10 | Out-File -FilePath $workflowPath -Encoding utf8
        }

        It 'Should warn when step command does not exist' {
            Mock Get-MyInvocation { @{
                MyCommand = @{
                    Module = @{
                        ModuleBase = $TestDrive
                    }
                }
            } }

            Mock Test-Path { $false } -ParameterFilter { $Path -eq 'function:\Invoke-MissingStep' }

            $result = Initialize-MCDWorkflowTasks -Name 'invalid'

            # Should still return workflow but with warning
            $result | Should -Not -BeNullOrEmpty
            Should -Invoke Write-Warning
        }
    }

    Context 'Error Handling' {
        It 'Should handle missing workflow files gracefully' {
            Mock Get-MyInvocation { @{
                MyCommand = @{
                    Module = @{
                        ModuleBase = 'C:\NonExistent\Path'
                    }
                }
            } }

            Mock Test-Path { $false }

            $result = Initialize-MCDWorkflowTasks

            $result | Should -BeNullOrEmpty
            Should -Invoke Write-Warning
        }

        It 'Should handle invalid JSON gracefully' {
            Mock Get-MyInvocation { @{
                MyCommand = @{
                    Module = @{
                        ModuleBase = $TestDrive
                    }
                }
            } }

            $invalidJsonPath = Join-Path $testWorkflowsPath 'Invalid.json'
            '{ invalid json' | Out-File -FilePath $invalidJsonPath -Encoding utf8

            $result = Initialize-MCDWorkflowTasks -Name 'invalid'

            # Should skip invalid files
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Sorting' {
        BeforeEach {
            # Create multiple workflows
            $workflow1 = @{
                id      = 'workflow-1'
                name    = 'Zulu Workflow'
                version = '1.0.0'
                author  = 'Test'
                amd64   = $true
                arm64   = $true
                default = $false
                steps   = @()
            }

            $workflow2 = @{
                id      = 'workflow-2'
                name    = 'Alpha Workflow'
                version = '1.0.0'
                author  = 'Test'
                amd64   = $true
                arm64   = $true
                default = $false
                steps   = @()
            }

            $workflow3 = @{
                id      = 'workflow-3'
                name    = 'Default Workflow'
                version = '1.0.0'
                author  = 'Test'
                amd64   = $true
                arm64   = $true
                default = $true
                steps   = @()
            }

            $workflow1 | ConvertTo-Json -Depth 10 | Out-File -FilePath (Join-Path $testWorkflowsPath 'Zulu.json') -Encoding utf8
            $workflow2 | ConvertTo-Json -Depth 10 | Out-File -FilePath (Join-Path $testWorkflowsPath 'Alpha.json') -Encoding utf8
            $workflow3 | ConvertTo-Json -Depth 10 | Out-File -FilePath (Join-Path $testWorkflowsPath 'Default.json') -Encoding utf8
        }

        It 'Should sort workflows with default first, then by name' {
            Mock Get-MyInvocation { @{
                MyCommand = @{
                    Module = @{
                        ModuleBase = $TestDrive
                    }
                }
            } }

            $result = Initialize-MCDWorkflowTasks

            $result.Count | Should -Be 3
            $result[0].name | Should -Be 'Default Workflow'
            $result[1].name | Should -Be 'Alpha Workflow'
            $result[2].name | Should -Be 'Zulu Workflow'
        }
    }
}
