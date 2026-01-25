BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\.." | Convert-Path
    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }
    $script:moduleName = $ProjectName
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

Describe 'Write-MCDLog' {
    It 'Writes a log line to a provided path' {
        InModuleScope $script:moduleName {
            $logPath = Join-Path -Path $TestDrive -ChildPath 'mcd.log'
            Write-MCDLog -Level Info -Message 'hello' -Path $logPath

            Test-Path -Path $logPath | Should -BeTrue
            (Get-Content -Path $logPath -Raw) | Should -Match 'hello'
        }
    }
}
