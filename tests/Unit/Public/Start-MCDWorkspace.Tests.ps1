BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\.." | Convert-Path

    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }

    $script:moduleName = $ProjectName
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

Describe 'Start-MCDWorkspace' {
    Context 'When running on full Windows' {
        BeforeEach {
            Mock Get-MCDExecutionContext -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    IsWinPE = $false
                }
            }

            Mock Write-MCDLog -ModuleName $script:moduleName

            Mock Initialize-MCDWorkspaceLayout -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{ ProfileName = $ProfileName }
            }
        }

        It 'Invokes Initialize-MCDWorkspaceLayout' {
            $result = Start-MCDWorkspace -ProfileName 'Test'

            $result.ProfileName | Should -Be 'Test'
            Should -Invoke Initialize-MCDWorkspaceLayout -ModuleName $script:moduleName -Times 1 -ParameterFilter {
                $ProfileName -eq 'Test'
            }
        }
    }

    Context 'When running in WinPE' {
        BeforeEach {
            Mock Get-MCDExecutionContext -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    IsWinPE = $true
                }
            }
        }

        It 'Throws' {
            { Start-MCDWorkspace -ProfileName 'Test' } | Should -Throw
        }
    }
}
