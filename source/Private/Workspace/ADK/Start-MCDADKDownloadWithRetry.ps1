<#
.SYNOPSIS
Downloads a file with retry logic using BITS transfer or Invoke-WebRequest.

.DESCRIPTION
Downloads a file from a URL with configurable retry attempts and delay between
retries. Uses BITS transfer as primary method with fallback to Invoke-WebRequest.
Sets a Microsoft-compatible User-Agent header to avoid download failures.

.PARAMETER Uri
The URL to download from.

.PARAMETER DestinationPath
The full path where the file should be saved.

.PARAMETER MaxRetries
Maximum number of retry attempts. Default is 3.

.PARAMETER RetryDelaySeconds
Seconds to wait between retry attempts. Default is 5.

.PARAMETER Force
Overwrite existing file if present.

.EXAMPLE
Start-MCDADKDownloadWithRetry -Uri 'https://example.com/file.exe' -DestinationPath 'C:\Temp\file.exe'
Downloads file with default retry settings.

.EXAMPLE
Start-MCDADKDownloadWithRetry -Uri 'https://example.com/file.exe' -DestinationPath 'C:\Temp\file.exe' -MaxRetries 5 -RetryDelaySeconds 10
Downloads file with custom retry settings.
#>
function Start-MCDADKDownloadWithRetry
{
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Uri,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $DestinationPath,

        [Parameter()]
        [ValidateRange(1, 10)]
        [int]
        $MaxRetries = 3,

        [Parameter()]
        [ValidateRange(1, 60)]
        [int]
        $RetryDelaySeconds = 5,

        [Parameter()]
        [switch]
        $Force
    )

    # Microsoft-compatible User-Agent to avoid download failures
    $userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36 Edg/125.0.0.0'

    # Check if file exists and Force not specified
    if ((Test-Path -Path $DestinationPath) -and (-not $Force))
    {
        Write-MCDLog -Message "[ADKDownload] File already exists: $DestinationPath. Use -Force to overwrite." -Level Info
        return Get-Item -Path $DestinationPath
    }

    # Ensure destination directory exists
    $destinationDir = Split-Path -Path $DestinationPath -Parent
    if (-not (Test-Path -Path $destinationDir))
    {
        Write-MCDLog -Message "[ADKDownload] Creating destination directory: $destinationDir" -Level Verbose
        $null = New-Item -Path $destinationDir -ItemType Directory -Force
    }

    # Enable TLS 1.2
    try
    {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    }
    catch
    {
        Write-MCDLog -Message '[ADKDownload] Unable to enable TLS 1.2; continuing with existing SecurityProtocol.' -Level Verbose
    }

    $attempt = 0
    $lastError = $null

    while ($attempt -lt $MaxRetries)
    {
        $attempt++
        Write-MCDLog -Message "[ADKDownload] Download attempt $attempt of $MaxRetries for: $Uri" -Level Info

        try
        {
            # Try BITS transfer first (supports resume and is more reliable for large files)
            $useBits = $true
            try
            {
                # Check if BITS is available
                $null = Get-Command -Name Start-BitsTransfer -ErrorAction Stop
            }
            catch
            {
                $useBits = $false
            }

            if ($useBits)
            {
                Write-MCDLog -Message '[ADKDownload] Using BITS transfer.' -Level Verbose
                $originalProgressPreference = $ProgressPreference
                $ProgressPreference = 'SilentlyContinue'
                Start-BitsTransfer -Source $Uri -Destination $DestinationPath -ErrorAction Stop
                $ProgressPreference = $originalProgressPreference
            }
            else
            {
                Write-MCDLog -Message '[ADKDownload] BITS not available, using Invoke-WebRequest.' -Level Verbose
                $headers = @{
                    'Accept'          = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8'
                    'Accept-Encoding' = 'gzip, deflate, br'
                    'Accept-Language' = 'en-US,en;q=0.9'
                }
                Invoke-WebRequest -Uri $Uri -OutFile $DestinationPath -UseBasicParsing -UserAgent $userAgent -Headers $headers -ErrorAction Stop | Out-Null
            }

            # Verify file was downloaded
            if (Test-Path -Path $DestinationPath)
            {
                $fileInfo = Get-Item -Path $DestinationPath
                Write-MCDLog -Message "[ADKDownload] Download completed successfully: $DestinationPath ($($fileInfo.Length) bytes)" -Level Info
                return $fileInfo
            }
            else
            {
                throw "Download appeared to succeed but file not found at: $DestinationPath"
            }
        }
        catch
        {
            $lastError = $_
            Write-MCDLog -Message "[ADKDownload] Download attempt $attempt failed: $($_.Exception.Message)" -Level Warning

            # Remove partial file if exists
            if (Test-Path -Path $DestinationPath)
            {
                Remove-Item -Path $DestinationPath -Force -ErrorAction SilentlyContinue
            }

            if ($attempt -lt $MaxRetries)
            {
                Write-MCDLog -Message "[ADKDownload] Waiting $RetryDelaySeconds seconds before retry..." -Level Verbose
                Start-Sleep -Seconds $RetryDelaySeconds
            }
        }
    }

    # All retries exhausted
    $errorMessage = "Failed to download $Uri after $MaxRetries attempts. Last error: $($lastError.Exception.Message)"
    Write-MCDLog -Message $errorMessage -Level Error
    throw $errorMessage
}
