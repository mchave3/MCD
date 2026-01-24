function Test-MCDNetwork
{
    <#
      .SYNOPSIS
      Tests network connectivity for MCD operations.

      .DESCRIPTION
      This function checks network connectivity by performing DNS resolution and
      optionally a ping test. It is designed to work in both full Windows and
      WinPE environments with appropriate fallbacks.

      .EXAMPLE
      if (Test-MCDNetwork) { Write-Host 'Network is available' }

      Tests network connectivity using default settings.

      .EXAMPLE
      Test-MCDNetwork -HostName 'download.microsoft.com' -Verbose

      Tests connectivity to a specific host with verbose output.

      .EXAMPLE
      Test-MCDNetwork -Uri 'https://www.microsoft.com' -TimeoutSeconds 10

      Tests HTTP connectivity to a specific URI with a custom timeout.

      .PARAMETER HostName
      The hostname to use for DNS resolution test. Defaults to 'www.microsoft.com'.

      .PARAMETER Uri
      An optional URI to test HTTP/HTTPS connectivity. If specified, performs an
      additional web request test.

      .PARAMETER TimeoutSeconds
      The timeout in seconds for network tests. Defaults to 5 seconds.

      .OUTPUTS
      [bool] Returns $true if network connectivity is available, $false otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param
    (
        [Parameter()]
        [string]
        $HostName = 'www.microsoft.com',

        [Parameter()]
        [uri]
        $Uri,

        [Parameter()]
        [int]
        $TimeoutSeconds = 5
    )

    process
    {
        Write-Verbose -Message "Testing network connectivity to: $HostName"

        # Test DNS resolution
        $dnsResolved = $false

        try
        {
            # Try Resolve-DnsName first (available in Windows 8+/Server 2012+)
            $resolveDnsCmd = Get-Command -Name 'Resolve-DnsName' -ErrorAction SilentlyContinue

            if ($resolveDnsCmd)
            {
                Write-Verbose -Message 'Using Resolve-DnsName for DNS test.'
                $dnsResult = Resolve-DnsName -Name $HostName -DnsOnly -ErrorAction Stop
                if ($dnsResult)
                {
                    $dnsResolved = $true
                    Write-Verbose -Message "DNS resolution successful: $($dnsResult[0].IPAddress)"
                }
            }
            else
            {
                # Fallback to .NET DNS resolution
                Write-Verbose -Message 'Using .NET DNS resolution (fallback).'
                $dnsResult = [System.Net.Dns]::GetHostAddresses($HostName)
                if ($dnsResult.Count -gt 0)
                {
                    $dnsResolved = $true
                    Write-Verbose -Message "DNS resolution successful: $($dnsResult[0].IPAddressToString)"
                }
            }
        }
        catch
        {
            Write-Verbose -Message "DNS resolution failed: $($_.Exception.Message)"
            $dnsResolved = $false
        }

        if (-not $dnsResolved)
        {
            Write-Verbose -Message 'Network test failed: DNS resolution unsuccessful.'
            return $false
        }

        # Test ping connectivity (optional, best-effort)
        $pingSuccess = $false

        try
        {
            $testConnectionCmd = Get-Command -Name 'Test-Connection' -ErrorAction SilentlyContinue

            if ($testConnectionCmd)
            {
                Write-Verbose -Message 'Testing ping connectivity...'

                # Use different parameters based on PowerShell version
                if ($PSVersionTable.PSVersion.Major -ge 6)
                {
                    # PowerShell 6+ syntax
                    $pingResult = Test-Connection -TargetName $HostName -Count 1 -TimeoutSeconds $TimeoutSeconds -Quiet -ErrorAction SilentlyContinue
                }
                else
                {
                    # PowerShell 5.1 syntax
                    $pingResult = Test-Connection -ComputerName $HostName -Count 1 -Quiet -ErrorAction SilentlyContinue
                }

                $pingSuccess = $pingResult -eq $true
                Write-Verbose -Message "Ping test result: $pingSuccess"
            }
            else
            {
                Write-Verbose -Message 'Test-Connection not available, skipping ping test.'
                # DNS resolved, so we consider network available
                $pingSuccess = $true
            }
        }
        catch
        {
            Write-Verbose -Message "Ping test failed: $($_.Exception.Message)"
            # DNS resolved successfully, so network is likely available
            # Ping may be blocked by firewall
            $pingSuccess = $true
        }

        # Test HTTP/HTTPS if URI is specified
        if ($null -ne $Uri)
        {
            try
            {
                Write-Verbose -Message "Testing HTTP connectivity to: $Uri"

                $webRequest = [System.Net.WebRequest]::Create($Uri)
                $webRequest.Timeout = $TimeoutSeconds * 1000
                $webRequest.Method = 'HEAD'

                $response = $webRequest.GetResponse()
                $response.Close()

                Write-Verbose -Message 'HTTP connectivity test successful.'
            }
            catch
            {
                Write-Verbose -Message "HTTP connectivity test failed: $($_.Exception.Message)"
                return $false
            }
        }

        Write-Verbose -Message 'Network connectivity test passed.'
        return $true
    }
}
