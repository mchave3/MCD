<#
.SYNOPSIS
Downloads and installs the Windows Assessment and Deployment Kit (ADK).

.DESCRIPTION
Retrieves the latest ADK download URL from Microsoft documentation, downloads
the installer, and runs a silent installation with the DeploymentTools feature.
Handles reboot-required exit codes (3010) gracefully as success.

.PARAMETER InstallPath
Custom installation path for ADK. Defaults to Program Files (x86)\Windows Kits\10.

.PARAMETER SkipIfInstalled
Skip installation if ADK is already detected.

.EXAMPLE
Install-MCDADK
Downloads and installs ADK with default settings.

.EXAMPLE
Install-MCDADK -InstallPath 'D:\ADK' -SkipIfInstalled
Installs ADK to custom path only if not already installed.
#>
function Install-MCDADK
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([ADKInstallerModel])]
    param
    (
        [Parameter()]
        [string]
        $InstallPath,

        [Parameter()]
        [switch]
        $SkipIfInstalled
    )

    # Check if already installed
    if ($SkipIfInstalled)
    {
        $existing = Get-MCDADKInstaller
        if ($existing.IsInstalled)
        {
            Write-MCDLog -Message '[ADKInstall] Windows ADK is already installed. Skipping installation.' -Level Info
            return $existing
        }
    }

    Write-MCDLog -Message '[ADKInstall] Starting Windows ADK installation.' -Level Info

    # Get download URL from Microsoft docs
    $adkUrl = Get-MCDADKDownloadUrl -Component 'ADK'
    if ([string]::IsNullOrWhiteSpace($adkUrl))
    {
        throw 'Failed to retrieve Windows ADK download URL from Microsoft documentation.'
    }

    Write-MCDLog -Message "[ADKInstall] ADK download URL: $adkUrl" -Level Verbose

    # Download the installer
    $installerPath = Join-Path -Path $env:TEMP -ChildPath 'adksetup.exe'

    if ($PSCmdlet.ShouldProcess('adksetup.exe', 'Download ADK installer'))
    {
        $null = Start-MCDADKDownloadWithRetry -Uri $adkUrl -DestinationPath $installerPath -Force
    }

    # Build installation arguments
    if ([string]::IsNullOrWhiteSpace($InstallPath))
    {
        $InstallPath = "${env:ProgramFiles(x86)}\Windows Kits\10"
    }

    $arguments = "/quiet /installpath `"$InstallPath`" /features OptionId.DeploymentTools"

    Write-MCDLog -Message "[ADKInstall] Installing Windows ADK to: $InstallPath" -Level Info
    Write-MCDLog -Message "[ADKInstall] Installation arguments: $arguments" -Level Verbose

    if ($PSCmdlet.ShouldProcess('Windows ADK', 'Install'))
    {
        try
        {
            $process = Start-Process -FilePath $installerPath -ArgumentList $arguments -Wait -PassThru -NoNewWindow

            # Handle exit codes
            # 0 = Success
            # 3010 = Success but reboot required
            # Other = Failure
            switch ($process.ExitCode)
            {
                0
                {
                    Write-MCDLog -Message '[ADKInstall] Windows ADK installation completed successfully.' -Level Info
                }
                3010
                {
                    Write-MCDLog -Message '[ADKInstall] Windows ADK installation completed successfully. A reboot is required.' -Level Warning
                }
                default
                {
                    throw "Windows ADK installation failed with exit code: $($process.ExitCode)"
                }
            }
        }
        finally
        {
            # Clean up installer
            if (Test-Path -Path $installerPath)
            {
                Write-MCDLog -Message '[ADKInstall] Cleaning up ADK installer.' -Level Verbose
                Remove-Item -Path $installerPath -Force -ErrorAction SilentlyContinue
            }
        }
    }

    # Return updated installation info
    return Get-MCDADKInstaller
}

<#
.SYNOPSIS
Gets the download URL for ADK or WinPE add-on from Microsoft documentation.

.DESCRIPTION
Scrapes the Microsoft ADK documentation page to find the current download URLs
for the Windows ADK or WinPE add-on. Follows the fwlink redirect to get the
actual download URL.

.PARAMETER Component
Which component URL to retrieve: 'ADK' or 'WinPE'.

.EXAMPLE
$url = Get-MCDADKDownloadUrl -Component 'ADK'
Returns the current ADK download URL.
#>
function Get-MCDADKDownloadUrl
{
    [CmdletBinding()]
    [OutputType([string])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('ADK', 'WinPE')]
        [string]
        $Component
    )

    $userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36 Edg/125.0.0.0'
    $headers = @{
        'Accept'          = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8'
        'Accept-Encoding' = 'gzip, deflate, br'
        'Accept-Language' = 'en-US,en;q=0.9'
    }

    # URL patterns for scraping
    $basePattern = '<li><a href="(https://[^"]+)" data-linktype="external">Download the '
    $urlPatterns = @{
        'ADK'   = $basePattern + 'Windows ADK'
        'WinPE' = $basePattern + 'Windows PE add-on for the Windows ADK'
    }

    $pattern = $urlPatterns[$Component]

    Write-MCDLog -Message "[ADKDownload] Retrieving $Component download URL from Microsoft documentation." -Level Verbose

    try
    {
        # Fetch the ADK documentation page
        $webPage = Invoke-RestMethod -Uri 'https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install' -Headers $headers -UserAgent $userAgent -ErrorAction Stop

        # Extract the fwlink URL
        $match = [regex]::Match($webPage, $pattern)
        if (-not $match.Success)
        {
            Write-MCDLog -Message "[ADKDownload] Failed to find $Component download link pattern on documentation page." -Level Error
            throw "Failed to retrieve $Component download URL: pattern not found on documentation page."
        }

        $fwLink = $match.Groups[1].Value
        Write-MCDLog -Message "[ADKDownload] Found fwlink: $fwLink" -Level Verbose

        # Follow the fwlink redirect to get actual download URL
        $fwLinkResponse = Invoke-WebRequest -Uri $fwLink -Method Head -MaximumRedirection 0 -ErrorAction SilentlyContinue -UseBasicParsing -UserAgent $userAgent

        if ($fwLinkResponse.StatusCode -eq 302)
        {
            $downloadUrl = $fwLinkResponse.Headers.Location
            if ($downloadUrl -is [array])
            {
                $downloadUrl = $downloadUrl[0]
            }
            Write-MCDLog -Message "[ADKDownload] Resolved download URL: $downloadUrl" -Level Verbose
            return $downloadUrl
        }
        else
        {
            Write-MCDLog -Message "[ADKDownload] Unexpected status code from fwlink: $($fwLinkResponse.StatusCode)" -Level Warning
            # Return the fwlink itself as fallback
            return $fwLink
        }
    }
    catch
    {
        Write-MCDLog -Message "[ADKDownload] Error retrieving $Component download URL: $($_.Exception.Message)" -Level Error
        throw "Failed to retrieve $Component download URL: $($_.Exception.Message)"
    }
}
