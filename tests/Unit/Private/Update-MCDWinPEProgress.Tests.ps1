BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\.." | Convert-Path
    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }
    $script:moduleName = $ProjectName
    Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase -ErrorAction SilentlyContinue
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

Describe 'Update-MCDWinPEProgress' {
    BeforeEach {
        InModuleScope $script:moduleName {
            $script:xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <StackPanel>
    <TextBlock x:Name="StepCounterText" />
    <TextBlock x:Name="CurrentStepText" />
    <ProgressBar x:Name="DeploymentProgressBar" />
    <TextBlock x:Name="ProgressPercentText" />
  </StackPanel>
</Window>
'@
            $reader = New-Object System.Xml.XmlNodeReader ([xml]$script:xaml)
            $script:testWindow = [Windows.Markup.XamlReader]::Load($reader)
        }
    }

    Context 'Updates UI controls' {
        It 'Updates named controls when present' {
            InModuleScope $script:moduleName {
                Update-MCDWinPEProgress -Window $script:testWindow -StepName 'Test' -StepIndex 1 -StepCount 3 -Percent 10
                $script:testWindow.FindName('CurrentStepText').Text | Should -Be 'Test'
                $script:testWindow.FindName('ProgressPercentText').Text | Should -Be '10 %'
            }
        }

        It 'Updates step counter text correctly' {
            InModuleScope $script:moduleName {
                Update-MCDWinPEProgress -Window $script:testWindow -StepName 'Step Two' -StepIndex 2 -StepCount 5 -Percent 40
                $script:testWindow.FindName('StepCounterText').Text | Should -Be 'Step: 2 of 5'
            }
        }

        It 'Sets progress bar value correctly' {
            InModuleScope $script:moduleName {
                Update-MCDWinPEProgress -Window $script:testWindow -StepName 'Progress Step' -StepIndex 3 -StepCount 4 -Percent 75
                $script:testWindow.FindName('DeploymentProgressBar').Value | Should -Be 75
            }
        }

        It 'Sets progress bar to indeterminate when switch is provided' {
            InModuleScope $script:moduleName {
                Update-MCDWinPEProgress -Window $script:testWindow -StepName 'Loading' -StepIndex 1 -StepCount 2 -Percent 0 -Indeterminate
                $script:testWindow.FindName('DeploymentProgressBar').IsIndeterminate | Should -Be $true
            }
        }
    }

    Context 'Dispatcher-safe behavior' {
        It 'Does not throw when called from the UI thread' {
            InModuleScope $script:moduleName {
                { Update-MCDWinPEProgress -Window $script:testWindow -StepName 'UIThread' -StepIndex 1 -StepCount 1 -Percent 50 } | Should -Not -Throw
            }
        }

        It 'Has Dispatcher property on window' {
            InModuleScope $script:moduleName {
                # Verify the window has a Dispatcher (required for cross-thread safety)
                $script:testWindow.Dispatcher | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'ShouldProcess support' {
        It 'Respects WhatIf and does not update controls' {
            InModuleScope $script:moduleName {
                $originalText = $script:testWindow.FindName('CurrentStepText').Text
                Update-MCDWinPEProgress -Window $script:testWindow -StepName 'ShouldNotAppear' -StepIndex 1 -StepCount 1 -Percent 50 -WhatIf
                $script:testWindow.FindName('CurrentStepText').Text | Should -Be $originalText
            }
        }
    }
}
