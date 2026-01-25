BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\.." | Convert-Path
    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }
    $script:moduleName = $ProjectName
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

Describe 'Get-MCDExecutionContext' {
    It 'Returns a context object with expected properties' {
        InModuleScope $script:moduleName {
            $context = Get-MCDExecutionContext

            $context | Should -Not -BeNullOrEmpty
            $context.PSObject.Properties.Name | Should -Contain 'IsWinPE'
            $context.PSObject.Properties.Name | Should -Contain 'DataRoot'
            $context.PSObject.Properties.Name | Should -Contain 'LogsRoot'
            $context.PSObject.Properties.Name | Should -Contain 'XamlRoot'
        }
    }
}
