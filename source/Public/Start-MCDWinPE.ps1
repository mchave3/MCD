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

    $dhcpWait = 20
    if ($winpeConfig.DhcpWaitSeconds)
    {
        $dhcpWait = [int]$winpeConfig.DhcpWaitSeconds
    }

    $testHost = 'google.com'
    if ($winpeConfig.NetworkTestHostName)
    {
        $testHost = [string]$winpeConfig.NetworkTestHostName
    }

    $net = Test-MCDNetwork -WaitForDhcpSeconds $dhcpWait -TestHostName $testHost
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

    $relativeXaml = 'WinPE\\MainWindow.xaml'
    if ($winpeConfig.XamlMainWindowRelativePath)
    {
        $relativeXaml = [string]$winpeConfig.XamlMainWindowRelativePath
    }

    if ($PSCmdlet.ShouldProcess($relativeXaml, 'Start WinPE UI'))
    {
        $xamlPath = Join-Path -Path $context.XamlRoot -ChildPath $relativeXaml
        $window = Import-MCDWinPEXaml -XamlPath $xamlPath
        Start-MCDWinPEMainWindow -Window $window
    }
}
