BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\.." | Convert-Path
    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }
    $script:moduleName = $ProjectName
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

Describe 'Find-MCDWifiProfile' {
    It 'Returns null when no match exists' {
        InModuleScope $script:moduleName {
            Mock Get-MCDExternalVolume -MockWith { @() }
            Find-MCDWifiProfile -RelativePaths @('MCD\\Config\\WiFi\\*.xml') | Should -BeNullOrEmpty
        }
    }
}
