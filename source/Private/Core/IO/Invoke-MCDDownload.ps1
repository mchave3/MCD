function Invoke-MCDDownload
{
    <#
    .SYNOPSIS
    Downloads a file to disk using Invoke-WebRequest.

    .DESCRIPTION
    Downloads a file from a given URI to a destination path. The destination
    directory is created if it does not exist. When the destination file already
    exists, the function returns the existing file unless -Force is specified.

    .PARAMETER Uri
    The HTTP/HTTPS URI of the file to download.

    .PARAMETER DestinationPath
    Full path where the downloaded file will be written.

    .PARAMETER Force
    Overwrites the destination file when it already exists.

    .EXAMPLE
    Invoke-MCDDownload -Uri 'https://example.com/file.zip' -DestinationPath 'X:\\Temp\\file.zip' -Force

    Downloads file.zip to X:\Temp and overwrites any existing file.
    #>
    [CmdletBinding()]
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
        [switch]
        $Force
    )

    if ((Test-Path -Path $DestinationPath) -and (-not $Force))
    {
        return Get-Item -Path $DestinationPath
    }

    $destinationDirectory = Split-Path -Path $DestinationPath -Parent
    if (-not (Test-Path -Path $destinationDirectory))
    {
        $null = New-Item -Path $destinationDirectory -ItemType Directory -Force
    }

    try
    {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    }
    catch
    {
        Write-Verbose -Message 'Unable to enable TLS 1.2; continuing with existing SecurityProtocol.'
    }

    Invoke-WebRequest -Uri $Uri -OutFile $DestinationPath -UseBasicParsing -ErrorAction Stop | Out-Null
    Get-Item -Path $DestinationPath
}
