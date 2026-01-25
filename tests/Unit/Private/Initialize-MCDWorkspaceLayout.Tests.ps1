BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\.." | Convert-Path
    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }
    $script:moduleName = $ProjectName
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

Describe 'Initialize-MCDWorkspaceLayout' {
    It 'Creates workspace directories and profile configs' {
        InModuleScope $script:moduleName {
            Mock Get-MCDExecutionContext -MockWith {
                [PSCustomObject]@{
                    WorkspacesRoot = (Join-Path -Path $TestDrive -ChildPath 'Workspaces')
                    ProfilesRoot   = (Join-Path -Path $TestDrive -ChildPath 'Profiles')
                }
            }

            $result = Initialize-MCDWorkspaceLayout -ProfileName 'Default' -Confirm:$false

            Test-Path -Path $result.WorkspaceRoot | Should -BeTrue
            Test-Path -Path (Join-Path -Path $TestDrive -ChildPath 'Profiles\\Default\\Workspace.json') | Should -BeTrue
            Test-Path -Path (Join-Path -Path $TestDrive -ChildPath 'Profiles\\Default\\WinPE.json') | Should -BeTrue
        }
    }
}
