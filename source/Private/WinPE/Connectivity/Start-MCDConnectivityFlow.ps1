function Start-MCDConnectivityFlow
{
    <#
    .SYNOPSIS
    Runs the WinPE connectivity flow and optionally prompts for Wi-Fi.

    .DESCRIPTION
    Tests DHCP and basic Internet connectivity. If Internet is unavailable, a
    connectivity window can be displayed to allow the user to retry or open a
    Wi-Fi connection UI (WirelessConnect.exe when available), then re-test.

    .PARAMETER WinPEConfig
    WinPE configuration object (typically loaded from Get-MCDConfig).

    .PARAMETER XamlRoot
    Root directory containing the WinPE XAML files.

    .PARAMETER NoUI
    Disables the connectivity window and only performs non-interactive tests.

    .EXAMPLE
    Start-MCDConnectivityFlow -WinPEConfig $winpeConfig -XamlRoot $context.XamlRoot

    Checks connectivity and optionally prompts for Wi-Fi.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([pscustomobject])]
    param
    (
        [Parameter()]
        [ValidateNotNull()]
        [pscustomobject]
        $WinPEConfig,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $XamlRoot,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $NoUI
    )

    $dhcpWait = 20
    if ($WinPEConfig.DhcpWaitSeconds)
    {
        $dhcpWait = [int]$WinPEConfig.DhcpWaitSeconds
    }

    $testHost = 'google.com'
    if ($WinPEConfig.NetworkTestHostName)
    {
        $testHost = [string]$WinPEConfig.NetworkTestHostName
    }

    $net = Test-MCDNetwork -WaitForDhcpSeconds $dhcpWait -TestHostName $testHost
    if ($net.HasInternet -or $NoUI)
    {
        return $net
    }

    if ($WinPEConfig.AutoConnectWifiProfile -and $WinPEConfig.WifiProfileRelativePaths)
    {
        $wifiProfilePath = Find-MCDWifiProfile -RelativePaths @($WinPEConfig.WifiProfileRelativePaths)
        if ($wifiProfilePath)
        {
            try
            {
                $connected = Connect-MCDWifiProfile -WifiProfilePath $wifiProfilePath -Confirm:$false
                if ($connected)
                {
                    $net = Test-MCDNetwork -WaitForDhcpSeconds $dhcpWait -TestHostName $testHost
                    if ($net.HasInternet)
                    {
                        return $net
                    }
                }
            }
            catch
            {
                Write-MCDLog -Level Warning -Message "Auto-connect Wi-Fi profile failed: $($_.Exception.Message)"
            }
        }
    }

    $relativeXaml = 'WinPE\\ConnectivityWindow.xaml'
    if ($WinPEConfig.XamlConnectivityWindowRelativePath)
    {
        $relativeXaml = [string]$WinPEConfig.XamlConnectivityWindowRelativePath
    }

    $xamlPath = Join-Path -Path $XamlRoot -ChildPath $relativeXaml
    $window = Import-MCDWinPEXaml -XamlPath $xamlPath

    $statusText = $window.FindName('StatusText')
    $wifiButton = $window.FindName('WifiButton')
    $retryButton = $window.FindName('RetryButton')
    $continueButton = $window.FindName('ContinueButton')
    $cancelButton = $window.FindName('CancelButton')

    if ($statusText)
    {
        $statusText.Text = "DHCP: $($net.HasDhcp); IP: $($net.IpAddress); Internet: $($net.HasInternet)"
    }

    $getWirelessConnectPath = {
        $candidate = Join-Path -Path $env:SystemRoot -ChildPath 'WirelessConnect.exe'
        if (Test-Path -Path $candidate)
        {
            return $candidate
        }
        return $null
    }

    if ($wifiButton)
    {
        $wifiButton.Add_Click({
                $wirelessConnect = & $getWirelessConnectPath
                if (-not $wirelessConnect)
                {
                    if ($statusText)
                    {
                        $statusText.Text = 'WirelessConnect.exe was not found in this WinPE image.'
                    }
                    return
                }

                if ($PSCmdlet.ShouldProcess($wirelessConnect, 'Launch Wi-Fi connection UI'))
                {
                    Start-Process -FilePath $wirelessConnect -Wait
                }
            })
    }

    $refresh = {
        $netRefreshed = Test-MCDNetwork -WaitForDhcpSeconds $dhcpWait -TestHostName $testHost
        $net = $netRefreshed
        if ($statusText)
        {
            $statusText.Text = "DHCP: $($net.HasDhcp); IP: $($net.IpAddress); Internet: $($net.HasInternet)"
        }
        if ($net.HasInternet)
        {
            $window.DialogResult = $true
            $window.Close()
        }
    }

    if ($retryButton)
    {
        $retryButton.Add_Click({ & $refresh })
    }

    if ($continueButton)
    {
        $continueButton.Add_Click({
                $window.DialogResult = $true
                $window.Close()
            })
    }

    if ($cancelButton)
    {
        $cancelButton.Add_Click({
                $window.DialogResult = $false
                $window.Close()
            })
    }

    if ($PSCmdlet.ShouldProcess($relativeXaml, 'Show connectivity window'))
    {
        $null = $window.ShowDialog()
    }

    Test-MCDNetwork -WaitForDhcpSeconds $dhcpWait -TestHostName $testHost
}
