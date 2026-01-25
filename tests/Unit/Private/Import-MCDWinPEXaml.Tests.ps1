BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\.." | Convert-Path
    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }
    $script:moduleName = $ProjectName
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

Describe 'Import-MCDWinPEXaml' {
    It 'Throws when XamlPath does not exist' {
        { Import-MCDWinPEXaml -XamlPath (Join-Path -Path $TestDrive -ChildPath 'missing.xaml') } | Should -Throw
    }
}
