BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\.." | Convert-Path
    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }
    $script:moduleName = $ProjectName
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

Describe 'Initialize-MCDWorkflowTasks' {
    Context 'Loading default workflow from module' {
        It 'Returns at least one workflow when default workflows exist' {
            InModuleScope $script:moduleName {
                # Arrange: Create a mock default workflow in the module's Workflows directory
                $workflowsDir = Join-Path -Path $TestDrive -ChildPath 'Workflows'
                $null = New-Item -Path $workflowsDir -ItemType Directory -Force

                $defaultWorkflow = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'Default Deployment'
                    description = 'Standard cloud deployment workflow for Windows 11 Enterprise.'
                    version     = '1.0.0'
                    author      = 'MCD Team'
                    amd64       = $true
                    arm64       = $true
                    default     = $true
                    steps       = @(
                        @{
                            name        = 'Initialize Environment'
                            description = 'Prepare the WinPE environment for deployment.'
                            command     = 'Initialize-MCDEnvironment'
                            args        = @()
                            parameters  = @{ Verbose = $true }
                            rules       = @{
                                skip           = $false
                                runinfullos    = $false
                                runinwinpe     = $true
                                architecture   = @('amd64', 'arm64')
                                retry          = @{ enabled = $false }
                                continueOnError = $false
                            }
                        }
                    )
                } | ConvertTo-Json -Depth 10

                Set-Content -Path (Join-Path -Path $workflowsDir -ChildPath 'Default.json') -Value $defaultWorkflow -Encoding utf8

                Mock Get-MCDExecutionContext -MockWith {
                    [PSCustomObject]@{
                        ModuleBase = $TestDrive
                    }
                }

                # Act
                $workflows = Initialize-MCDWorkflowTasks

                # Assert
                $workflows | Should -Not -BeNullOrEmpty
                @($workflows).Count | Should -BeGreaterOrEqual 1
                @($workflows)[0].name | Should -Be 'Default Deployment'
            }
        }
    }

    Context 'Loading custom workflows from USB profiles' {
        It 'Returns custom workflows from USB profile directory' {
            InModuleScope $script:moduleName {
                # Arrange: Create a mock USB profile structure
                $profilesDir = Join-Path -Path $TestDrive -ChildPath 'MCD\Profiles\CustomProfile'
                $null = New-Item -Path $profilesDir -ItemType Directory -Force

                $customWorkflow = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'Custom Workflow'
                    description = 'A custom workflow for specialized deployment scenarios.'
                    version     = '1.0.0'
                    author      = 'Custom Author'
                    amd64       = $true
                    arm64       = $false
                    default     = $false
                    steps       = @(
                        @{
                            name        = 'Custom Step'
                            description = 'A custom deployment step.'
                            command     = 'Invoke-CustomStep'
                            args        = @()
                            parameters  = @{}
                            rules       = @{
                                skip           = $false
                                runinfullos    = $false
                                runinwinpe     = $true
                                architecture   = @('amd64')
                                retry          = @{ enabled = $false }
                                continueOnError = $false
                            }
                        }
                    )
                } | ConvertTo-Json -Depth 10

                Set-Content -Path (Join-Path -Path $profilesDir -ChildPath 'workflow.json') -Value $customWorkflow -Encoding utf8

                Mock Get-MCDExecutionContext -MockWith {
                    [PSCustomObject]@{
                        ModuleBase   = $TestDrive
                        ProfilesRoot = (Join-Path -Path $TestDrive -ChildPath 'MCD\Profiles')
                    }
                }

                # Empty default workflows
                $workflowsDir = Join-Path -Path $TestDrive -ChildPath 'Workflows'
                $null = New-Item -Path $workflowsDir -ItemType Directory -Force

                # Act
                $workflows = Initialize-MCDWorkflowTasks -ProfileName 'CustomProfile'

                # Assert
                $workflows | Should -Not -BeNullOrEmpty
                ($workflows | Where-Object { $_.name -eq 'Custom Workflow' }) | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'Filtering workflows by architecture' {
        It 'Returns only workflows matching the specified architecture (amd64)' {
            InModuleScope $script:moduleName {
                # Arrange
                $workflowsDir = Join-Path -Path $TestDrive -ChildPath 'Workflows'
                $null = New-Item -Path $workflowsDir -ItemType Directory -Force

                # Workflow for amd64 only
                $amd64Workflow = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'AMD64 Only'
                    description = 'A workflow that only supports AMD64 architecture.'
                    version     = '1.0.0'
                    author      = 'MCD Team'
                    amd64       = $true
                    arm64       = $false
                    default     = $false
                    steps       = @()
                } | ConvertTo-Json -Depth 10

                # Workflow for arm64 only
                $arm64Workflow = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'ARM64 Only'
                    description = 'A workflow that only supports ARM64 architecture.'
                    version     = '1.0.0'
                    author      = 'MCD Team'
                    amd64       = $false
                    arm64       = $true
                    default     = $false
                    steps       = @()
                } | ConvertTo-Json -Depth 10

                Set-Content -Path (Join-Path -Path $workflowsDir -ChildPath 'AMD64Only.json') -Value $amd64Workflow -Encoding utf8
                Set-Content -Path (Join-Path -Path $workflowsDir -ChildPath 'ARM64Only.json') -Value $arm64Workflow -Encoding utf8

                Mock Get-MCDExecutionContext -MockWith {
                    [PSCustomObject]@{
                        ModuleBase = $TestDrive
                    }
                }

                # Act
                $workflows = Initialize-MCDWorkflowTasks -Architecture 'amd64'

                # Assert
                $workflows | Should -Not -BeNullOrEmpty
                $workflows.name | Should -Contain 'AMD64 Only'
                $workflows.name | Should -Not -Contain 'ARM64 Only'
            }
        }

        It 'Returns only workflows matching the specified architecture (arm64)' {
            InModuleScope $script:moduleName {
                # Arrange
                $workflowsDir = Join-Path -Path $TestDrive -ChildPath 'Workflows'
                $null = New-Item -Path $workflowsDir -ItemType Directory -Force

                # Workflow for amd64 only
                $amd64Workflow = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'AMD64 Only'
                    description = 'A workflow that only supports AMD64 architecture.'
                    version     = '1.0.0'
                    author      = 'MCD Team'
                    amd64       = $true
                    arm64       = $false
                    default     = $false
                    steps       = @()
                } | ConvertTo-Json -Depth 10

                # Workflow for arm64 only
                $arm64Workflow = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'ARM64 Only'
                    description = 'A workflow that only supports ARM64 architecture.'
                    version     = '1.0.0'
                    author      = 'MCD Team'
                    amd64       = $false
                    arm64       = $true
                    default     = $false
                    steps       = @()
                } | ConvertTo-Json -Depth 10

                Set-Content -Path (Join-Path -Path $workflowsDir -ChildPath 'AMD64Only.json') -Value $amd64Workflow -Encoding utf8
                Set-Content -Path (Join-Path -Path $workflowsDir -ChildPath 'ARM64Only.json') -Value $arm64Workflow -Encoding utf8

                Mock Get-MCDExecutionContext -MockWith {
                    [PSCustomObject]@{
                        ModuleBase = $TestDrive
                    }
                }

                # Act
                $workflows = Initialize-MCDWorkflowTasks -Architecture 'arm64'

                # Assert
                $workflows | Should -Not -BeNullOrEmpty
                $workflows.name | Should -Contain 'ARM64 Only'
                $workflows.name | Should -Not -Contain 'AMD64 Only'
            }
        }
    }

    Context 'Validating step availability' {
        It 'Emits a warning when a step command is not available' {
            InModuleScope $script:moduleName {
                # Arrange
                $workflowsDir = Join-Path -Path $TestDrive -ChildPath 'Workflows'
                $null = New-Item -Path $workflowsDir -ItemType Directory -Force

                $workflowWithMissingStep = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'Workflow With Missing Step'
                    description = 'A workflow that references a non-existent command.'
                    version     = '1.0.0'
                    author      = 'MCD Team'
                    amd64       = $true
                    arm64       = $true
                    default     = $false
                    steps       = @(
                        @{
                            name        = 'Missing Step'
                            description = 'This step references a command that does not exist.'
                            command     = 'Invoke-NonExistentCommand'
                            args        = @()
                            parameters  = @{}
                            rules       = @{
                                skip           = $false
                                runinfullos    = $false
                                runinwinpe     = $true
                                architecture   = @('amd64', 'arm64')
                                retry          = @{ enabled = $false }
                                continueOnError = $false
                            }
                        }
                    )
                } | ConvertTo-Json -Depth 10

                Set-Content -Path (Join-Path -Path $workflowsDir -ChildPath 'MissingStep.json') -Value $workflowWithMissingStep -Encoding utf8

                Mock Get-MCDExecutionContext -MockWith {
                    [PSCustomObject]@{
                        ModuleBase = $TestDrive
                    }
                }

                Mock Get-Command -MockWith { $null }

                # Act & Assert
                $workflows = Initialize-MCDWorkflowTasks -WarningVariable capturedWarnings -WarningAction SilentlyContinue

                # Should not throw (graceful handling)
                $workflows | Should -Not -BeNullOrEmpty

                # Should emit a warning
                $capturedWarnings | Should -Not -BeNullOrEmpty
                $capturedWarnings | Should -Match 'Invoke-NonExistentCommand'
            }
        }

        It 'Does not fail when step command is missing, only warns' {
            InModuleScope $script:moduleName {
                # Arrange
                $workflowsDir = Join-Path -Path $TestDrive -ChildPath 'Workflows'
                $null = New-Item -Path $workflowsDir -ItemType Directory -Force

                $workflowWithMissingStep = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'Workflow With Missing Step'
                    description = 'A workflow that references a non-existent command.'
                    version     = '1.0.0'
                    author      = 'MCD Team'
                    amd64       = $true
                    arm64       = $true
                    default     = $false
                    steps       = @(
                        @{
                            name        = 'Missing Step'
                            description = 'This step references a command that does not exist.'
                            command     = 'Invoke-NonExistentCommand'
                            args        = @()
                            parameters  = @{}
                            rules       = @{
                                skip           = $false
                                runinfullos    = $false
                                runinwinpe     = $true
                                architecture   = @('amd64', 'arm64')
                                retry          = @{ enabled = $false }
                                continueOnError = $false
                            }
                        }
                    )
                } | ConvertTo-Json -Depth 10

                Set-Content -Path (Join-Path -Path $workflowsDir -ChildPath 'MissingStep.json') -Value $workflowWithMissingStep -Encoding utf8

                Mock Get-MCDExecutionContext -MockWith {
                    [PSCustomObject]@{
                        ModuleBase = $TestDrive
                    }
                }

                Mock Get-Command -MockWith { $null }

                # Act & Assert: Should not throw
                { Initialize-MCDWorkflowTasks -WarningAction SilentlyContinue } | Should -Not -Throw
            }
        }
    }

    Context 'Handling missing workflow files' {
        It 'Returns empty result when no workflow files exist' {
            InModuleScope $script:moduleName {
                # Arrange: Create empty Workflows directory
                $workflowsDir = Join-Path -Path $TestDrive -ChildPath 'Workflows'
                $null = New-Item -Path $workflowsDir -ItemType Directory -Force

                Mock Get-MCDExecutionContext -MockWith {
                    [PSCustomObject]@{
                        ModuleBase = $TestDrive
                    }
                }

                # Act
                $workflows = Initialize-MCDWorkflowTasks

                # Assert
                $workflows | Should -BeNullOrEmpty
            }
        }

        It 'Does not throw when Workflows directory does not exist' {
            InModuleScope $script:moduleName {
                # Arrange: Point to empty directory (no Workflows subfolder)
                Mock Get-MCDExecutionContext -MockWith {
                    [PSCustomObject]@{
                        ModuleBase = $TestDrive
                    }
                }

                # Act & Assert
                { Initialize-MCDWorkflowTasks } | Should -Not -Throw
            }
        }
    }

    Context 'Handling invalid JSON' {
        It 'Skips workflow files with invalid JSON and emits a warning' {
            InModuleScope $script:moduleName {
                # Arrange
                $workflowsDir = Join-Path -Path $TestDrive -ChildPath 'Workflows'
                $null = New-Item -Path $workflowsDir -ItemType Directory -Force

                # Valid workflow
                $validWorkflow = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'Valid Workflow'
                    description = 'A valid workflow that should be loaded successfully.'
                    version     = '1.0.0'
                    author      = 'MCD Team'
                    amd64       = $true
                    arm64       = $true
                    default     = $false
                    steps       = @()
                } | ConvertTo-Json -Depth 10

                Set-Content -Path (Join-Path -Path $workflowsDir -ChildPath 'Valid.json') -Value $validWorkflow -Encoding utf8

                # Invalid JSON file
                Set-Content -Path (Join-Path -Path $workflowsDir -ChildPath 'Invalid.json') -Value '{ invalid json content' -Encoding utf8

                Mock Get-MCDExecutionContext -MockWith {
                    [PSCustomObject]@{
                        ModuleBase = $TestDrive
                    }
                }

                # Act
                $workflows = Initialize-MCDWorkflowTasks -WarningVariable capturedWarnings -WarningAction SilentlyContinue

                # Assert: Valid workflow loaded, invalid skipped
                $workflows | Should -Not -BeNullOrEmpty
                $workflows.name | Should -Contain 'Valid Workflow'

                # Assert: Warning emitted for invalid JSON
                $capturedWarnings | Should -Not -BeNullOrEmpty
                $capturedWarnings | Should -Match 'Invalid.json'
            }
        }

        It 'Does not throw when encountering invalid JSON' {
            InModuleScope $script:moduleName {
                # Arrange
                $workflowsDir = Join-Path -Path $TestDrive -ChildPath 'Workflows'
                $null = New-Item -Path $workflowsDir -ItemType Directory -Force

                # Invalid JSON only
                Set-Content -Path (Join-Path -Path $workflowsDir -ChildPath 'Invalid.json') -Value '{ invalid json content' -Encoding utf8

                Mock Get-MCDExecutionContext -MockWith {
                    [PSCustomObject]@{
                        ModuleBase = $TestDrive
                    }
                }

                # Act & Assert
                { Initialize-MCDWorkflowTasks -WarningAction SilentlyContinue } | Should -Not -Throw
            }
        }
    }

    Context 'Workflow sorting' {
        It 'Returns workflows sorted with default workflow first, then by name' {
            InModuleScope $script:moduleName {
                # Arrange
                $workflowsDir = Join-Path -Path $TestDrive -ChildPath 'Workflows'
                $null = New-Item -Path $workflowsDir -ItemType Directory -Force

                # Create workflows in non-sorted order
                $workflowZ = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'Zebra Workflow'
                    description = 'A workflow starting with Z to test sorting behavior.'
                    version     = '1.0.0'
                    author      = 'MCD Team'
                    amd64       = $true
                    arm64       = $true
                    default     = $false
                    steps       = @()
                } | ConvertTo-Json -Depth 10

                $workflowA = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'Alpha Workflow'
                    description = 'A workflow starting with A to test sorting behavior.'
                    version     = '1.0.0'
                    author      = 'MCD Team'
                    amd64       = $true
                    arm64       = $true
                    default     = $false
                    steps       = @()
                } | ConvertTo-Json -Depth 10

                $defaultWorkflow = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'Default Deployment'
                    description = 'Standard cloud deployment workflow for Windows 11 Enterprise.'
                    version     = '1.0.0'
                    author      = 'MCD Team'
                    amd64       = $true
                    arm64       = $true
                    default     = $true
                    steps       = @()
                } | ConvertTo-Json -Depth 10

                Set-Content -Path (Join-Path -Path $workflowsDir -ChildPath 'Zebra.json') -Value $workflowZ -Encoding utf8
                Set-Content -Path (Join-Path -Path $workflowsDir -ChildPath 'Alpha.json') -Value $workflowA -Encoding utf8
                Set-Content -Path (Join-Path -Path $workflowsDir -ChildPath 'Default.json') -Value $defaultWorkflow -Encoding utf8

                Mock Get-MCDExecutionContext -MockWith {
                    [PSCustomObject]@{
                        ModuleBase = $TestDrive
                    }
                }

                # Act
                $workflows = Initialize-MCDWorkflowTasks

                # Assert: Default first
                @($workflows)[0].default | Should -BeTrue
                @($workflows)[0].name | Should -Be 'Default Deployment'

                # Assert: Remaining sorted by name
                $nonDefaultWorkflows = $workflows | Select-Object -Skip 1
                $nonDefaultWorkflows[0].name | Should -Be 'Alpha Workflow'
                $nonDefaultWorkflows[1].name | Should -Be 'Zebra Workflow'
            }
        }
    }
}
