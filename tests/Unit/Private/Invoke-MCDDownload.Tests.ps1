BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\.." | Convert-Path
    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }
    $script:moduleName = $ProjectName
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

Describe 'Invoke-MCDDownload' {
    BeforeEach {
        Mock Invoke-WebRequest -ModuleName $script:moduleName -MockWith {
            Set-Content -Path $OutFile -Value 'ok' -Encoding utf8
        }
    }

    It 'Creates the destination file and returns it' {
        InModuleScope $script:moduleName {
            $dest = Join-Path -Path $TestDrive -ChildPath 'file.txt'
            $item = Invoke-MCDDownload -Uri 'https://example.invalid/file.txt' -DestinationPath $dest -Force

            $item.FullName | Should -Be $dest
            Test-Path -Path $dest | Should -BeTrue
        }
    }
}
