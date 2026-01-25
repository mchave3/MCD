function Initialize-MCDWorkspaceLayout
{
    <#
    .SYNOPSIS
    Creates the directory layout for an MCD workspace profile.

    .DESCRIPTION
    Creates the workspace directory structure under %ProgramData%\MCD\Workspaces\<ProfileName>
    and writes initial profile configuration files under %ProgramData%\MCD\Profiles\<ProfileName>.

    .PARAMETER ProfileName
    Name of the profile used to create the workspace and profile configuration.

    .EXAMPLE
    Initialize-MCDWorkspaceLayout -ProfileName Default

    Creates the Default workspace directory structure and default configs.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ProfileName
    )

    $context = Get-MCDExecutionContext

    $workspaceRoot = Join-Path -Path $context.WorkspacesRoot -ChildPath $ProfileName
    $configRoot = Join-Path -Path $workspaceRoot -ChildPath 'Config'
    $logsRoot = Join-Path -Path $workspaceRoot -ChildPath 'Logs'
    $cacheRoot = Join-Path -Path $workspaceRoot -ChildPath 'Cache'
    $mediaPayloadRoot = Join-Path -Path $workspaceRoot -ChildPath 'MediaPayload'

    $paths = @($workspaceRoot, $configRoot, $logsRoot, $cacheRoot, $mediaPayloadRoot)
    foreach ($path in $paths)
    {
        if (-not (Test-Path -Path $path))
        {
            if ($PSCmdlet.ShouldProcess($path, 'Create directory'))
            {
                $null = New-Item -Path $path -ItemType Directory -Force
            }
        }
    }

    $workspaceConfig = @{
        ProfileName      = $ProfileName
        WorkspaceRoot    = $workspaceRoot
        ConfigRoot       = $configRoot
        LogsRoot         = $logsRoot
        CacheRoot        = $cacheRoot
        MediaPayloadRoot = $mediaPayloadRoot
        WizardOptions    = @{
            ComputerLanguages = @('fr-FR', 'en-US')
            OperatingSystems  = @(
                @{
                    Id = 'Win11-23H2'
                    DisplayName = 'Windows 11 23H2'
                    Source = @{ Type = 'WIM'; Path = ''; Uri = '' }
                    ImageIndex = 6
                    AllowedLanguages = @('fr-FR','en-US')
                }
                @{
                    Id = 'Win10-22H2'
                    DisplayName = 'Windows 10 22H2'
                    Source = @{ Type = 'WIM'; Path = ''; Uri = '' }
                    ImageIndex = 6
                    AllowedLanguages = @('fr-FR','en-US')
                }
            )
            DriverPacks       = @('Auto', 'Dell', 'HP', 'Lenovo', 'Surface', 'VMware')
            WinPELanguages    = @('fr-FR', 'en-US')
            Wallpaper         = @{
                Enabled = $false
                Path    = ''
            }
        }
        UpdatedAt        = (Get-Date).ToString('o')
    }

    $winpeConfig = @{
        ProfileName               = $ProfileName
        PreferPSGalleryUpdate     = $true
        EnableWirelessConnectUi   = $true
        AutoConnectWifiProfile    = $true
        WifiProfileRelativePaths  = @(
            'MCD\\Config\\WiFi\\WiFiProfile.xml'
            'MCD\\Config\\WiFi\\*.xml'
        )
        DiskPolicy                = @{
            Mode                     = 'AutoIfSingleElsePrompt'
            ExcludeBusTypes          = @('USB')
            RequireConfirmIfMultiple = $true
            AllowDestructiveActions  = $false
            DefaultDiskNumber        = $null
        }
        NetworkTestHostName       = 'google.com'
        DhcpWaitSeconds           = 20
        XamlMainWindowRelativePath = 'WinPE\\MainWindow.xaml'
        XamlConnectivityWindowRelativePath = 'WinPE\\ConnectivityWindow.xaml'
        XamlWizardWindowRelativePath       = 'WinPE\\WizardWindow.xaml'
        UpdatedAt                 = (Get-Date).ToString('o')
    }

    if ($PSCmdlet.ShouldProcess("Profiles/$ProfileName", 'Write profile configuration'))
    {
        $null = Set-MCDConfig -ConfigName Workspace -ProfileName $ProfileName -Data $workspaceConfig
        $null = Set-MCDConfig -ConfigName WinPE -ProfileName $ProfileName -Data $winpeConfig
    }

    [PSCustomObject]@{
        ProfileName      = $ProfileName
        WorkspaceRoot    = $workspaceRoot
        ConfigRoot       = $configRoot
        LogsRoot         = $logsRoot
        CacheRoot        = $cacheRoot
        MediaPayloadRoot = $mediaPayloadRoot
    }
}
