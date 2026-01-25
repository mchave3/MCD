BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\.." | Convert-Path
    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }
    $script:moduleName = $ProjectName
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

Describe 'Update-MCDFromPSGallery' {
    BeforeEach {
        Mock Write-MCDLog -ModuleName $script:moduleName
        Mock Import-Module -ModuleName $script:moduleName
        Mock Install-Module -ModuleName $script:moduleName
    }

    It 'Installs when the gallery version is newer' {
        InModuleScope $script:moduleName {
            Mock Get-Module -MockWith {
                [PSCustomObject]@{ Version = [version]'0.0.1' }
            }

            Mock Find-Module -MockWith {
                [PSCustomObject]@{ Version = [version]'0.0.2' }
            }

            $result = Update-MCDFromPSGallery -ModuleName 'MCD' -Confirm:$false
            $result | Should -BeTrue
            Should -Invoke Install-Module -Times 1
        }
    }
}
