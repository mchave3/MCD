BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\.." | Convert-Path
    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }
    $script:moduleName = $ProjectName
    Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase -ErrorAction SilentlyContinue
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

Describe 'Invoke-MCDWinPEDeployment' {
    BeforeEach {
        InModuleScope $script:moduleName {
            $script:xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <StackPanel>
    <TextBlock x:Name="StepCounterText" />
    <TextBlock x:Name="CurrentStepText" />
    <ProgressBar x:Name="DeploymentProgressBar" />
    <TextBlock x:Name="ProgressPercentText" />
  </StackPanel>
</Window>
'@
            $reader = New-Object System.Xml.XmlNodeReader ([xml]$script:xaml)
            $script:testWindow = [Windows.Markup.XamlReader]::Load($reader)
        }
    }

    Context 'Uses workflow from Selection.Workflow' {
        It 'Calls Invoke-MCDWorkflow with workflow from Selection' {
            InModuleScope $script:moduleName {
                $mockWorkflow = @{
                    name    = 'TestWorkflow'
                    default = $true
                    steps   = @(
                        @{ name = 'Step1'; command = 'Write-Verbose' }
                    )
                }

                Mock Invoke-MCDWorkflow { }
                Mock Write-MCDLog { }
                Mock Update-MCDWinPEProgress { }

                $selection = [pscustomobject]@{
                    Workflow         = $mockWorkflow
                    ComputerLanguage = 'en-US'
                    OperatingSystem  = [pscustomobject]@{ DisplayName = 'Windows 11'; Id = 'win11' }
                }

                Invoke-MCDWinPEDeployment -Window $script:testWindow -Selection $selection

                Should -Invoke Invoke-MCDWorkflow -Times 1 -ParameterFilter {
                    $WorkflowObject.name -eq 'TestWorkflow'
                }
            }
        }
    }

    Context 'Falls back to default workflow when Selection.Workflow is null' {
        It 'Loads default workflow via Initialize-MCDWorkflowTasks' {
            InModuleScope $script:moduleName {
                $defaultWorkflow = @{
                    name    = 'DefaultWorkflow'
                    default = $true
                    steps   = @(
                        @{ name = 'DefaultStep'; command = 'Write-Verbose' }
                    )
                }

                Mock Initialize-MCDWorkflowTasks { return @($defaultWorkflow) }
                Mock Invoke-MCDWorkflow { }
                Mock Write-MCDLog { }
                Mock Update-MCDWinPEProgress { }

                $selection = [pscustomobject]@{
                    Workflow         = $null
                    ComputerLanguage = 'en-US'
                    OperatingSystem  = [pscustomobject]@{ DisplayName = 'Windows 11'; Id = 'win11' }
                }

                Invoke-MCDWinPEDeployment -Window $script:testWindow -Selection $selection

                Should -Invoke Initialize-MCDWorkflowTasks -Times 1
                Should -Invoke Invoke-MCDWorkflow -Times 1 -ParameterFilter {
                    $WorkflowObject.name -eq 'DefaultWorkflow'
                }
            }
        }
    }

    Context 'Falls back to first workflow when no default is marked' {
        It 'Uses first available workflow when no default exists' {
            InModuleScope $script:moduleName {
                $firstWorkflow = @{
                    name    = 'FirstWorkflow'
                    default = $false
                    steps   = @(
                        @{ name = 'FirstStep'; command = 'Write-Verbose' }
                    )
                }
                $secondWorkflow = @{
                    name    = 'SecondWorkflow'
                    default = $false
                    steps   = @(
                        @{ name = 'SecondStep'; command = 'Write-Verbose' }
                    )
                }

                Mock Initialize-MCDWorkflowTasks { return @($firstWorkflow, $secondWorkflow) }
                Mock Invoke-MCDWorkflow { }
                Mock Write-MCDLog { }
                Mock Update-MCDWinPEProgress { }

                $selection = [pscustomobject]@{
                    Workflow         = $null
                    ComputerLanguage = 'en-US'
                    OperatingSystem  = [pscustomobject]@{ DisplayName = 'Windows 11'; Id = 'win11' }
                }

                Invoke-MCDWinPEDeployment -Window $script:testWindow -Selection $selection

                Should -Invoke Invoke-MCDWorkflow -Times 1 -ParameterFilter {
                    $WorkflowObject.name -eq 'FirstWorkflow'
                }
            }
        }
    }

    Context 'Throws when no workflow is available' {
        It 'Throws an error when Initialize-MCDWorkflowTasks returns no workflows' {
            InModuleScope $script:moduleName {
                Mock Initialize-MCDWorkflowTasks { return @() }
                Mock Write-MCDLog { }
                Mock Update-MCDWinPEProgress { }

                $selection = [pscustomobject]@{
                    Workflow         = $null
                    ComputerLanguage = 'en-US'
                    OperatingSystem  = [pscustomobject]@{ DisplayName = 'Windows 11'; Id = 'win11' }
                }

                { Invoke-MCDWinPEDeployment -Window $script:testWindow -Selection $selection } | Should -Throw -ExpectedMessage '*No workflow available*'
            }
        }
    }

    Context 'Passes Window to Invoke-MCDWorkflow' {
        It 'Invoke-MCDWorkflow receives the Window parameter' {
            InModuleScope $script:moduleName {
                $mockWorkflow = @{
                    name    = 'UIWorkflow'
                    default = $true
                    steps   = @(
                        @{ name = 'UIStep'; command = 'Write-Verbose' }
                    )
                }

                Mock Invoke-MCDWorkflow { }
                Mock Write-MCDLog { }
                Mock Update-MCDWinPEProgress { }

                $selection = [pscustomobject]@{
                    Workflow         = $mockWorkflow
                    ComputerLanguage = 'en-US'
                    OperatingSystem  = [pscustomobject]@{ DisplayName = 'Windows 11'; Id = 'win11' }
                }

                Invoke-MCDWinPEDeployment -Window $script:testWindow -Selection $selection

                Should -Invoke Invoke-MCDWorkflow -Times 1 -ParameterFilter {
                    $null -ne $Window
                }
            }
        }
    }

    Context 'Handles workflow execution failure' {
        It 'Re-throws exception from Invoke-MCDWorkflow' {
            InModuleScope $script:moduleName {
                $mockWorkflow = @{
                    name    = 'FailingWorkflow'
                    default = $true
                    steps   = @(
                        @{ name = 'FailStep'; command = 'Write-Verbose' }
                    )
                }

                Mock Invoke-MCDWorkflow { throw 'Simulated workflow failure' }
                Mock Write-MCDLog { }
                Mock Update-MCDWinPEProgress { }

                $selection = [pscustomobject]@{
                    Workflow         = $mockWorkflow
                    ComputerLanguage = 'en-US'
                    OperatingSystem  = [pscustomobject]@{ DisplayName = 'Windows 11'; Id = 'win11' }
                }

                { Invoke-MCDWinPEDeployment -Window $script:testWindow -Selection $selection } | Should -Throw -ExpectedMessage '*Simulated workflow failure*'
            }
        }

        It 'Logs error on workflow failure' {
            InModuleScope $script:moduleName {
                $mockWorkflow = @{
                    name    = 'FailingWorkflow'
                    default = $true
                    steps   = @(
                        @{ name = 'FailStep'; command = 'Write-Verbose' }
                    )
                }

                Mock Invoke-MCDWorkflow { throw 'Simulated workflow failure' }
                Mock Write-MCDLog { }
                Mock Update-MCDWinPEProgress { }

                $selection = [pscustomobject]@{
                    Workflow         = $mockWorkflow
                    ComputerLanguage = 'en-US'
                    OperatingSystem  = [pscustomobject]@{ DisplayName = 'Windows 11'; Id = 'win11' }
                }

                try
                {
                    Invoke-MCDWinPEDeployment -Window $script:testWindow -Selection $selection
                }
                catch
                {
                    # Expected
                }

                Should -Invoke Write-MCDLog -Times 1 -ParameterFilter {
                    $Level -eq 'Error' -and $Message -like '*Workflow execution failed*'
                }
            }
        }
    }

    Context 'Logs deployment selection' {
        It 'Logs OS, Language, and DriverPack from Selection' {
            InModuleScope $script:moduleName {
                $mockWorkflow = @{
                    name    = 'LogWorkflow'
                    default = $true
                    steps   = @(
                        @{ name = 'LogStep'; command = 'Write-Verbose' }
                    )
                }

                Mock Invoke-MCDWorkflow { }
                Mock Write-MCDLog { }
                Mock Update-MCDWinPEProgress { }

                $selection = [pscustomobject]@{
                    Workflow         = $mockWorkflow
                    ComputerLanguage = 'de-DE'
                    OperatingSystem  = [pscustomobject]@{ DisplayName = 'Windows 10 Pro'; Id = 'win10pro' }
                    DriverPack       = 'ThinkPad X1 Carbon'
                }

                Invoke-MCDWinPEDeployment -Window $script:testWindow -Selection $selection

                Should -Invoke Write-MCDLog -Times 1 -ParameterFilter {
                    $Level -eq 'Info' -and $Message -like '*Windows 10 Pro*' -and $Message -like '*de-DE*' -and $Message -like '*ThinkPad X1 Carbon*'
                }
            }
        }
    }

    Context 'Updates progress on completion' {
        It 'Updates progress to 100% on successful completion' {
            InModuleScope $script:moduleName {
                $mockWorkflow = @{
                    name    = 'CompletionWorkflow'
                    default = $true
                    steps   = @(
                        @{ name = 'Step1'; command = 'Write-Verbose' },
                        @{ name = 'Step2'; command = 'Write-Verbose' }
                    )
                }

                Mock Invoke-MCDWorkflow { }
                Mock Write-MCDLog { }
                Mock Update-MCDWinPEProgress { }

                $selection = [pscustomobject]@{
                    Workflow         = $mockWorkflow
                    ComputerLanguage = 'en-US'
                    OperatingSystem  = [pscustomobject]@{ DisplayName = 'Windows 11'; Id = 'win11' }
                }

                Invoke-MCDWinPEDeployment -Window $script:testWindow -Selection $selection

                Should -Invoke Update-MCDWinPEProgress -Times 1 -ParameterFilter {
                    $StepName -eq 'Completed' -and $Percent -eq 100
                }
            }
        }
    }
}
