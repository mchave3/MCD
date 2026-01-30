BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\..\.." | Convert-Path

    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }

    $script:moduleName = $ProjectName
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

Describe 'Get-MCDWorkflowStepPalette' {
    Context 'Parameter Validation' {
        It 'Has optional IncludeCustom switch parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Get-MCDWorkflowStepPalette'
                $param = $cmd.Parameters['IncludeCustom']

                $param | Should -Not -BeNullOrEmpty
                $param.SwitchParameter | Should -BeTrue
            }
        }
    }

    Context 'Returns built-in step commands' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
        }

        It 'Returns array of step command objects' {
            InModuleScope $script:moduleName {
                $result = Get-MCDWorkflowStepPalette

                $result | Should -Not -BeNullOrEmpty
                $result.Count | Should -BeGreaterThan 0
            }
        }

        It 'Each step has Name, Command, and Description properties' {
            InModuleScope $script:moduleName {
                $result = Get-MCDWorkflowStepPalette

                foreach ($step in $result)
                {
                    $step.Name | Should -Not -BeNullOrEmpty
                    $step.Command | Should -Not -BeNullOrEmpty
                    $step.Command | Should -Match '^Step-MCD'
                }
            }
        }

        It 'Includes Step-MCDValidateSelection' {
            InModuleScope $script:moduleName {
                $result = Get-MCDWorkflowStepPalette

                $validateStep = $result | Where-Object { $_.Command -eq 'Step-MCDValidateSelection' }
                $validateStep | Should -Not -BeNullOrEmpty
            }
        }

        It 'Includes Step-MCDPrepareDisk' {
            InModuleScope $script:moduleName {
                $result = Get-MCDWorkflowStepPalette

                $diskStep = $result | Where-Object { $_.Command -eq 'Step-MCDPrepareDisk' }
                $diskStep | Should -Not -BeNullOrEmpty
            }
        }
    }
}

Describe 'New-MCDWorkflow' {
    Context 'Parameter Validation' {
        It 'Has mandatory Name parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'New-MCDWorkflow'
                $param = $cmd.Parameters['Name']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory } | Should -Not -BeNullOrEmpty
            }
        }

        It 'Has optional Description parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'New-MCDWorkflow'
                $param = $cmd.Parameters['Description']

                $param | Should -Not -BeNullOrEmpty
            }
        }

        It 'Has optional Author parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'New-MCDWorkflow'
                $param = $cmd.Parameters['Author']

                $param | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'Creates valid workflow' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
        }

        It 'Returns WorkflowEditorModel object' {
            InModuleScope $script:moduleName {
                $result = New-MCDWorkflow -Name 'TestWorkflow'

                $result | Should -Not -BeNullOrEmpty
                $result.GetType().Name | Should -Be 'WorkflowEditorModel'
            }
        }

        It 'Sets name from parameter' {
            InModuleScope $script:moduleName {
                $result = New-MCDWorkflow -Name 'MyCustomWorkflow'

                $result.Name | Should -Be 'MyCustomWorkflow'
            }
        }

        It 'Sets description from parameter' {
            InModuleScope $script:moduleName {
                $result = New-MCDWorkflow -Name 'TestWorkflow' -Description 'This is a test workflow description.'

                $result.Description | Should -Be 'This is a test workflow description.'
            }
        }

        It 'Sets author from parameter' {
            InModuleScope $script:moduleName {
                $result = New-MCDWorkflow -Name 'TestWorkflow' -Author 'Test Author'

                $result.Author | Should -Be 'Test Author'
            }
        }

        It 'Generates valid GUID for Id' {
            InModuleScope $script:moduleName {
                $result = New-MCDWorkflow -Name 'TestWorkflow'

                $result.Id | Should -Not -BeNullOrEmpty
                { [guid]::Parse($result.Id) } | Should -Not -Throw
            }
        }

        It 'Defaults to supporting both architectures' {
            InModuleScope $script:moduleName {
                $result = New-MCDWorkflow -Name 'TestWorkflow'

                $result.Amd64 | Should -BeTrue
                $result.Arm64 | Should -BeTrue
            }
        }

        It 'Initializes empty steps list' {
            InModuleScope $script:moduleName {
                $result = New-MCDWorkflow -Name 'TestWorkflow'

                $null -ne $result.Steps | Should -BeTrue
                $result.Steps.Count | Should -Be 0
            }
        }
    }
}

Describe 'Save-MCDWorkflow' {
    Context 'Parameter Validation' {
        It 'Has mandatory Workflow parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Save-MCDWorkflow'
                $param = $cmd.Parameters['Workflow']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory } | Should -Not -BeNullOrEmpty
            }
        }

        It 'Has mandatory ProfileName parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Save-MCDWorkflow'
                $param = $cmd.Parameters['ProfileName']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory } | Should -Not -BeNullOrEmpty
            }
        }

        It 'Supports ShouldProcess' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Save-MCDWorkflow'
                $cmd.CmdletBinding | Should -BeTrue
                $cmd.Parameters.Keys | Should -Contain 'WhatIf'
                $cmd.Parameters.Keys | Should -Contain 'Confirm'
            }
        }
    }

    Context 'Saves workflow to profile directory' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
            Mock Get-MCDExecutionContext -ModuleName $script:moduleName -MockWith {
                @{
                    ProfilesRoot = $TestDrive
                }
            }
            Mock Test-Path -ModuleName $script:moduleName -MockWith { $true }
            Mock New-Item -ModuleName $script:moduleName
            Mock Set-Content -ModuleName $script:moduleName
        }

        It 'Creates profile directory if not exists' {
            Mock Test-Path -ModuleName $script:moduleName -ParameterFilter { $Path -like '*TestProfile*' } -MockWith { $false }
            Mock New-Item -ModuleName $script:moduleName -MockWith { [PSCustomObject]@{ FullName = $Path } }

            InModuleScope $script:moduleName {
                $workflow = New-MCDWorkflow -Name 'TestWorkflow'
                Save-MCDWorkflow -Workflow $workflow -ProfileName 'TestProfile' -Confirm:$false
            }

            Should -Invoke New-Item -ModuleName $script:moduleName -ParameterFilter { $ItemType -eq 'Directory' }
        }

        It 'Writes JSON content to workflow.json file' {
            InModuleScope $script:moduleName {
                $workflow = New-MCDWorkflow -Name 'TestWorkflow'
                Save-MCDWorkflow -Workflow $workflow -ProfileName 'TestProfile' -Confirm:$false
            }

            Should -Invoke Set-Content -ModuleName $script:moduleName
        }

        It 'Validates workflow before saving' {
            InModuleScope $script:moduleName {
                $workflow = [WorkflowEditorModel]::new()
                $workflow.Name = $null  # Invalid - no name

                { Save-MCDWorkflow -Workflow $workflow -ProfileName 'TestProfile' -Confirm:$false } | Should -Throw '*Name is required*'
            }
        }

        It 'Supports WhatIf' {
            Mock Set-Content -ModuleName $script:moduleName

            InModuleScope $script:moduleName {
                $workflow = New-MCDWorkflow -Name 'TestWorkflow'
                Save-MCDWorkflow -Workflow $workflow -ProfileName 'TestProfile' -WhatIf
            }

            Should -Not -Invoke Set-Content -ModuleName $script:moduleName
        }
    }
}

Describe 'Remove-MCDWorkflow' {
    Context 'Parameter Validation' {
        It 'Has mandatory ProfileName parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Remove-MCDWorkflow'
                $param = $cmd.Parameters['ProfileName']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory } | Should -Not -BeNullOrEmpty
            }
        }

        It 'Supports ShouldProcess' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Remove-MCDWorkflow'
                $cmd.CmdletBinding | Should -BeTrue
                $cmd.Parameters.Keys | Should -Contain 'WhatIf'
                $cmd.Parameters.Keys | Should -Contain 'Confirm'
            }
        }
    }

    Context 'Removes workflow from profile directory' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
            Mock Get-MCDExecutionContext -ModuleName $script:moduleName -MockWith {
                @{
                    ProfilesRoot = $TestDrive
                }
            }
            Mock Test-Path -ModuleName $script:moduleName -MockWith { $true }
            Mock Remove-Item -ModuleName $script:moduleName
        }

        It 'Removes workflow.json file from profile' {
            InModuleScope $script:moduleName {
                Remove-MCDWorkflow -ProfileName 'TestProfile' -Confirm:$false
            }

            Should -Invoke Remove-Item -ModuleName $script:moduleName
        }

        It 'Throws if workflow file does not exist' {
            Mock Test-Path -ModuleName $script:moduleName -ParameterFilter { $Path -like '*workflow.json*' } -MockWith { $false }

            InModuleScope $script:moduleName {
                { Remove-MCDWorkflow -ProfileName 'NonExistentProfile' -Confirm:$false } | Should -Throw '*not found*'
            }
        }

        It 'Supports WhatIf' {
            Mock Remove-Item -ModuleName $script:moduleName

            InModuleScope $script:moduleName {
                Remove-MCDWorkflow -ProfileName 'TestProfile' -WhatIf
            }

            Should -Not -Invoke Remove-Item -ModuleName $script:moduleName
        }
    }
}

Describe 'Test-MCDWorkflowValidation' {
    Context 'Parameter Validation' {
        It 'Has mandatory Workflow parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Test-MCDWorkflowValidation'
                $param = $cmd.Parameters['Workflow']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory } | Should -Not -BeNullOrEmpty
            }
        }

        It 'Has optional ValidateCommands switch' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Test-MCDWorkflowValidation'
                $param = $cmd.Parameters['ValidateCommands']

                $param | Should -Not -BeNullOrEmpty
                $param.SwitchParameter | Should -BeTrue
            }
        }
    }

    Context 'Validates workflow structure' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
        }

        It 'Returns true for valid workflow' {
            InModuleScope $script:moduleName {
                $workflow = New-MCDWorkflow -Name 'ValidWorkflow'
                $result = Test-MCDWorkflowValidation -Workflow $workflow

                $result.IsValid | Should -BeTrue
            }
        }

        It 'Returns false for workflow with no name' {
            InModuleScope $script:moduleName {
                $workflow = [WorkflowEditorModel]::new()
                $workflow.Name = $null

                $result = Test-MCDWorkflowValidation -Workflow $workflow

                $result.IsValid | Should -BeFalse
                $result.Errors | Should -Contain '*Name*'
            }
        }

        It 'Returns false for workflow with no architectures' {
            InModuleScope $script:moduleName {
                $workflow = New-MCDWorkflow -Name 'NoArchWorkflow'
                $workflow.Amd64 = $false
                $workflow.Arm64 = $false

                $result = Test-MCDWorkflowValidation -Workflow $workflow

                $result.IsValid | Should -BeFalse
                $result.Errors | Should -Contain '*architecture*'
            }
        }

        It 'Validates step commands when ValidateCommands is specified' {
            Mock Get-Command -ModuleName $script:moduleName -ParameterFilter { $Name -eq 'Invalid-Command' } -MockWith { $null }

            InModuleScope $script:moduleName {
                $workflow = New-MCDWorkflow -Name 'InvalidStepWorkflow'
                $step = [StepModel]::new('Invalid Step', 'Invalid-Command')
                $workflow.AddStep($step)

                $result = Test-MCDWorkflowValidation -Workflow $workflow -ValidateCommands

                $result.IsValid | Should -BeFalse
                $result.Errors | Should -Contain '*Invalid-Command*not found*'
            }
        }

        It 'Returns validation result object with IsValid and Errors properties' {
            InModuleScope $script:moduleName {
                $workflow = New-MCDWorkflow -Name 'TestWorkflow'
                $result = Test-MCDWorkflowValidation -Workflow $workflow

                $result.PSObject.Properties.Name | Should -Contain 'IsValid'
                $result.PSObject.Properties.Name | Should -Contain 'Errors'
            }
        }
    }
}

Describe 'Move-MCDWorkflowStep' {
    Context 'Parameter Validation' {
        It 'Has mandatory Workflow parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Move-MCDWorkflowStep'
                $param = $cmd.Parameters['Workflow']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory } | Should -Not -BeNullOrEmpty
            }
        }

        It 'Has mandatory FromIndex parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Move-MCDWorkflowStep'
                $param = $cmd.Parameters['FromIndex']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory } | Should -Not -BeNullOrEmpty
            }
        }

        It 'Has mandatory ToIndex parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Move-MCDWorkflowStep'
                $param = $cmd.Parameters['ToIndex']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory } | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'Moves steps within workflow' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
        }

        It 'Moves step from first to last position' {
            InModuleScope $script:moduleName {
                $workflow = New-MCDWorkflow -Name 'TestWorkflow'
                $step1 = [StepModel]::new('Step 1', 'Step-MCDValidateSelection')
                $step2 = [StepModel]::new('Step 2', 'Step-MCDPrepareDisk')
                $step3 = [StepModel]::new('Step 3', 'Step-MCDDeployWindows')
                $workflow.AddStep($step1)
                $workflow.AddStep($step2)
                $workflow.AddStep($step3)

                Move-MCDWorkflowStep -Workflow $workflow -FromIndex 0 -ToIndex 2

                $workflow.Steps[2].Name | Should -Be 'Step 1'
                $workflow.Steps[0].Name | Should -Be 'Step 2'
            }
        }

        It 'Moves step from last to first position' {
            InModuleScope $script:moduleName {
                $workflow = New-MCDWorkflow -Name 'TestWorkflow'
                $step1 = [StepModel]::new('Step 1', 'Step-MCDValidateSelection')
                $step2 = [StepModel]::new('Step 2', 'Step-MCDPrepareDisk')
                $step3 = [StepModel]::new('Step 3', 'Step-MCDDeployWindows')
                $workflow.AddStep($step1)
                $workflow.AddStep($step2)
                $workflow.AddStep($step3)

                Move-MCDWorkflowStep -Workflow $workflow -FromIndex 2 -ToIndex 0

                $workflow.Steps[0].Name | Should -Be 'Step 3'
                $workflow.Steps[2].Name | Should -Be 'Step 2'
            }
        }

        It 'Throws for invalid FromIndex' {
            InModuleScope $script:moduleName {
                $workflow = New-MCDWorkflow -Name 'TestWorkflow'
                $step1 = [StepModel]::new('Step 1', 'Step-MCDValidateSelection')
                $workflow.AddStep($step1)

                { Move-MCDWorkflowStep -Workflow $workflow -FromIndex 5 -ToIndex 0 } | Should -Throw
            }
        }

        It 'Throws for invalid ToIndex' {
            InModuleScope $script:moduleName {
                $workflow = New-MCDWorkflow -Name 'TestWorkflow'
                $step1 = [StepModel]::new('Step 1', 'Step-MCDValidateSelection')
                $workflow.AddStep($step1)

                { Move-MCDWorkflowStep -Workflow $workflow -FromIndex 0 -ToIndex 5 } | Should -Throw
            }
        }
    }
}

Describe 'Add-MCDWorkflowStep' {
    Context 'Parameter Validation' {
        It 'Has mandatory Workflow parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Add-MCDWorkflowStep'
                $param = $cmd.Parameters['Workflow']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory } | Should -Not -BeNullOrEmpty
            }
        }

        It 'Has mandatory StepName parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Add-MCDWorkflowStep'
                $param = $cmd.Parameters['StepName']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory } | Should -Not -BeNullOrEmpty
            }
        }

        It 'Has mandatory Command parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Add-MCDWorkflowStep'
                $param = $cmd.Parameters['Command']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory } | Should -Not -BeNullOrEmpty
            }
        }

        It 'Has optional Position parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Add-MCDWorkflowStep'
                $param = $cmd.Parameters['Position']

                $param | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'Adds steps to workflow' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
        }

        It 'Adds step to end by default' {
            InModuleScope $script:moduleName {
                $workflow = New-MCDWorkflow -Name 'TestWorkflow'
                $step1 = [StepModel]::new('Step 1', 'Step-MCDValidateSelection')
                $workflow.AddStep($step1)

                Add-MCDWorkflowStep -Workflow $workflow -StepName 'New Step' -Command 'Step-MCDPrepareDisk'

                $workflow.Steps.Count | Should -Be 2
                $workflow.Steps[1].Name | Should -Be 'New Step'
            }
        }

        It 'Adds step at specified position' {
            InModuleScope $script:moduleName {
                $workflow = New-MCDWorkflow -Name 'TestWorkflow'
                $step1 = [StepModel]::new('Step 1', 'Step-MCDValidateSelection')
                $step2 = [StepModel]::new('Step 2', 'Step-MCDDeployWindows')
                $workflow.AddStep($step1)
                $workflow.AddStep($step2)

                Add-MCDWorkflowStep -Workflow $workflow -StepName 'Inserted Step' -Command 'Step-MCDPrepareDisk' -Position 1

                $workflow.Steps.Count | Should -Be 3
                $workflow.Steps[1].Name | Should -Be 'Inserted Step'
            }
        }

        It 'Returns the added step' {
            InModuleScope $script:moduleName {
                $workflow = New-MCDWorkflow -Name 'TestWorkflow'

                $result = Add-MCDWorkflowStep -Workflow $workflow -StepName 'New Step' -Command 'Step-MCDPrepareDisk'

                $result | Should -Not -BeNullOrEmpty
                $result.GetType().Name | Should -Be 'StepModel'
                $result.Name | Should -Be 'New Step'
            }
        }

        It 'Sets description when provided' {
            InModuleScope $script:moduleName {
                $workflow = New-MCDWorkflow -Name 'TestWorkflow'

                $result = Add-MCDWorkflowStep -Workflow $workflow -StepName 'New Step' -Command 'Step-MCDPrepareDisk' -Description 'Step description'

                $result.Description | Should -Be 'Step description'
            }
        }
    }
}

Describe 'Remove-MCDWorkflowStep' {
    Context 'Parameter Validation' {
        It 'Has mandatory Workflow parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Remove-MCDWorkflowStep'
                $param = $cmd.Parameters['Workflow']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory } | Should -Not -BeNullOrEmpty
            }
        }

        It 'Has mandatory Index parameter' {
            InModuleScope $script:moduleName {
                $cmd = Get-Command -Name 'Remove-MCDWorkflowStep'
                $param = $cmd.Parameters['Index']

                $param | Should -Not -BeNullOrEmpty
                $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory } | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'Removes steps from workflow' {
        BeforeEach {
            Mock Write-MCDLog -ModuleName $script:moduleName
        }

        It 'Removes step at specified index' {
            InModuleScope $script:moduleName {
                $workflow = New-MCDWorkflow -Name 'TestWorkflow'
                $step1 = [StepModel]::new('Step 1', 'Step-MCDValidateSelection')
                $step2 = [StepModel]::new('Step 2', 'Step-MCDPrepareDisk')
                $step3 = [StepModel]::new('Step 3', 'Step-MCDDeployWindows')
                $workflow.AddStep($step1)
                $workflow.AddStep($step2)
                $workflow.AddStep($step3)

                Remove-MCDWorkflowStep -Workflow $workflow -Index 1

                $workflow.Steps.Count | Should -Be 2
                $workflow.Steps[0].Name | Should -Be 'Step 1'
                $workflow.Steps[1].Name | Should -Be 'Step 3'
            }
        }

        It 'Throws for invalid index' {
            InModuleScope $script:moduleName {
                $workflow = New-MCDWorkflow -Name 'TestWorkflow'
                $step1 = [StepModel]::new('Step 1', 'Step-MCDValidateSelection')
                $workflow.AddStep($step1)

                { Remove-MCDWorkflowStep -Workflow $workflow -Index 5 } | Should -Throw
            }
        }

        It 'Returns the removed step' {
            InModuleScope $script:moduleName {
                $workflow = New-MCDWorkflow -Name 'TestWorkflow'
                $step1 = [StepModel]::new('Step 1', 'Step-MCDValidateSelection')
                $workflow.AddStep($step1)

                $result = Remove-MCDWorkflowStep -Workflow $workflow -Index 0

                $result | Should -Not -BeNullOrEmpty
                $result.Name | Should -Be 'Step 1'
            }
        }
    }
}
