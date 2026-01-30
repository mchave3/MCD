BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\..\.." | Convert-Path

    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }

    $script:moduleName = $ProjectName
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

Describe 'WorkspaceContext Class' {
    Context 'Construction' {
        It 'Creates empty instance with default constructor' {
            InModuleScope $script:moduleName {
                $context = [WorkspaceContext]::new()

                $context | Should -Not -BeNullOrEmpty
                $context.IsInitialized | Should -BeFalse
                # Use direct assertion for empty hashtable (pipeline unwraps empty collections)
                $null -ne $context.Configuration | Should -BeTrue
                $context.Configuration -is [hashtable] | Should -BeTrue
                $context.Configuration.Count | Should -Be 0
            }
        }

        It 'Creates instance with profile name and workspace path' {
            InModuleScope $script:moduleName {
                $context = [WorkspaceContext]::new('TestProfile', 'C:\TestWorkspace')

                $context.ProfileName | Should -Be 'TestProfile'
                $context.WorkspacePath | Should -Be 'C:\TestWorkspace'
                $context.ProfilesPath | Should -Be 'C:\TestWorkspace\Profiles'
                $context.CachePath | Should -Be 'C:\TestWorkspace\Cache'
                $context.LogsPath | Should -Be 'C:\TestWorkspace\Logs'
                $context.IsInitialized | Should -BeTrue
            }
        }

        It 'Throws on null profile name' {
            InModuleScope $script:moduleName {
                { [WorkspaceContext]::new($null, 'C:\Test') } | Should -Throw '*ProfileName*'
            }
        }

        It 'Throws on empty workspace path' {
            InModuleScope $script:moduleName {
                { [WorkspaceContext]::new('Test', '') } | Should -Throw '*WorkspacePath*'
            }
        }
    }

    Context 'Validation' {
        It 'Validate throws when ProfileName is missing' {
            InModuleScope $script:moduleName {
                $context = [WorkspaceContext]::new()
                $context.WorkspacePath = 'C:\Test'

                { $context.Validate() } | Should -Throw '*ProfileName*'
            }
        }

        It 'Validate throws when WorkspacePath is missing' {
            InModuleScope $script:moduleName {
                $context = [WorkspaceContext]::new()
                $context.ProfileName = 'Test'

                { $context.Validate() } | Should -Throw '*WorkspacePath*'
            }
        }
    }

    Context 'Serialization' {
        It 'ToJson produces valid JSON with ASCII keys' {
            InModuleScope $script:moduleName {
                $context = [WorkspaceContext]::new('TestProfile', 'C:\TestWorkspace')
                $context.Configuration['key1'] = 'value1'

                $json = $context.ToJson()

                $json | Should -Not -BeNullOrEmpty
                $json | Should -Match '"profileName"'
                $json | Should -Match '"workspacePath"'
                $json | Should -Match '"isInitialized"'

                # Verify it's valid JSON
                $parsed = $json | ConvertFrom-Json
                $parsed.profileName | Should -Be 'TestProfile'
            }
        }

        It 'FromJson restores instance correctly' {
            InModuleScope $script:moduleName {
                $original = [WorkspaceContext]::new('TestProfile', 'C:\TestWorkspace')
                $original.Configuration['testKey'] = 'testValue'
                $json = $original.ToJson()

                $restored = [WorkspaceContext]::FromJson($json)

                $restored.ProfileName | Should -Be 'TestProfile'
                $restored.WorkspacePath | Should -Be 'C:\TestWorkspace'
                $restored.IsInitialized | Should -BeTrue
                $restored.Configuration['testKey'] | Should -Be 'testValue'
            }
        }
    }
}

Describe 'StepModel Class' {
    Context 'Construction' {
        It 'Creates empty instance with default constructor' {
            InModuleScope $script:moduleName {
                $step = [StepModel]::new()

                $step | Should -Not -BeNullOrEmpty
                # Use direct assertion for empty collections (pipeline unwraps empty collections)
                $null -ne $step.Args | Should -BeTrue
                $step.Args -is [array] | Should -BeTrue
                $step.Args.Count | Should -Be 0
                $null -ne $step.Parameters | Should -BeTrue
                $step.Parameters -is [hashtable] | Should -BeTrue
                $step.Parameters.Count | Should -Be 0
                $step.Rules | Should -Not -BeNullOrEmpty
            }
        }

        It 'Creates instance with name and command' {
            InModuleScope $script:moduleName {
                $step = [StepModel]::new('Test Step', 'Test-Command')

                $step.Name | Should -Be 'Test Step'
                $step.Command | Should -Be 'Test-Command'
            }
        }

        It 'Throws on null name' {
            InModuleScope $script:moduleName {
                { [StepModel]::new($null, 'Test-Command') } | Should -Throw '*Name*'
            }
        }

        It 'Throws on empty command' {
            InModuleScope $script:moduleName {
                { [StepModel]::new('Test', '') } | Should -Throw '*Command*'
            }
        }
    }

    Context 'Args and Parameters Support' {
        It 'Supports positional args array' {
            InModuleScope $script:moduleName {
                $step = [StepModel]::new('Test', 'Test-Command')
                $step.Args = @('arg1', 'arg2', 123)

                $step.Args.Count | Should -Be 3
                $step.Args[0] | Should -Be 'arg1'
                $step.Args[2] | Should -Be 123
            }
        }

        It 'Supports named parameters hashtable' {
            InModuleScope $script:moduleName {
                $step = [StepModel]::new('Test', 'Test-Command')
                $step.Parameters = @{
                    Verbose    = $true
                    DiskNumber = 0
                }

                $step.Parameters.Count | Should -Be 2
                $step.Parameters['Verbose'] | Should -BeTrue
                $step.Parameters['DiskNumber'] | Should -Be 0
            }
        }

        It 'Supports both args and parameters simultaneously' {
            InModuleScope $script:moduleName {
                $step = [StepModel]::new('Test', 'Test-Command')
                $step.Args = @('positional1')
                $step.Parameters = @{ Named1 = 'value1' }

                $step.Args.Count | Should -Be 1
                $step.Parameters.Count | Should -Be 1
            }
        }
    }

    Context 'Validation' {
        It 'Validate throws when Name is missing' {
            InModuleScope $script:moduleName {
                $step = [StepModel]::new()
                $step.Command = 'Test-Command'

                { $step.Validate() } | Should -Throw '*Name*'
            }
        }

        It 'Validate throws on invalid architecture' {
            InModuleScope $script:moduleName {
                $step = [StepModel]::new('Test', 'Test-Command')
                $step.Rules.Architecture = @('invalid')

                { $step.Validate() } | Should -Throw '*architecture*'
            }
        }
    }

    Context 'Serialization' {
        It 'ToJson produces valid JSON matching workflow schema' {
            InModuleScope $script:moduleName {
                $step = [StepModel]::new('Initialize', 'Initialize-MCDEnvironment')
                $step.Description = 'Initialize the environment'
                $step.Args = @()
                $step.Parameters = @{ Verbose = $true }
                $step.Rules.Skip = $false
                $step.Rules.RunInWinPE = $true
                $step.Rules.Retry.Enabled = $true
                $step.Rules.Retry.MaxAttempts = 3

                $json = $step.ToJson()

                $json | Should -Match '"name"'
                $json | Should -Match '"command"'
                $json | Should -Match '"args"'
                $json | Should -Match '"parameters"'
                $json | Should -Match '"rules"'

                $parsed = $json | ConvertFrom-Json
                $parsed.name | Should -Be 'Initialize'
                $parsed.command | Should -Be 'Initialize-MCDEnvironment'
            }
        }

        It 'FromHashtable parses schema-compliant data' {
            InModuleScope $script:moduleName {
                $data = @{
                    name        = 'Format Disk'
                    description = 'Wipe and partition the primary system disk.'
                    command     = 'Invoke-MCDDiskPart'
                    args        = @()
                    parameters  = @{ DiskNumber = 0 }
                    rules       = @{
                        skip            = $false
                        runinfullos     = $false
                        runinwinpe      = $true
                        architecture    = @('amd64')
                        retry           = @{
                            enabled     = $false
                            maxAttempts = 3
                            retryDelay  = 5
                        }
                        continueOnError = $false
                    }
                }

                $step = [StepModel]::FromHashtable($data)

                $step.Name | Should -Be 'Format Disk'
                $step.Command | Should -Be 'Invoke-MCDDiskPart'
                $step.Parameters['DiskNumber'] | Should -Be 0
                $step.Rules.Architecture | Should -Contain 'amd64'
                $step.Rules.RunInWinPE | Should -BeTrue
            }
        }

        It 'FromJson round-trips correctly' {
            InModuleScope $script:moduleName {
                $original = [StepModel]::new('Test', 'Test-Cmd')
                $original.Args = @('arg1')
                $original.Parameters = @{ Key = 'Value' }
                $json = $original.ToJson()

                $restored = [StepModel]::FromJson($json)

                $restored.Name | Should -Be 'Test'
                $restored.Command | Should -Be 'Test-Cmd'
                $restored.Args.Count | Should -Be 1
                $restored.Parameters['Key'] | Should -Be 'Value'
            }
        }
    }
}

Describe 'WorkflowEditorModel Class' {
    Context 'Construction' {
        It 'Creates instance with default constructor' {
            InModuleScope $script:moduleName {
                $workflow = [WorkflowEditorModel]::new()

                $workflow | Should -Not -BeNullOrEmpty
                $workflow.Id | Should -Not -BeNullOrEmpty
                # Use direct assertion for empty list (pipeline unwraps empty collections)
                $null -ne $workflow.Steps | Should -BeTrue
                $workflow.Steps.Count | Should -Be 0
                $workflow.Amd64 | Should -BeTrue
                $workflow.Arm64 | Should -BeTrue
            }
        }

        It 'Creates instance with name' {
            InModuleScope $script:moduleName {
                $workflow = [WorkflowEditorModel]::new('Test Workflow')

                $workflow.Name | Should -Be 'Test Workflow'
                $workflow.Id | Should -Not -BeNullOrEmpty
            }
        }

        It 'Throws on empty name' {
            InModuleScope $script:moduleName {
                { [WorkflowEditorModel]::new('') } | Should -Throw '*Name*'
            }
        }
    }

    Context 'Step Management' {
        It 'AddStep adds step to list' {
            InModuleScope $script:moduleName {
                $workflow = [WorkflowEditorModel]::new('Test')
                $step = [StepModel]::new('Step1', 'Cmd1')

                $workflow.AddStep($step)

                $workflow.Steps.Count | Should -Be 1
                $workflow.Steps[0].Name | Should -Be 'Step1'
            }
        }

        It 'RemoveStep removes step by index' {
            InModuleScope $script:moduleName {
                $workflow = [WorkflowEditorModel]::new('Test')
                $workflow.AddStep([StepModel]::new('Step1', 'Cmd1'))
                $workflow.AddStep([StepModel]::new('Step2', 'Cmd2'))

                $workflow.RemoveStep(0)

                $workflow.Steps.Count | Should -Be 1
                $workflow.Steps[0].Name | Should -Be 'Step2'
            }
        }

        It 'RemoveStep throws on invalid index' {
            InModuleScope $script:moduleName {
                $workflow = [WorkflowEditorModel]::new('Test')

                { $workflow.RemoveStep(0) } | Should -Throw
            }
        }

        It 'MoveStep reorders steps' {
            InModuleScope $script:moduleName {
                $workflow = [WorkflowEditorModel]::new('Test')
                $workflow.AddStep([StepModel]::new('Step1', 'Cmd1'))
                $workflow.AddStep([StepModel]::new('Step2', 'Cmd2'))
                $workflow.AddStep([StepModel]::new('Step3', 'Cmd3'))

                $workflow.MoveStep(0, 2)

                $workflow.Steps[0].Name | Should -Be 'Step2'
                $workflow.Steps[2].Name | Should -Be 'Step1'
            }
        }
    }

    Context 'Validation' {
        It 'Validate throws when no architecture enabled' {
            InModuleScope $script:moduleName {
                $workflow = [WorkflowEditorModel]::new('Test')
                $workflow.Amd64 = $false
                $workflow.Arm64 = $false

                { $workflow.Validate() } | Should -Throw '*architecture*'
            }
        }

        It 'Validate cascades to steps' {
            InModuleScope $script:moduleName {
                $workflow = [WorkflowEditorModel]::new('Test')
                $invalidStep = [StepModel]::new()  # Missing required fields
                $workflow.Steps.Add($invalidStep)

                { $workflow.Validate() } | Should -Throw
            }
        }
    }

    Context 'Serialization' {
        It 'ToJson matches workflow schema structure' {
            InModuleScope $script:moduleName {
                $workflow = [WorkflowEditorModel]::new('Default Deployment')
                $workflow.Description = 'Standard cloud deployment workflow for Windows 11 Enterprise.'
                $workflow.Version = '1.0.0'
                $workflow.Author = 'MCD Team'
                $workflow.Default = $true

                $step = [StepModel]::new('Initialize', 'Initialize-MCDEnvironment')
                $step.Description = 'Prepare the WinPE environment'
                $workflow.AddStep($step)

                $json = $workflow.ToJson()

                $json | Should -Match '"id"'
                $json | Should -Match '"name"'
                $json | Should -Match '"description"'
                $json | Should -Match '"version"'
                $json | Should -Match '"author"'
                $json | Should -Match '"amd64"'
                $json | Should -Match '"arm64"'
                $json | Should -Match '"default"'
                $json | Should -Match '"steps"'

                $parsed = $json | ConvertFrom-Json
                $parsed.name | Should -Be 'Default Deployment'
                $parsed.steps.Count | Should -Be 1
            }
        }

        It 'FromJson round-trips correctly' {
            InModuleScope $script:moduleName {
                $original = [WorkflowEditorModel]::new('Test Workflow')
                $original.Author = 'Test Author'
                $original.AddStep([StepModel]::new('Step1', 'Cmd1'))
                $json = $original.ToJson()

                $restored = [WorkflowEditorModel]::FromJson($json)

                $restored.Name | Should -Be 'Test Workflow'
                $restored.Author | Should -Be 'Test Author'
                $restored.Steps.Count | Should -Be 1
            }
        }
    }
}

Describe 'BootImageModel Class' {
    Context 'Construction' {
        It 'Creates instance with path' {
            InModuleScope $script:moduleName {
                $model = [BootImageModel]::new('C:\Images\boot.wim')

                $model.Path | Should -Be 'C:\Images\boot.wim'
                $model.Name | Should -Be 'boot.wim'
                $model.IsValid | Should -BeFalse
            }
        }

        It 'Throws on empty path' {
            InModuleScope $script:moduleName {
                { [BootImageModel]::new('') } | Should -Throw '*Path*'
            }
        }
    }

    Context 'Validation' {
        It 'Validate throws on invalid architecture' {
            InModuleScope $script:moduleName {
                $model = [BootImageModel]::new('C:\test.wim')
                $model.Architecture = 'x86'

                { $model.Validate() } | Should -Throw '*architecture*'
            }
        }
    }

    Context 'Serialization' {
        It 'ToJson and FromJson round-trip correctly' {
            InModuleScope $script:moduleName {
                $original = [BootImageModel]::new('C:\boot.wim')
                $original.Architecture = 'amd64'
                $original.Version = '10.0.22621'
                $original.SizeBytes = 1024000
                $original.IsValid = $true
                $json = $original.ToJson()

                $restored = [BootImageModel]::FromJson($json)

                $restored.Path | Should -Be 'C:\boot.wim'
                $restored.Architecture | Should -Be 'amd64'
                $restored.SizeBytes | Should -Be 1024000
            }
        }
    }
}

Describe 'USBModel Class' {
    Context 'Construction' {
        It 'Creates instance with drive letter' {
            InModuleScope $script:moduleName {
                $model = [USBModel]::new('E')

                $model.DriveLetter | Should -Be 'E:'
            }
        }

        It 'Normalizes drive letter format' {
            InModuleScope $script:moduleName {
                $model = [USBModel]::new('e:')

                $model.DriveLetter | Should -Be 'E:'
            }
        }
    }

    Context 'Validation' {
        It 'Validate throws on invalid drive letter format' {
            InModuleScope $script:moduleName {
                $model = [USBModel]::new()
                $model.DriveLetter = 'Invalid'

                { $model.Validate() } | Should -Throw '*drive letter*'
            }
        }

        It 'Validate throws on negative SizeBytes' {
            InModuleScope $script:moduleName {
                $model = [USBModel]::new('E')
                $model.SizeBytes = -100

                { $model.Validate() } | Should -Throw '*SizeBytes*'
            }
        }
    }

    Context 'Serialization' {
        It 'ToJson and FromJson round-trip correctly' {
            InModuleScope $script:moduleName {
                $original = [USBModel]::new('F')
                $original.FriendlyName = 'SanDisk USB'
                $original.SizeBytes = 16000000000
                $original.FileSystem = 'FAT32'
                $original.IsBootable = $true
                $json = $original.ToJson()

                $restored = [USBModel]::FromJson($json)

                $restored.DriveLetter | Should -Be 'F:'
                $restored.FriendlyName | Should -Be 'SanDisk USB'
                $restored.IsBootable | Should -BeTrue
            }
        }
    }
}

Describe 'ADKInstallerModel Class' {
    Context 'Construction' {
        It 'Creates instance with install path' {
            InModuleScope $script:moduleName {
                $model = [ADKInstallerModel]::new('C:\Program Files (x86)\Windows Kits\10')

                $model.InstallPath | Should -Be 'C:\Program Files (x86)\Windows Kits\10'
                $model.IsInstalled | Should -BeFalse
            }
        }
    }

    Context 'Validation' {
        It 'Validate throws when installed but no path' {
            InModuleScope $script:moduleName {
                $model = [ADKInstallerModel]::new()
                $model.IsInstalled = $true
                $model.InstallPath = $null

                { $model.Validate() } | Should -Throw '*InstallPath*'
            }
        }

        It 'Validate throws when HasWinPEAddOn but no path' {
            InModuleScope $script:moduleName {
                $model = [ADKInstallerModel]::new()
                $model.HasWinPEAddOn = $true
                $model.WinPEAddOnPath = $null

                { $model.Validate() } | Should -Throw '*WinPEAddOnPath*'
            }
        }
    }

    Context 'Serialization' {
        It 'ToJson and FromJson round-trip correctly' {
            InModuleScope $script:moduleName {
                $original = [ADKInstallerModel]::new('C:\ADK')
                $original.Version = '10.1.22621.1'
                $original.IsInstalled = $true
                $original.HasWinPEAddOn = $true
                $original.WinPEAddOnPath = 'C:\ADK\WinPE'
                $json = $original.ToJson()

                $restored = [ADKInstallerModel]::FromJson($json)

                $restored.InstallPath | Should -Be 'C:\ADK'
                $restored.Version | Should -Be '10.1.22621.1'
                $restored.HasWinPEAddOn | Should -BeTrue
            }
        }
    }
}

Describe 'BootImageCacheItem Class' {
    Context 'Construction' {
        It 'Creates instance with source and cache paths' {
            InModuleScope $script:moduleName {
                $model = [BootImageCacheItem]::new('C:\Source\boot.wim', 'C:\Cache\boot.wim')

                $model.SourcePath | Should -Be 'C:\Source\boot.wim'
                $model.CachePath | Should -Be 'C:\Cache\boot.wim'
                $model.Id | Should -Not -BeNullOrEmpty
            }
        }

        It 'Throws on empty source path' {
            InModuleScope $script:moduleName {
                { [BootImageCacheItem]::new('', 'C:\Cache') } | Should -Throw '*SourcePath*'
            }
        }
    }

    Context 'Operations' {
        It 'UpdateLastAccessed updates timestamp' {
            InModuleScope $script:moduleName {
                $model = [BootImageCacheItem]::new('C:\Source', 'C:\Cache')
                $original = $model.LastAccessedAt
                Start-Sleep -Milliseconds 100

                $model.UpdateLastAccessed()

                $model.LastAccessedAt | Should -BeGreaterThan $original
            }
        }
    }

    Context 'Validation' {
        It 'Validate throws on invalid architecture' {
            InModuleScope $script:moduleName {
                $model = [BootImageCacheItem]::new('C:\Source', 'C:\Cache')
                $model.Architecture = 'invalid'

                { $model.Validate() } | Should -Throw '*architecture*'
            }
        }

        It 'Validate throws on negative SizeBytes' {
            InModuleScope $script:moduleName {
                $model = [BootImageCacheItem]::new('C:\Source', 'C:\Cache')
                $model.SizeBytes = -1

                { $model.Validate() } | Should -Throw '*SizeBytes*'
            }
        }
    }

    Context 'Serialization' {
        It 'ToJson and FromJson round-trip correctly' {
            InModuleScope $script:moduleName {
                $original = [BootImageCacheItem]::new('C:\Source\boot.wim', 'C:\Cache\boot.wim')
                $original.Architecture = 'arm64'
                $original.Hash = 'ABC123'
                $original.SizeBytes = 500000
                $original.IsValid = $true
                $json = $original.ToJson()

                $restored = [BootImageCacheItem]::FromJson($json)

                $restored.SourcePath | Should -Be 'C:\Source\boot.wim'
                $restored.Architecture | Should -Be 'arm64'
                $restored.Hash | Should -Be 'ABC123'
                $restored.IsValid | Should -BeTrue
            }
        }
    }
}
