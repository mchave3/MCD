BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\.." | Convert-Path
    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }
    $script:moduleName = $ProjectName
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

Describe 'Test-MCDNetwork' {
    It 'Returns a result object without waiting when WaitForDhcpSeconds is 0' {
        InModuleScope $script:moduleName {
            $result = Test-MCDNetwork -WaitForDhcpSeconds 0 -TestHostName 'example.com'

            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain 'HasDhcp'
            $result.PSObject.Properties.Name | Should -Contain 'HasInternet'
        }
    }
}
