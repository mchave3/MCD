BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\.." | Convert-Path
    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }
    $script:moduleName = $ProjectName
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

Describe 'Get-MCDExternalVolume' {
    It 'Returns filesystem drives excluding C and X' {
        InModuleScope $script:moduleName {
            $driveName = 'Z'
            $null = New-PSDrive -Name $driveName -PSProvider FileSystem -Root $TestDrive -ErrorAction Stop

            $drives = Get-MCDExternalVolume
            ($drives.Name -contains $driveName) | Should -BeTrue
        }
    }
}
