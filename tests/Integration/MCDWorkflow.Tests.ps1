BeforeAll {
    $projectPath = "$PSScriptRoot\.." | Convert-Path
    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }
    $script:moduleName = $ProjectName

    # Load WPF assemblies before module import to enable mocking of functions
    # that use [System.Windows.Window] type in their signatures
    Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase -ErrorAction SilentlyContinue

    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

Describe 'MCD Workflow Integration Tests' -Tag 'Integration' {
    Context 'Default workflow loads from module' {
        It 'Initialize-MCDWorkflowTasks returns at least one workflow' {
            InModuleScope $script:moduleName {
                # Arrange
                Mock Get-MCDExecutionContext -MockWith {
                    [PSCustomObject]@{
                        ModuleBase   = (Get-Module MCD).ModuleBase
                        ProfilesRoot = $TestDrive
                        IsWinPE      = $false
                        Architecture = 'amd64'
                    }
                }

                # Act
                $workflows = Initialize-MCDWorkflowTasks

                # Assert
                $workflows | Should -Not -BeNullOrEmpty
                @($workflows).Count | Should -BeGreaterOrEqual 1
            }
        }

        It 'Default workflow has required properties' {
            InModuleScope $script:moduleName {
                # Arrange
                Mock Get-MCDExecutionContext -MockWith {
                    [PSCustomObject]@{
                        ModuleBase   = (Get-Module MCD).ModuleBase
                        ProfilesRoot = $TestDrive
                        IsWinPE      = $false
                        Architecture = 'amd64'
                    }
                }

                # Act
                $workflows = Initialize-MCDWorkflowTasks
                $defaultWorkflow = $workflows | Where-Object { $_.default -eq $true } | Select-Object -First 1

                # Assert
                $defaultWorkflow | Should -Not -BeNullOrEmpty
                $defaultWorkflow.name | Should -Not -BeNullOrEmpty
                $defaultWorkflow.steps | Should -Not -BeNullOrEmpty
                @($defaultWorkflow.steps).Count | Should -BeGreaterOrEqual 1
            }
        }

        It 'Default workflow steps have valid structure' {
            InModuleScope $script:moduleName {
                # Arrange
                Mock Get-MCDExecutionContext -MockWith {
                    [PSCustomObject]@{
                        ModuleBase   = (Get-Module MCD).ModuleBase
                        ProfilesRoot = $TestDrive
                        IsWinPE      = $false
                        Architecture = 'amd64'
                    }
                }

                # Act
                $workflows = Initialize-MCDWorkflowTasks
                $defaultWorkflow = $workflows | Where-Object { $_.default -eq $true } | Select-Object -First 1

                # Assert
                foreach ($step in $defaultWorkflow.steps)
                {
                    $step.name | Should -Not -BeNullOrEmpty -Because "Step name is required"
                    $step.command | Should -Not -BeNullOrEmpty -Because "Step command is required"
                    $step.rules | Should -Not -BeNullOrEmpty -Because "Step rules are required"
                }
            }
        }
    }

    Context 'Custom workflow detection on USB' {
        It 'Detects custom workflow from USB profile directory' {
            InModuleScope $script:moduleName {
                # Arrange: Create a mock USB profile with a custom workflow
                $profilesRoot = Join-Path -Path $TestDrive -ChildPath 'Profiles'
                $customProfilePath = Join-Path -Path $profilesRoot -ChildPath 'CustomProfile'
                New-Item -Path $customProfilePath -ItemType Directory -Force | Out-Null

                $customWorkflow = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'Custom USB Workflow'
                    description = 'A custom workflow loaded from USB profile.'
                    version     = '1.0.0'
                    author      = 'Test'
                    amd64       = $true
                    arm64       = $true
                    default     = $false
                    steps       = @(
                        @{
                            name        = 'Custom Step'
                            description = 'A custom step from USB.'
                            command     = 'Write-Output'
                            args        = @('Custom step executed')
                            parameters  = @{}
                            rules       = @{
                                skip            = $false
                                runinfullos     = $true
                                runinwinpe      = $true
                                architecture    = @('amd64', 'arm64')
                                retry           = @{ enabled = $false }
                                continueOnError = $false
                            }
                        }
                    )
                }
                $workflowPath = Join-Path -Path $customProfilePath -ChildPath 'workflow.json'
                $customWorkflow | ConvertTo-Json -Depth 10 | Set-Content -Path $workflowPath -Encoding UTF8

                Mock Get-MCDExecutionContext -MockWith {
                    [PSCustomObject]@{
                        ModuleBase   = (Get-Module MCD).ModuleBase
                        ProfilesRoot = $profilesRoot
                        IsWinPE      = $false
                        Architecture = 'amd64'
                    }
                }

                # Act
                $workflows = Initialize-MCDWorkflowTasks -ProfileName 'CustomProfile'

                # Assert
                $customWorkflowFound = $workflows | Where-Object { $_.name -eq 'Custom USB Workflow' }
                $customWorkflowFound | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'Workflow execution end-to-end' {
        It 'Executes a simple workflow successfully' {
            InModuleScope $script:moduleName {
                # Arrange
                $script:testStepExecuted = $false

                function Invoke-IntegrationTestStep
                {
                    $script:testStepExecuted = $true
                }

                $workflow = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'Integration Test Workflow'
                    description = 'A workflow for integration testing.'
                    version     = '1.0.0'
                    author      = 'MCD Test'
                    amd64       = $true
                    arm64       = $true
                    default     = $false
                    steps       = @(
                        @{
                            name        = 'Integration Test Step'
                            description = 'A simple test step.'
                            command     = 'Invoke-IntegrationTestStep'
                            args        = @()
                            parameters  = @{}
                            rules       = @{
                                skip            = $false
                                runinfullos     = $true
                                runinwinpe      = $true
                                architecture    = @('amd64', 'arm64')
                                retry           = @{ enabled = $false }
                                continueOnError = $false
                            }
                        }
                    )
                }

                Mock Get-MCDExecutionContext -MockWith {
                    [PSCustomObject]@{
                        IsWinPE      = $false
                        Architecture = 'amd64'
                        StateRoot    = $TestDrive
                        LogsRoot     = $TestDrive
                    }
                }

                Mock Write-MCDLog -MockWith {}

                # Act
                Invoke-MCDWorkflow -WorkflowObject $workflow

                # Assert
                $script:testStepExecuted | Should -Be $true
            }
        }

        It 'Executes workflow with retry and eventually succeeds' {
            InModuleScope $script:moduleName {
                # Arrange
                $script:attemptCount = 0

                function Invoke-IntegrationRetryStep
                {
                    $script:attemptCount++
                    if ($script:attemptCount -lt 2)
                    {
                        throw 'First attempt fails'
                    }
                }

                $workflow = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'Retry Integration Workflow'
                    description = 'A workflow that tests retry in integration.'
                    version     = '1.0.0'
                    author      = 'MCD Test'
                    amd64       = $true
                    arm64       = $true
                    default     = $false
                    steps       = @(
                        @{
                            name        = 'Retry Integration Step'
                            description = 'A step that fails first then succeeds.'
                            command     = 'Invoke-IntegrationRetryStep'
                            args        = @()
                            parameters  = @{}
                            rules       = @{
                                skip            = $false
                                runinfullos     = $true
                                runinwinpe      = $true
                                architecture    = @('amd64', 'arm64')
                                retry           = @{
                                    enabled     = $true
                                    maxAttempts = 3
                                    retryDelay  = 1
                                }
                                continueOnError = $false
                            }
                        }
                    )
                }

                Mock Get-MCDExecutionContext -MockWith {
                    [PSCustomObject]@{
                        IsWinPE      = $false
                        Architecture = 'amd64'
                        StateRoot    = $TestDrive
                        LogsRoot     = $TestDrive
                    }
                }

                Mock Start-Sleep -MockWith {}
                Mock Write-MCDLog -MockWith {}

                # Act
                Invoke-MCDWorkflow -WorkflowObject $workflow

                # Assert
                $script:attemptCount | Should -Be 2
            }
        }
    }

    Context 'State persistence' {
        It 'Persists state file after workflow execution' {
            InModuleScope $script:moduleName {
                # Arrange
                function Invoke-IntegrationStateStep
                {
                    # No-op
                }

                $workflow = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'State Persistence Integration Workflow'
                    description = 'A workflow that tests state persistence.'
                    version     = '1.0.0'
                    author      = 'MCD Test'
                    amd64       = $true
                    arm64       = $true
                    default     = $false
                    steps       = @(
                        @{
                            name        = 'State Integration Step'
                            description = 'A step for state testing.'
                            command     = 'Invoke-IntegrationStateStep'
                            args        = @()
                            parameters  = @{}
                            rules       = @{
                                skip            = $false
                                runinfullos     = $true
                                runinwinpe      = $true
                                architecture    = @('amd64', 'arm64')
                                retry           = @{ enabled = $false }
                                continueOnError = $false
                            }
                        }
                    )
                }

                Mock Get-MCDExecutionContext -MockWith {
                    [PSCustomObject]@{
                        IsWinPE      = $false
                        Architecture = 'amd64'
                        StateRoot    = $TestDrive
                        LogsRoot     = $TestDrive
                    }
                }

                # Mock Set-Content to capture calls
                $script:statePathCaptured = $null
                Mock Set-Content -MockWith {
                    $script:statePathCaptured = $Path
                }
                Mock Test-Path -MockWith { $true } -ParameterFilter { $Path -eq 'C:\Windows\Temp\MCD' }
                Mock Write-MCDLog -MockWith {}

                # Act
                Invoke-MCDWorkflow -WorkflowObject $workflow

                # Assert
                $script:statePathCaptured | Should -Be 'C:\Windows\Temp\MCD\State.json'
            }
        }
    }

    Context 'Fail-fast behavior' {
        It 'Stops execution on step failure when continueOnError is false' {
            InModuleScope $script:moduleName {
                # Arrange
                $script:stepsExecuted = @()

                function Invoke-IntegrationFailStep
                {
                    $script:stepsExecuted += 'Fail'
                    throw 'Intentional failure for fail-fast test'
                }

                function Invoke-IntegrationAfterFailStep
                {
                    $script:stepsExecuted += 'AfterFail'
                }

                $workflow = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'Fail-Fast Integration Workflow'
                    description = 'A workflow that tests fail-fast behavior.'
                    version     = '1.0.0'
                    author      = 'MCD Test'
                    amd64       = $true
                    arm64       = $true
                    default     = $false
                    steps       = @(
                        @{
                            name        = 'Fail Integration Step'
                            description = 'A step that fails.'
                            command     = 'Invoke-IntegrationFailStep'
                            args        = @()
                            parameters  = @{}
                            rules       = @{
                                skip            = $false
                                runinfullos     = $true
                                runinwinpe      = $true
                                architecture    = @('amd64', 'arm64')
                                retry           = @{ enabled = $false }
                                continueOnError = $false
                            }
                        }
                        @{
                            name        = 'After Fail Integration Step'
                            description = 'A step that should not run.'
                            command     = 'Invoke-IntegrationAfterFailStep'
                            args        = @()
                            parameters  = @{}
                            rules       = @{
                                skip            = $false
                                runinfullos     = $true
                                runinwinpe      = $true
                                architecture    = @('amd64', 'arm64')
                                retry           = @{ enabled = $false }
                                continueOnError = $false
                            }
                        }
                    )
                }

                Mock Get-MCDExecutionContext -MockWith {
                    [PSCustomObject]@{
                        IsWinPE      = $false
                        Architecture = 'amd64'
                        StateRoot    = $TestDrive
                        LogsRoot     = $TestDrive
                    }
                }

                Mock Write-MCDLog -MockWith {}

                # Act & Assert
                { Invoke-MCDWorkflow -WorkflowObject $workflow } | Should -Throw

                # Assert: Only the first step should have run
                $script:stepsExecuted | Should -Be @('Fail')
                $script:stepsExecuted | Should -Not -Contain 'AfterFail'
            }
        }
    }

    Context 'UI progress updates' {
        It 'Calls Update-MCDWinPEProgress when Window is provided' {
            InModuleScope $script:moduleName {
                # Arrange
                function Invoke-IntegrationProgressStep
                {
                    # No-op
                }

                $workflow = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'Progress Integration Workflow'
                    description = 'A workflow that tests progress updates.'
                    version     = '1.0.0'
                    author      = 'MCD Test'
                    amd64       = $true
                    arm64       = $true
                    default     = $false
                    steps       = @(
                        @{
                            name        = 'Progress Integration Step'
                            description = 'A step for progress testing.'
                            command     = 'Invoke-IntegrationProgressStep'
                            args        = @()
                            parameters  = @{}
                            rules       = @{
                                skip            = $false
                                runinfullos     = $true
                                runinwinpe      = $true
                                architecture    = @('amd64', 'arm64')
                                retry           = @{ enabled = $false }
                                continueOnError = $false
                            }
                        }
                    )
                }

                $mockWindow = [PSCustomObject]@{}

                Mock Get-MCDExecutionContext -MockWith {
                    [PSCustomObject]@{
                        IsWinPE      = $true
                        Architecture = 'amd64'
                        StateRoot    = $TestDrive
                        LogsRoot     = $TestDrive
                    }
                }

                Mock Update-MCDWinPEProgress -MockWith {}
                Mock Write-MCDLog -MockWith {}

                # Act
                Invoke-MCDWorkflow -WorkflowObject $workflow -Window $mockWindow

                # Assert
                Should -Invoke Update-MCDWinPEProgress -Times 1 -Exactly
            }
        }
    }

    Context 'WinPE deployment integration' {
        It 'Invoke-MCDWinPEDeployment uses Invoke-MCDWorkflow with selection workflow' {
            InModuleScope $script:moduleName {
                # Arrange: Create a real WPF Window using XAML (same pattern as unit tests)
                $xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <StackPanel>
    <TextBlock x:Name="StepCounterText" />
    <TextBlock x:Name="CurrentStepText" />
    <ProgressBar x:Name="DeploymentProgressBar" />
    <TextBlock x:Name="ProgressPercentText" />
  </StackPanel>
</Window>
'@
                $reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
                $testWindow = [Windows.Markup.XamlReader]::Load($reader)

                $testWorkflow = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'WinPE Deploy Test Workflow'
                    description = 'A workflow for WinPE deployment testing.'
                    version     = '1.0.0'
                    author      = 'MCD Test'
                    amd64       = $true
                    arm64       = $true
                    default     = $true
                    steps       = @()
                }

                $selection = [PSCustomObject]@{
                    OperatingSystem  = [PSCustomObject]@{ DisplayName = 'Windows 11 Pro' }
                    ComputerLanguage = 'en-US'
                    DriverPack       = 'None'
                    Workflow         = $testWorkflow
                }

                Mock Write-MCDLog -MockWith {}
                Mock Update-MCDWinPEProgress -MockWith {}
                Mock Invoke-MCDWorkflow -MockWith {}

                # Act
                Invoke-MCDWinPEDeployment -Selection $selection -Window $testWindow

                # Assert
                Should -Invoke Invoke-MCDWorkflow -ParameterFilter { $WorkflowObject.name -eq 'WinPE Deploy Test Workflow' } -Times 1
            }
        }
    }
}
