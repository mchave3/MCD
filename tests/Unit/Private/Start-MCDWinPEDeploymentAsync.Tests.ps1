BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\.." | Convert-Path
    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }
    $script:moduleName = $ProjectName
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

Describe 'Start-MCDWinPEDeploymentAsync' {
    It 'Is available as a command' {
        InModuleScope $script:moduleName {
            Get-Command -Name Start-MCDWinPEDeploymentAsync -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }
    }
}
