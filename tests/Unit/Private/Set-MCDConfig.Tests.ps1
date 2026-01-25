BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\.." | Convert-Path
    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }
    $script:moduleName = $ProjectName
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

Describe 'Set-MCDConfig' {
    It 'Writes a JSON file to the profile folder' {
        InModuleScope $script:moduleName {
            Mock Get-MCDExecutionContext -MockWith {
                [PSCustomObject]@{
                    ProfilesRoot = (Join-Path -Path $TestDrive -ChildPath 'Profiles')
                }
            }

            $null = Set-MCDConfig -ConfigName Workspace -ProfileName 'Default' -Data @{ Hello = 'World' } -Confirm:$false

            $path = Join-Path -Path $TestDrive -ChildPath 'Profiles\\Default\\Workspace.json'
            Test-Path -Path $path | Should -BeTrue
        }
    }
}
