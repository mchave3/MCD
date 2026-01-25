BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\.." | Convert-Path
    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }
    $script:moduleName = $ProjectName
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
}

Describe 'Connect-MCDWifiProfile' {
    It 'Validates XML and respects -WhatIf' {
        InModuleScope $script:moduleName {
            $xmlPath = Join-Path -Path $TestDrive -ChildPath 'WiFiProfile.xml'
            Set-Content -Path $xmlPath -Encoding utf8 -Value @'
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
  <name>TestSSID</name>
  <MSM>
    <security>
      <sharedKey>
        <protected>false</protected>
        <keyMaterial>password</keyMaterial>
      </sharedKey>
    </security>
  </MSM>
</WLANProfile>
'@

            $result = Connect-MCDWifiProfile -WifiProfilePath $xmlPath -WhatIf
            $result | Should -BeFalse
        }
    }
}
