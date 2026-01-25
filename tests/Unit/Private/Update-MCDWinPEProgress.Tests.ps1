BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\.." | Convert-Path
    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }
    $script:moduleName = $ProjectName
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

Describe 'Update-MCDWinPEProgress' {
    It 'Updates named controls when present' {
        InModuleScope $script:moduleName {
            $xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <StackPanel>
    <TextBlock x:Name="StepCounterText" />
    <TextBlock x:Name="CurrentStepText" />
    <ProgressBar x:Name="DeploymentProgressBar" />
    <TextBlock x:Name="ProgressPercentText" />
  </StackPanel>
</Window>
'@
            Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase
            $reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
            $window = [Windows.Markup.XamlReader]::Load($reader)

            Update-MCDWinPEProgress -Window $window -StepName 'Test' -StepIndex 1 -StepCount 3 -Percent 10
            $window.FindName('CurrentStepText').Text | Should -Be 'Test'
            $window.FindName('ProgressPercentText').Text | Should -Be '10 %'
        }
    }
}
