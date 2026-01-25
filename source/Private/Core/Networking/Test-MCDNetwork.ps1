function Test-MCDNetwork
{
    <#
    .SYNOPSIS
    Tests WinPE network readiness (DHCP and basic connectivity).

    .DESCRIPTION
    Waits for an IPv4 address that is not APIPA/loopback and optionally checks
    basic Internet reachability using ICMP to a configurable host name.

    .PARAMETER WaitForDhcpSeconds
    Maximum number of seconds to wait for a DHCP-assigned IPv4 address.

    .PARAMETER TestHostName
    Host name to test for basic Internet connectivity using Test-Connection.

    .EXAMPLE
    Test-MCDNetwork -WaitForDhcpSeconds 20 -TestHostName 'google.com'

    Waits for DHCP and then tests Internet connectivity using ICMP.
    #>
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateRange(0, 300)]
        [int]
        $WaitForDhcpSeconds = 20,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $TestHostName = 'google.com'
    )

    $timeout = 0
    $ipAddress = $null

    while ($timeout -lt $WaitForDhcpSeconds)
    {
        $ip = Test-Connection -ComputerName (hostname) -Count 1 -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty IPV4Address -ErrorAction SilentlyContinue

        if ($null -eq $ip)
        {
            Write-MCDLog -Level Verbose -Message 'Network adapter did not return an IPv4 address yet.'
        }
        elseif ($ip.IPAddressToString.StartsWith('169.254') -or $ip.IPAddressToString.Equals('127.0.0.1'))
        {
            Write-MCDLog -Level Verbose -Message 'IP not assigned by DHCP yet; attempting DHCP renew.'
            try
            {
                ipconfig /release | Out-Null
                ipconfig /renew | Out-Null
            }
            catch
            {
                Write-MCDLog -Level Verbose -Message "DHCP renew attempt failed: $($_.Exception.Message)"
            }
        }
        else
        {
            $ipAddress = $ip.IPAddressToString
            break
        }

        Start-Sleep -Seconds 5
        $timeout += 5
    }

    $hasDhcp = [bool]$ipAddress
    $hasInternet = $false
    if ($hasDhcp)
    {
        $hasInternet = [bool](Test-Connection -ComputerName $TestHostName -Count 1 -Quiet -ErrorAction SilentlyContinue)
    }

    [PSCustomObject]@{
        HasDhcp     = $hasDhcp
        IpAddress   = $ipAddress
        HasInternet = $hasInternet
    }
}
