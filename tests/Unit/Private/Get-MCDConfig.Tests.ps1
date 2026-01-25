BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\.." | Convert-Path
    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }
    $script:moduleName = $ProjectName
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

Describe 'Get-MCDConfig' {
    It 'Returns null when config file does not exist' {
        InModuleScope $script:moduleName {
            Mock Get-MCDExecutionContext -MockWith {
                [PSCustomObject]@{
                    ProfilesRoot = (Join-Path -Path $TestDrive -ChildPath 'Profiles')
                }
            }

            Get-MCDConfig -ConfigName Workspace -ProfileName 'Default' | Should -BeNullOrEmpty
        }
    }

    It 'Loads config when the file exists' {
        InModuleScope $script:moduleName {
            Mock Get-MCDExecutionContext -MockWith {
                [PSCustomObject]@{
                    ProfilesRoot = (Join-Path -Path $TestDrive -ChildPath 'Profiles')
                }
            }

            $profileRoot = Join-Path -Path $TestDrive -ChildPath 'Profiles\\Default'
            $null = New-Item -Path $profileRoot -ItemType Directory -Force
            Set-Content -Path (Join-Path -Path $profileRoot -ChildPath 'Workspace.json') -Value '{"Hello":"World"}' -Encoding utf8

            $config = Get-MCDConfig -ConfigName Workspace -ProfileName 'Default'
            $config.Hello | Should -Be 'World'
        }
    }
}
