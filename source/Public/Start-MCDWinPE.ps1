function Start-MCDWinPE
{
    <#
    .SYNOPSIS
    Starts the MCD WinPE deployment experience.

    .DESCRIPTION
    Runs the initial WinPE flow: validates WinPE context, checks connectivity,
    optionally updates the MCD module from PowerShell Gallery, and then loads
    and shows the WinPE main window XAML.

    .PARAMETER ProfileName
    Workspace profile name to load WinPE configuration from under ProgramData.

    .PARAMETER SkipModuleUpdate
    Skips the PowerShell Gallery update check for the MCD module in WinPE.

    .PARAMETER NoUI
    Prevents opening the WinPE UI. Intended for automated testing scenarios.

    .EXAMPLE
    Start-MCDWinPE -ProfileName Default

    Starts the WinPE flow using the Default workspace profile configuration.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $ProfileName = 'Default',

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $SkipModuleUpdate,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $NoUI
    )

    $null = Test-MCDPrerequisite -RequireWinPE

    $context = Get-MCDExecutionContext

    Write-MCDLog -Level Info -Message "Starting WinPE session (ProfileName='$ProfileName')."

    $winpeConfig = Get-MCDConfig -ConfigName WinPE -ProfileName $ProfileName
    if (-not $winpeConfig)
    {
        Write-MCDLog -Level Warning -Message "WinPE config not found for profile '$ProfileName'. Using built-in defaults."
        $winpeConfig = [PSCustomObject]@{}
    }

    $workspaceConfig = Get-MCDConfig -ConfigName Workspace -ProfileName $ProfileName
    if (-not $workspaceConfig)
    {
        Write-MCDLog -Level Warning -Message "Workspace config not found for profile '$ProfileName'. Using built-in defaults."
        $workspaceConfig = [PSCustomObject]@{ ProfileName = $ProfileName }
    }

    $net = Start-MCDConnectivityFlow -WinPEConfig $winpeConfig -XamlRoot $context.XamlRoot -NoUI:$NoUI
    if (-not $net.HasDhcp)
    {
        Write-MCDLog -Level Warning -Message 'Network DHCP lease was not obtained within the expected timeframe.'
    }

    if ((-not $SkipModuleUpdate) -and $net.HasInternet)
    {
        if ($PSCmdlet.ShouldProcess('MCD', 'Check for module updates from PowerShell Gallery'))
        {
            $null = Update-MCDFromPSGallery
        }
    }

    if ($NoUI)
    {
        Write-MCDLog -Level Verbose -Message 'NoUI specified; skipping WinPE UI startup.'
        return
    }

    $selection = Start-MCDWizard -WorkspaceConfig $workspaceConfig -WinPEConfig $winpeConfig -XamlRoot $context.XamlRoot

    # Attach config context for background deployment runner.
    $selection | Add-Member -NotePropertyName ProfileName -NotePropertyValue $ProfileName -Force
    $selection | Add-Member -NotePropertyName WinPEConfig -NotePropertyValue $winpeConfig -Force

    $osId = $null
    $osName = $null
    if ($selection.OperatingSystem)
    {
        $osId = $selection.OperatingSystem.Id
        $osName = $selection.OperatingSystem.DisplayName
    }
    $diskNumber = $null
    if ($selection.TargetDisk)
    {
        $diskNumber = $selection.TargetDisk.DiskNumber
    }
    Write-MCDLog -Level Info -Message ("Wizard selection: Language='{0}', OS='{1}' ({2}), DriverPack='{3}', Disk='{4}'" -f $selection.ComputerLanguage, $osName, $osId, $selection.DriverPack, $diskNumber)

    $relativeXaml = 'WinPE\\ProgressWindow.xaml'
    if ($winpeConfig.XamlMainWindowRelativePath)
    {
        $relativeXaml = [string]$winpeConfig.XamlMainWindowRelativePath
    }

    if ($PSCmdlet.ShouldProcess($relativeXaml, 'Start WinPE UI'))
    {
        $xamlPath = Join-Path -Path $context.XamlRoot -ChildPath $relativeXaml
        $window = Import-MCDWinPEXaml -XamlPath $xamlPath

        $deploymentStarted = $false
        $window.Add_ContentRendered({
                if ($deploymentStarted)
                {
                    return
                }
                $deploymentStarted = $true
                Start-MCDWinPEDeploymentAsync -Window $window -Selection $selection
            })

        Start-MCDWinPEMainWindow -Window $window
    }
}
