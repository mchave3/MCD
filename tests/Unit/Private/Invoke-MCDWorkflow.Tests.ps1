BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\.." | Convert-Path
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

Describe 'Invoke-MCDWorkflow' {
    Context 'Sequential execution of steps' {
        It 'Executes steps in the order they appear in the workflow' {
            InModuleScope $script:moduleName {
                # Arrange
                $script:executionOrder = @()

                function Invoke-TestStepOne
                {
                    $script:executionOrder += 'StepOne'
                }

                function Invoke-TestStepTwo
                {
                    $script:executionOrder += 'StepTwo'
                }

                function Invoke-TestStepThree
                {
                    $script:executionOrder += 'StepThree'
                }

                $workflow = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'Sequential Test Workflow'
                    description = 'A workflow that tests sequential execution of steps.'
                    version     = '1.0.0'
                    author      = 'MCD Team'
                    amd64       = $true
                    arm64       = $true
                    default     = $false
                    steps       = @(
                        @{
                            name        = 'Step One'
                            description = 'First step in the sequence.'
                            command     = 'Invoke-TestStepOne'
                            args        = @()
                            parameters  = @{}
                            rules       = @{
                                skip            = $false
                                runinfullos     = $false
                                runinwinpe      = $true
                                architecture    = @('amd64', 'arm64')
                                retry           = @{ enabled = $false }
                                continueOnError = $false
                            }
                        }
                        @{
                            name        = 'Step Two'
                            description = 'Second step in the sequence.'
                            command     = 'Invoke-TestStepTwo'
                            args        = @()
                            parameters  = @{}
                            rules       = @{
                                skip            = $false
                                runinfullos     = $false
                                runinwinpe      = $true
                                architecture    = @('amd64', 'arm64')
                                retry           = @{ enabled = $false }
                                continueOnError = $false
                            }
                        }
                        @{
                            name        = 'Step Three'
                            description = 'Third step in the sequence.'
                            command     = 'Invoke-TestStepThree'
                            args        = @()
                            parameters  = @{}
                            rules       = @{
                                skip            = $false
                                runinfullos     = $false
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
                        IsWinPE      = $true
                        Architecture = 'amd64'
                        StateRoot    = $TestDrive
                        LogsRoot     = $TestDrive
                    }
                }

                Mock Update-MCDWinPEProgress -MockWith {}
                Mock Write-MCDLog -MockWith {}

                # Act
                Invoke-MCDWorkflow -WorkflowObject $workflow

                # Assert
                $script:executionOrder | Should -Be @('StepOne', 'StepTwo', 'StepThree')
            }
        }
    }

    Context 'Skip rule: rules.skip = true' {
        It 'Skips steps where rules.skip is true' {
            InModuleScope $script:moduleName {
                # Arrange
                $script:executedSteps = @()

                function Invoke-TestExecutedStep
                {
                    $script:executedSteps += 'Executed'
                }

                function Invoke-TestSkippedStep
                {
                    $script:executedSteps += 'Skipped'
                }

                $workflow = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'Skip Test Workflow'
                    description = 'A workflow that tests the skip rule behavior.'
                    version     = '1.0.0'
                    author      = 'MCD Team'
                    amd64       = $true
                    arm64       = $true
                    default     = $false
                    steps       = @(
                        @{
                            name        = 'Executed Step'
                            description = 'This step should be executed.'
                            command     = 'Invoke-TestExecutedStep'
                            args        = @()
                            parameters  = @{}
                            rules       = @{
                                skip            = $false
                                runinfullos     = $false
                                runinwinpe      = $true
                                architecture    = @('amd64', 'arm64')
                                retry           = @{ enabled = $false }
                                continueOnError = $false
                            }
                        }
                        @{
                            name        = 'Skipped Step'
                            description = 'This step should be skipped.'
                            command     = 'Invoke-TestSkippedStep'
                            args        = @()
                            parameters  = @{}
                            rules       = @{
                                skip            = $true
                                runinfullos     = $false
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
                        IsWinPE      = $true
                        Architecture = 'amd64'
                        StateRoot    = $TestDrive
                        LogsRoot     = $TestDrive
                    }
                }

                Mock Update-MCDWinPEProgress -MockWith {}
                Mock Write-MCDLog -MockWith {}

                # Act
                Invoke-MCDWorkflow -WorkflowObject $workflow

                # Assert
                $script:executedSteps | Should -Be @('Executed')
                $script:executedSteps | Should -Not -Contain 'Skipped'
            }
        }
    }

    Context 'Skip by architecture mismatch (rules.architecture)' {
        It 'Skips steps that do not match the current architecture' {
            InModuleScope $script:moduleName {
                # Arrange
                $script:executedSteps = @()

                function Invoke-TestAmd64Step
                {
                    $script:executedSteps += 'amd64'
                }

                function Invoke-TestArm64Step
                {
                    $script:executedSteps += 'arm64'
                }

                $workflow = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'Architecture Filter Workflow'
                    description = 'A workflow that tests architecture filtering.'
                    version     = '1.0.0'
                    author      = 'MCD Team'
                    amd64       = $true
                    arm64       = $true
                    default     = $false
                    steps       = @(
                        @{
                            name        = 'AMD64 Only Step'
                            description = 'This step runs only on AMD64.'
                            command     = 'Invoke-TestAmd64Step'
                            args        = @()
                            parameters  = @{}
                            rules       = @{
                                skip            = $false
                                runinfullos     = $false
                                runinwinpe      = $true
                                architecture    = @('amd64')
                                retry           = @{ enabled = $false }
                                continueOnError = $false
                            }
                        }
                        @{
                            name        = 'ARM64 Only Step'
                            description = 'This step runs only on ARM64.'
                            command     = 'Invoke-TestArm64Step'
                            args        = @()
                            parameters  = @{}
                            rules       = @{
                                skip            = $false
                                runinfullos     = $false
                                runinwinpe      = $true
                                architecture    = @('arm64')
                                retry           = @{ enabled = $false }
                                continueOnError = $false
                            }
                        }
                    )
                }

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
                Invoke-MCDWorkflow -WorkflowObject $workflow

                # Assert
                $script:executedSteps | Should -Be @('amd64')
                $script:executedSteps | Should -Not -Contain 'arm64'
            }
        }
    }

    Context 'Validate step exists before execution' {
        It 'Throws an error when step command does not exist' {
            InModuleScope $script:moduleName {
                # Arrange
                $workflow = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'Missing Command Workflow'
                    description = 'A workflow that references a non-existent command.'
                    version     = '1.0.0'
                    author      = 'MCD Team'
                    amd64       = $true
                    arm64       = $true
                    default     = $false
                    steps       = @(
                        @{
                            name        = 'Missing Command Step'
                            description = 'This step references a non-existent command.'
                            command     = 'Invoke-NonExistentTestCommand'
                            args        = @()
                            parameters  = @{}
                            rules       = @{
                                skip            = $false
                                runinfullos     = $false
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
                        IsWinPE      = $true
                        Architecture = 'amd64'
                        StateRoot    = $TestDrive
                        LogsRoot     = $TestDrive
                    }
                }

                Mock Get-Command -MockWith { $null } -ParameterFilter { $Name -eq 'Invoke-NonExistentTestCommand' }
                Mock Update-MCDWinPEProgress -MockWith {}
                Mock Write-MCDLog -MockWith {}

                # Act & Assert: Should throw about missing step command (not CommandNotFoundException for Invoke-MCDWorkflow)
                { Invoke-MCDWorkflow -WorkflowObject $workflow } | Should -Throw -ExpectedMessage '*Invoke-NonExistentTestCommand*'
            }
        }
    }

    Context 'Args array passed correctly' {
        It 'Passes args array as positional arguments to the step command' {
            InModuleScope $script:moduleName {
                # Arrange
                $script:receivedArgs = @()

                function Invoke-TestArgsStep
                {
                    param(
                        [Parameter(Position = 0)]
                        [string]$FirstArg,

                        [Parameter(Position = 1)]
                        [string]$SecondArg
                    )

                    $script:receivedArgs = @($FirstArg, $SecondArg)
                }

                $workflow = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'Args Test Workflow'
                    description = 'A workflow that tests positional argument passing.'
                    version     = '1.0.0'
                    author      = 'MCD Team'
                    amd64       = $true
                    arm64       = $true
                    default     = $false
                    steps       = @(
                        @{
                            name        = 'Args Step'
                            description = 'This step receives positional arguments.'
                            command     = 'Invoke-TestArgsStep'
                            args        = @('ValueOne', 'ValueTwo')
                            parameters  = @{}
                            rules       = @{
                                skip            = $false
                                runinfullos     = $false
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
                        IsWinPE      = $true
                        Architecture = 'amd64'
                        StateRoot    = $TestDrive
                        LogsRoot     = $TestDrive
                    }
                }

                Mock Update-MCDWinPEProgress -MockWith {}
                Mock Write-MCDLog -MockWith {}

                # Act
                Invoke-MCDWorkflow -WorkflowObject $workflow

                # Assert
                $script:receivedArgs | Should -Be @('ValueOne', 'ValueTwo')
            }
        }
    }

    Context 'Parameters object passed correctly (splat)' {
        It 'Passes parameters object as named parameters to the step command' {
            InModuleScope $script:moduleName {
                # Arrange
                $script:receivedParams = @{}

                function Invoke-TestParamsStep
                {
                    param(
                        [Parameter()]
                        [string]$ParamOne,

                        [Parameter()]
                        [int]$ParamTwo
                    )

                    $script:receivedParams = @{
                        ParamOne = $ParamOne
                        ParamTwo = $ParamTwo
                    }
                }

                $workflow = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'Parameters Test Workflow'
                    description = 'A workflow that tests named parameter splatting.'
                    version     = '1.0.0'
                    author      = 'MCD Team'
                    amd64       = $true
                    arm64       = $true
                    default     = $false
                    steps       = @(
                        @{
                            name        = 'Parameters Step'
                            description = 'This step receives named parameters.'
                            command     = 'Invoke-TestParamsStep'
                            args        = @()
                            parameters  = @{
                                ParamOne = 'TestValue'
                                ParamTwo = 42
                            }
                            rules       = @{
                                skip            = $false
                                runinfullos     = $false
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
                        IsWinPE      = $true
                        Architecture = 'amd64'
                        StateRoot    = $TestDrive
                        LogsRoot     = $TestDrive
                    }
                }

                Mock Update-MCDWinPEProgress -MockWith {}
                Mock Write-MCDLog -MockWith {}

                # Act
                Invoke-MCDWorkflow -WorkflowObject $workflow

                # Assert
                $script:receivedParams.ParamOne | Should -Be 'TestValue'
                $script:receivedParams.ParamTwo | Should -Be 42
            }
        }
    }

    Context 'Args + parameters together' {
        It 'Passes both positional args and named parameters correctly' {
            InModuleScope $script:moduleName {
                # Arrange
                $script:receivedValues = @{}

                function Invoke-TestCombinedStep
                {
                    param(
                        [Parameter(Position = 0)]
                        [string]$PositionalArg,

                        [Parameter()]
                        [string]$NamedParam
                    )

                    $script:receivedValues = @{
                        PositionalArg = $PositionalArg
                        NamedParam    = $NamedParam
                    }
                }

                $workflow = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'Combined Args and Params Workflow'
                    description = 'A workflow that tests both args and parameters together.'
                    version     = '1.0.0'
                    author      = 'MCD Team'
                    amd64       = $true
                    arm64       = $true
                    default     = $false
                    steps       = @(
                        @{
                            name        = 'Combined Step'
                            description = 'This step receives both args and params.'
                            command     = 'Invoke-TestCombinedStep'
                            args        = @('PositionalValue')
                            parameters  = @{
                                NamedParam = 'NamedValue'
                            }
                            rules       = @{
                                skip            = $false
                                runinfullos     = $false
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
                        IsWinPE      = $true
                        Architecture = 'amd64'
                        StateRoot    = $TestDrive
                        LogsRoot     = $TestDrive
                    }
                }

                Mock Update-MCDWinPEProgress -MockWith {}
                Mock Write-MCDLog -MockWith {}

                # Act
                Invoke-MCDWorkflow -WorkflowObject $workflow

                # Assert
                $script:receivedValues.PositionalArg | Should -Be 'PositionalValue'
                $script:receivedValues.NamedParam | Should -Be 'NamedValue'
            }
        }
    }

    Context 'Retry on failure (maxAttempts)' {
        It 'Retries step execution up to maxAttempts times on failure' {
            InModuleScope $script:moduleName {
                # Arrange
                $script:attemptCount = 0

                function Invoke-TestRetryStep
                {
                    $script:attemptCount++
                    if ($script:attemptCount -lt 3)
                    {
                        throw 'Simulated failure for retry test'
                    }
                }

                $workflow = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'Retry Test Workflow'
                    description = 'A workflow that tests retry behavior on failure.'
                    version     = '1.0.0'
                    author      = 'MCD Team'
                    amd64       = $true
                    arm64       = $true
                    default     = $false
                    steps       = @(
                        @{
                            name        = 'Retry Step'
                            description = 'This step fails twice then succeeds.'
                            command     = 'Invoke-TestRetryStep'
                            args        = @()
                            parameters  = @{}
                            rules       = @{
                                skip            = $false
                                runinfullos     = $false
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
                        IsWinPE      = $true
                        Architecture = 'amd64'
                        StateRoot    = $TestDrive
                        LogsRoot     = $TestDrive
                    }
                }

                Mock Start-Sleep -MockWith {}
                Mock Update-MCDWinPEProgress -MockWith {}
                Mock Write-MCDLog -MockWith {}

                # Act
                Invoke-MCDWorkflow -WorkflowObject $workflow

                # Assert: Should have been called 3 times (2 failures + 1 success)
                $script:attemptCount | Should -Be 3
            }
        }

        It 'Throws after exhausting all retry attempts' {
            InModuleScope $script:moduleName {
                # Arrange
                $script:attemptCount = 0

                function Invoke-TestAlwaysFailStep
                {
                    $script:attemptCount++
                    throw 'Simulated persistent failure'
                }

                $workflow = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'Exhausted Retry Workflow'
                    description = 'A workflow where step always fails to test retry exhaustion.'
                    version     = '1.0.0'
                    author      = 'MCD Team'
                    amd64       = $true
                    arm64       = $true
                    default     = $false
                    steps       = @(
                        @{
                            name        = 'Always Fail Step'
                            description = 'This step always fails.'
                            command     = 'Invoke-TestAlwaysFailStep'
                            args        = @()
                            parameters  = @{}
                            rules       = @{
                                skip            = $false
                                runinfullos     = $false
                                runinwinpe      = $true
                                architecture    = @('amd64', 'arm64')
                                retry           = @{
                                    enabled     = $true
                                    maxAttempts = 2
                                    retryDelay  = 1
                                }
                                continueOnError = $false
                            }
                        }
                    )
                }

                Mock Get-MCDExecutionContext -MockWith {
                    [PSCustomObject]@{
                        IsWinPE      = $true
                        Architecture = 'amd64'
                        StateRoot    = $TestDrive
                        LogsRoot     = $TestDrive
                    }
                }

                Mock Start-Sleep -MockWith {}
                Mock Update-MCDWinPEProgress -MockWith {}
                Mock Write-MCDLog -MockWith {}

                # Act & Assert: Should throw about persistent failure (not CommandNotFoundException)
                { Invoke-MCDWorkflow -WorkflowObject $workflow } | Should -Throw -ExpectedMessage '*Simulated persistent failure*'

                # Assert: Should have been called maxAttempts times
                $script:attemptCount | Should -Be 2
            }
        }
    }

    Context 'Retry delay respected (retryDelay)' {
        It 'Calls Start-Sleep with the correct delay between retries' {
            InModuleScope $script:moduleName {
                # Arrange
                $script:attemptCount = 0

                function Invoke-TestDelayStep
                {
                    $script:attemptCount++
                    if ($script:attemptCount -lt 2)
                    {
                        throw 'Simulated failure for delay test'
                    }
                }

                $workflow = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'Retry Delay Workflow'
                    description = 'A workflow that tests retry delay behavior.'
                    version     = '1.0.0'
                    author      = 'MCD Team'
                    amd64       = $true
                    arm64       = $true
                    default     = $false
                    steps       = @(
                        @{
                            name        = 'Delay Step'
                            description = 'This step tests retry delay.'
                            command     = 'Invoke-TestDelayStep'
                            args        = @()
                            parameters  = @{}
                            rules       = @{
                                skip            = $false
                                runinfullos     = $false
                                runinwinpe      = $true
                                architecture    = @('amd64', 'arm64')
                                retry           = @{
                                    enabled     = $true
                                    maxAttempts = 3
                                    retryDelay  = 5
                                }
                                continueOnError = $false
                            }
                        }
                    )
                }

                Mock Get-MCDExecutionContext -MockWith {
                    [PSCustomObject]@{
                        IsWinPE      = $true
                        Architecture = 'amd64'
                        StateRoot    = $TestDrive
                        LogsRoot     = $TestDrive
                    }
                }

                Mock Start-Sleep -MockWith {}
                Mock Update-MCDWinPEProgress -MockWith {}
                Mock Write-MCDLog -MockWith {}

                # Act
                Invoke-MCDWorkflow -WorkflowObject $workflow

                # Assert: Start-Sleep should have been called with 5 seconds
                Should -Invoke Start-Sleep -ParameterFilter { $Seconds -eq 5 } -Times 1
            }
        }
    }

    Context 'Fail-fast when continueOnError false' {
        It 'Stops workflow execution on step failure when continueOnError is false' {
            InModuleScope $script:moduleName {
                # Arrange
                $script:executedSteps = @()

                function Invoke-TestFailStep
                {
                    $script:executedSteps += 'Fail'
                    throw 'Simulated failure for fail-fast test'
                }

                function Invoke-TestAfterFailStep
                {
                    $script:executedSteps += 'AfterFail'
                }

                $workflow = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'Fail-Fast Workflow'
                    description = 'A workflow that tests fail-fast behavior.'
                    version     = '1.0.0'
                    author      = 'MCD Team'
                    amd64       = $true
                    arm64       = $true
                    default     = $false
                    steps       = @(
                        @{
                            name        = 'Fail Step'
                            description = 'This step fails.'
                            command     = 'Invoke-TestFailStep'
                            args        = @()
                            parameters  = @{}
                            rules       = @{
                                skip            = $false
                                runinfullos     = $false
                                runinwinpe      = $true
                                architecture    = @('amd64', 'arm64')
                                retry           = @{ enabled = $false }
                                continueOnError = $false
                            }
                        }
                        @{
                            name        = 'After Fail Step'
                            description = 'This step should not run.'
                            command     = 'Invoke-TestAfterFailStep'
                            args        = @()
                            parameters  = @{}
                            rules       = @{
                                skip            = $false
                                runinfullos     = $false
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
                        IsWinPE      = $true
                        Architecture = 'amd64'
                        StateRoot    = $TestDrive
                        LogsRoot     = $TestDrive
                    }
                }

                Mock Update-MCDWinPEProgress -MockWith {}
                Mock Write-MCDLog -MockWith {}

                # Act & Assert: Should throw about fail-fast failure (not CommandNotFoundException)
                { Invoke-MCDWorkflow -WorkflowObject $workflow } | Should -Throw -ExpectedMessage '*Simulated failure for fail-fast test*'

                # Assert: Second step should not have run
                $script:executedSteps | Should -Be @('Fail')
                $script:executedSteps | Should -Not -Contain 'AfterFail'
            }
        }
    }

    Context 'Continue when continueOnError true' {
        It 'Continues workflow execution on step failure when continueOnError is true' {
            InModuleScope $script:moduleName {
                # Arrange
                $script:executedSteps = @()

                function Invoke-TestContinueFailStep
                {
                    $script:executedSteps += 'Fail'
                    throw 'Simulated failure for continue-on-error test'
                }

                function Invoke-TestAfterContinueStep
                {
                    $script:executedSteps += 'AfterContinue'
                }

                $workflow = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'Continue On Error Workflow'
                    description = 'A workflow that tests continueOnError behavior.'
                    version     = '1.0.0'
                    author      = 'MCD Team'
                    amd64       = $true
                    arm64       = $true
                    default     = $false
                    steps       = @(
                        @{
                            name        = 'Fail But Continue Step'
                            description = 'This step fails but continues.'
                            command     = 'Invoke-TestContinueFailStep'
                            args        = @()
                            parameters  = @{}
                            rules       = @{
                                skip            = $false
                                runinfullos     = $false
                                runinwinpe      = $true
                                architecture    = @('amd64', 'arm64')
                                retry           = @{ enabled = $false }
                                continueOnError = $true
                            }
                        }
                        @{
                            name        = 'After Continue Step'
                            description = 'This step should run after failure.'
                            command     = 'Invoke-TestAfterContinueStep'
                            args        = @()
                            parameters  = @{}
                            rules       = @{
                                skip            = $false
                                runinfullos     = $false
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
                        IsWinPE      = $true
                        Architecture = 'amd64'
                        StateRoot    = $TestDrive
                        LogsRoot     = $TestDrive
                    }
                }

                Mock Update-MCDWinPEProgress -MockWith {}
                Mock Write-MCDLog -MockWith {}

                # Act
                Invoke-MCDWorkflow -WorkflowObject $workflow

                # Assert: Both steps should have run
                $script:executedSteps | Should -Be @('Fail', 'AfterContinue')
            }
        }
    }

    Context 'Progress UI updates via Update-MCDWinPEProgress' {
        It 'Calls Update-MCDWinPEProgress with correct step information' {
            InModuleScope $script:moduleName {
                # Arrange
                function Invoke-TestProgressStep
                {
                    # No-op step
                }

                $workflow = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'Progress UI Workflow'
                    description = 'A workflow that tests UI progress updates.'
                    version     = '1.0.0'
                    author      = 'MCD Team'
                    amd64       = $true
                    arm64       = $true
                    default     = $false
                    steps       = @(
                        @{
                            name        = 'Progress Step One'
                            description = 'First progress step.'
                            command     = 'Invoke-TestProgressStep'
                            args        = @()
                            parameters  = @{}
                            rules       = @{
                                skip            = $false
                                runinfullos     = $false
                                runinwinpe      = $true
                                architecture    = @('amd64', 'arm64')
                                retry           = @{ enabled = $false }
                                continueOnError = $false
                            }
                        }
                        @{
                            name        = 'Progress Step Two'
                            description = 'Second progress step.'
                            command     = 'Invoke-TestProgressStep'
                            args        = @()
                            parameters  = @{}
                            rules       = @{
                                skip            = $false
                                runinfullos     = $false
                                runinwinpe      = $true
                                architecture    = @('amd64', 'arm64')
                                retry           = @{ enabled = $false }
                                continueOnError = $false
                            }
                        }
                    )
                }

                # Create a minimal mock window object
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

                # Assert: Update-MCDWinPEProgress should have been called for each step
                Should -Invoke Update-MCDWinPEProgress -ParameterFilter { $StepName -eq 'Progress Step One' -and $StepIndex -eq 1 -and $StepCount -eq 2 }
                Should -Invoke Update-MCDWinPEProgress -ParameterFilter { $StepName -eq 'Progress Step Two' -and $StepIndex -eq 2 -and $StepCount -eq 2 }
            }
        }

        It 'Does not call Update-MCDWinPEProgress when Window is not provided' {
            InModuleScope $script:moduleName {
                # Arrange
                function Invoke-TestNoWindowStep
                {
                    # No-op step
                }

                $workflow = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'No Window Workflow'
                    description = 'A workflow that runs without a window.'
                    version     = '1.0.0'
                    author      = 'MCD Team'
                    amd64       = $true
                    arm64       = $true
                    default     = $false
                    steps       = @(
                        @{
                            name        = 'No Window Step'
                            description = 'Step without window.'
                            command     = 'Invoke-TestNoWindowStep'
                            args        = @()
                            parameters  = @{}
                            rules       = @{
                                skip            = $false
                                runinfullos     = $false
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
                        IsWinPE      = $true
                        Architecture = 'amd64'
                        StateRoot    = $TestDrive
                        LogsRoot     = $TestDrive
                    }
                }

                Mock Update-MCDWinPEProgress -MockWith {}
                Mock Write-MCDLog -MockWith {}

                # Act
                Invoke-MCDWorkflow -WorkflowObject $workflow

                # Assert: Update-MCDWinPEProgress should not have been called
                Should -Invoke Update-MCDWinPEProgress -Times 0
            }
        }
    }

    Context 'State persisted to State.json' {
        It 'Persists workflow state to C:\Windows\Temp\MCD\State.json' {
            InModuleScope $script:moduleName {
                # Arrange
                function Invoke-TestStateStep
                {
                    # No-op step
                }

                $workflow = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'State Persistence Workflow'
                    description = 'A workflow that tests state file persistence.'
                    version     = '1.0.0'
                    author      = 'MCD Team'
                    amd64       = $true
                    arm64       = $true
                    default     = $false
                    steps       = @(
                        @{
                            name        = 'State Step One'
                            description = 'First state step.'
                            command     = 'Invoke-TestStateStep'
                            args        = @()
                            parameters  = @{}
                            rules       = @{
                                skip            = $false
                                runinfullos     = $false
                                runinwinpe      = $true
                                architecture    = @('amd64', 'arm64')
                                retry           = @{ enabled = $false }
                                continueOnError = $false
                            }
                        }
                        @{
                            name        = 'State Step Two'
                            description = 'Second state step.'
                            command     = 'Invoke-TestStateStep'
                            args        = @()
                            parameters  = @{}
                            rules       = @{
                                skip            = $false
                                runinfullos     = $false
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
                        IsWinPE      = $true
                        Architecture = 'amd64'
                        StateRoot    = $TestDrive
                        LogsRoot     = $TestDrive
                    }
                }

                Mock Set-Content -MockWith { }
                Mock Test-Path -MockWith { $true } -ParameterFilter { $Path -eq 'C:\Windows\Temp\MCD' }
                Mock Update-MCDWinPEProgress -MockWith {}
                Mock Write-MCDLog -MockWith {}

                # Act
                Invoke-MCDWorkflow -WorkflowObject $workflow

                # Assert: Set-Content should have been called at least twice (once per step)
                # with Path = 'C:\Windows\Temp\MCD\State.json'
                Should -Invoke Set-Content -ParameterFilter { $Path -eq 'C:\Windows\Temp\MCD\State.json' } -Times 2 -Exactly
            }
        }
    }

    Context 'Handle invalid step command gracefully' {
        It 'Logs an error and continues or throws based on continueOnError when command is invalid' {
            InModuleScope $script:moduleName {
                # Arrange
                $script:executedSteps = @()

                function Invoke-TestValidStep
                {
                    $script:executedSteps += 'Valid'
                }

                $workflow = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'Invalid Command Graceful Workflow'
                    description = 'A workflow that tests graceful handling of invalid commands.'
                    version     = '1.0.0'
                    author      = 'MCD Team'
                    amd64       = $true
                    arm64       = $true
                    default     = $false
                    steps       = @(
                        @{
                            name        = 'Invalid Command Step'
                            description = 'This step has an invalid command.'
                            command     = 'Invoke-InvalidCommandThatDoesNotExist'
                            args        = @()
                            parameters  = @{}
                            rules       = @{
                                skip            = $false
                                runinfullos     = $false
                                runinwinpe      = $true
                                architecture    = @('amd64', 'arm64')
                                retry           = @{ enabled = $false }
                                continueOnError = $true
                            }
                        }
                        @{
                            name        = 'Valid Step'
                            description = 'This step should run despite previous invalid command.'
                            command     = 'Invoke-TestValidStep'
                            args        = @()
                            parameters  = @{}
                            rules       = @{
                                skip            = $false
                                runinfullos     = $false
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
                        IsWinPE      = $true
                        Architecture = 'amd64'
                        StateRoot    = $TestDrive
                        LogsRoot     = $TestDrive
                    }
                }

                Mock Get-Command -MockWith { $null } -ParameterFilter { $Name -eq 'Invoke-InvalidCommandThatDoesNotExist' }
                Mock Update-MCDWinPEProgress -MockWith {}
                Mock Write-MCDLog -MockWith {}

                # Act
                Invoke-MCDWorkflow -WorkflowObject $workflow

                # Assert: Write-MCDLog should have been called with Error level
                Should -Invoke Write-MCDLog -ParameterFilter { $Level -eq 'Error' }

                # Assert: Valid step should still run
                $script:executedSteps | Should -Contain 'Valid'
            }
        }
    }

    Context 'Handle step exceptions gracefully' {
        It 'Catches step exceptions and logs them appropriately' {
            InModuleScope $script:moduleName {
                # Arrange
                function Invoke-TestExceptionStep
                {
                    throw 'Intentional exception for testing'
                }

                $workflow = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'Exception Handling Workflow'
                    description = 'A workflow that tests exception handling in steps.'
                    version     = '1.0.0'
                    author      = 'MCD Team'
                    amd64       = $true
                    arm64       = $true
                    default     = $false
                    steps       = @(
                        @{
                            name        = 'Exception Step'
                            description = 'This step throws an exception.'
                            command     = 'Invoke-TestExceptionStep'
                            args        = @()
                            parameters  = @{}
                            rules       = @{
                                skip            = $false
                                runinfullos     = $false
                                runinwinpe      = $true
                                architecture    = @('amd64', 'arm64')
                                retry           = @{ enabled = $false }
                                continueOnError = $true
                            }
                        }
                    )
                }

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

                # Act: Should not throw because continueOnError is true
                { Invoke-MCDWorkflow -WorkflowObject $workflow } | Should -Not -Throw

                # Assert: Write-MCDLog should have been called with Error level
                Should -Invoke Write-MCDLog -ParameterFilter { $Level -eq 'Error' }
            }
        }
    }

    Context 'Environment execution context (WinPE vs Full OS)' {
        It 'Skips steps marked runinwinpe=false when running in WinPE' {
            InModuleScope $script:moduleName {
                # Arrange
                $script:executedSteps = @()

                function Invoke-TestWinPEOnlyStep
                {
                    $script:executedSteps += 'WinPE'
                }

                function Invoke-TestFullOSOnlyStep
                {
                    $script:executedSteps += 'FullOS'
                }

                $workflow = @{
                    id          = [guid]::NewGuid().ToString()
                    name        = 'Environment Filter Workflow'
                    description = 'A workflow that tests environment filtering.'
                    version     = '1.0.0'
                    author      = 'MCD Team'
                    amd64       = $true
                    arm64       = $true
                    default     = $false
                    steps       = @(
                        @{
                            name        = 'WinPE Only Step'
                            description = 'This step runs only in WinPE.'
                            command     = 'Invoke-TestWinPEOnlyStep'
                            args        = @()
                            parameters  = @{}
                            rules       = @{
                                skip            = $false
                                runinfullos     = $false
                                runinwinpe      = $true
                                architecture    = @('amd64', 'arm64')
                                retry           = @{ enabled = $false }
                                continueOnError = $false
                            }
                        }
                        @{
                            name        = 'Full OS Only Step'
                            description = 'This step runs only in Full OS.'
                            command     = 'Invoke-TestFullOSOnlyStep'
                            args        = @()
                            parameters  = @{}
                            rules       = @{
                                skip            = $false
                                runinfullos     = $true
                                runinwinpe      = $false
                                architecture    = @('amd64', 'arm64')
                                retry           = @{ enabled = $false }
                                continueOnError = $false
                            }
                        }
                    )
                }

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
                Invoke-MCDWorkflow -WorkflowObject $workflow

                # Assert
                $script:executedSteps | Should -Be @('WinPE')
                $script:executedSteps | Should -Not -Contain 'FullOS'
            }
        }
    }
}
