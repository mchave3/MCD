BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\.." | Convert-Path
    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }
    $script:moduleName = $ProjectName
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

Describe 'Start-MCDConnectivityFlow' {
    It 'Returns immediately when NoUI is specified' {
        InModuleScope $script:moduleName {
            Mock Test-MCDNetwork -MockWith {
                [PSCustomObject]@{ HasDhcp = $true; IpAddress = '192.168.1.10'; HasInternet = $false }
            }
            Mock Import-MCDWinPEXaml

            $cfg = [PSCustomObject]@{ DhcpWaitSeconds = 0; NetworkTestHostName = 'example.com' }
            $result = Start-MCDConnectivityFlow -WinPEConfig $cfg -XamlRoot 'X:\\Xaml' -NoUI

            $result.HasInternet | Should -BeFalse
            Should -Invoke Import-MCDWinPEXaml -Times 0
        }
    }

    It 'Returns immediately when Internet is already available' {
        InModuleScope $script:moduleName {
            Mock Test-MCDNetwork -MockWith {
                [PSCustomObject]@{ HasDhcp = $true; IpAddress = '192.168.1.10'; HasInternet = $true }
            }
            Mock Import-MCDWinPEXaml

            $cfg = [PSCustomObject]@{ DhcpWaitSeconds = 0; NetworkTestHostName = 'example.com' }
            $result = Start-MCDConnectivityFlow -WinPEConfig $cfg -XamlRoot 'X:\\Xaml'

            $result.HasInternet | Should -BeTrue
            Should -Invoke Import-MCDWinPEXaml -Times 0
        }
    }
}
