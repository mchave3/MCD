BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\.." | Convert-Path
    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }
    $script:moduleName = $ProjectName
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

Describe 'Test-MCDPrerequisite' {
    It 'Returns true when RequireFullOS is met' {
        InModuleScope $script:moduleName {
            Mock Get-MCDExecutionContext -MockWith {
                [PSCustomObject]@{ IsWinPE = $false }
            }

            Test-MCDPrerequisite -RequireFullOS | Should -BeTrue
        }
    }

    It 'Throws when RequireWinPE is not met' {
        InModuleScope $script:moduleName {
            Mock Get-MCDExecutionContext -MockWith {
                [PSCustomObject]@{ IsWinPE = $false }
            }

            { Test-MCDPrerequisite -RequireWinPE } | Should -Throw
        }
    }
}
