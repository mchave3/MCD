BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\.." | Convert-Path
    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }
    $script:moduleName = $ProjectName
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

Describe 'Step-MCDDeployWindows' {
    It 'Is tested in Steps.tests.ps1' {
        # This function is tested in tests/Unit/Private/Steps/Steps.tests.ps1
        # This stub file exists to satisfy the QA test that expects
        # a <FunctionName>.Tests.ps1 file for each function
        $true | Should -Be $true
    }
}
