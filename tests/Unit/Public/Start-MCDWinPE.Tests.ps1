BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\.." | Convert-Path

    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }

    $script:moduleName = $ProjectName
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

Describe 'Start-MCDWinPE' {
    Context 'When not running in WinPE' {
        BeforeEach {
            Mock Get-MCDExecutionContext -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    IsWinPE = $false
                }
            }
        }

        It 'Throws' {
            { Start-MCDWinPE -ProfileName 'Default' -NoUI } | Should -Throw
        }
    }

    Context 'When running in WinPE' {
        BeforeEach {
            Mock Get-MCDExecutionContext -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    IsWinPE  = $true
                    XamlRoot = 'X:\\Xaml'
                }
            }

            Mock Write-MCDLog -ModuleName $script:moduleName
            Mock Get-MCDConfig -ModuleName $script:moduleName -MockWith { $null }

            Mock Test-MCDNetwork -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    HasDhcp     = $true
                    HasInternet = $true
                }
            }

            Mock Update-MCDFromPSGallery -ModuleName $script:moduleName -MockWith { $true }
        }

        It 'Checks for updates when online (unless skipped)' {
            Start-MCDWinPE -ProfileName 'Default' -NoUI
            Should -Invoke Update-MCDFromPSGallery -ModuleName $script:moduleName -Times 1
        }

        It 'Does not update when SkipModuleUpdate is set' {
            Start-MCDWinPE -ProfileName 'Default' -SkipModuleUpdate -NoUI
            Should -Invoke Update-MCDFromPSGallery -ModuleName $script:moduleName -Times 0
        }
    }
}
