BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\.." | Convert-Path
    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }
    $script:moduleName = $ProjectName
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

Describe 'Get-MCDAvailableDriveLetter' {
    It 'Returns first available preferred letter' {
        InModuleScope $script:moduleName {
            Mock Get-PSDrive -MockWith {
                @(
                    [pscustomobject]@{ Name = 'C'; Provider = 'FileSystem' }
                    [pscustomobject]@{ Name = 'X'; Provider = 'FileSystem' }
                    [pscustomobject]@{ Name = 'S'; Provider = 'FileSystem' }
                )
            }

            $letter = Get-MCDAvailableDriveLetter -PreferredLetters @('S', 'W') -FallbackLetters @('D')
            $letter | Should -Be 'W'
        }
    }

    It 'Treats ExcludeLetters as unavailable' {
        InModuleScope $script:moduleName {
            Mock Get-PSDrive -MockWith {
                @(
                    [pscustomobject]@{ Name = 'C'; Provider = 'FileSystem' }
                    [pscustomobject]@{ Name = 'X'; Provider = 'FileSystem' }
                )
            }

            $letter = Get-MCDAvailableDriveLetter -PreferredLetters @('W') -FallbackLetters @('D') -ExcludeLetters @('W')
            $letter | Should -Be 'D'
        }
    }
}
