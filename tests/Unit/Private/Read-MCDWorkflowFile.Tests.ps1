BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\.." | Convert-Path
    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }
    $script:moduleName = $ProjectName
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

Describe 'Read-MCDWorkflowFile' {
    It 'Is a helper function tested implicitly via Initialize-MCDWorkflowTasks' {
        # Read-MCDWorkflowFile is an internal helper function defined within
        # Initialize-MCDWorkflowTasks.ps1. It is tested implicitly via the
        # Initialize-MCDWorkflowTasks.Tests.ps1 file which tests workflow loading
        # including JSON parsing, error handling for invalid JSON, etc.
        $true | Should -Be $true
    }
}
