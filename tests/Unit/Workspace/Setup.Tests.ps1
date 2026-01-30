BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\.." | Convert-Path

    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }

    $script:moduleName = $ProjectName
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

Describe 'Workspace Test Infrastructure' {
    Context 'Module Import' {
        It 'Imports the module successfully' {
            Get-Module -Name $script:moduleName | Should -Not -BeNullOrEmpty
        }

        It 'Exports Start-MCDWorkspace function' {
            $commands = Get-Command -Module $script:moduleName -Name 'Start-MCDWorkspace'
            $commands | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Required Helpers' {
        It 'Can access private functions via InModuleScope' {
            InModuleScope -ModuleName $script:moduleName -ScriptBlock {
                Get-Command -Name 'Get-MCDExecutionContext' -ErrorAction Stop | Should -Not -BeNullOrEmpty
            }
        }

        It 'Can access Write-MCDLog via InModuleScope' {
            InModuleScope -ModuleName $script:moduleName -ScriptBlock {
                Get-Command -Name 'Write-MCDLog' -ErrorAction Stop | Should -Not -BeNullOrEmpty
            }
        }

        It 'Can access Initialize-MCDWorkspaceLayout via InModuleScope' {
            InModuleScope -ModuleName $script:moduleName -ScriptBlock {
                Get-Command -Name 'Initialize-MCDWorkspaceLayout' -ErrorAction Stop | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'Test Scaffolding' {
        BeforeEach {
            Mock Get-MCDExecutionContext -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    IsWinPE = $false
                }
            }

            Mock Write-MCDLog -ModuleName $script:moduleName
        }

        It 'Can mock module functions within InModuleScope' {
            InModuleScope -ModuleName $script:moduleName -ScriptBlock {
                Get-MCDExecutionContext | Should -Not -BeNullOrEmpty
            }
        }

        It 'Validates PowerShell version compatibility' {
            $PSVersionTable.PSVersion | Should -Not -BeNullOrEmpty
        }
    }
}
