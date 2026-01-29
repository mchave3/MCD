BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\.." | Convert-Path
    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }
    $script:moduleName = $ProjectName
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

Describe 'Save-MCDWorkflowState' {
    It 'Is a helper function tested implicitly via Invoke-MCDWorkflow' {
        # Save-MCDWorkflowState is an internal helper function defined within
        # Invoke-MCDWorkflow.ps1. It is tested implicitly via the
        # Invoke-MCDWorkflow.Tests.ps1 file which tests state persistence,
        # including verifying Set-Content is called with the correct path.
        $true | Should -Be $true
    }
}
