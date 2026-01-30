<#
.SYNOPSIS
Downloads and installs the Windows PE add-on for ADK.

.DESCRIPTION
Retrieves the latest WinPE add-on download URL from Microsoft documentation,
downloads the installer, and runs a silent installation with the
WindowsPreinstallationEnvironment feature. Handles reboot-required exit codes
(3010) gracefully as success.

.PARAMETER InstallPath
Custom installation path for WinPE. Should match the ADK installation path.
Defaults to Program Files (x86)\Windows Kits\10.

.PARAMETER SkipIfInstalled
Skip installation if WinPE add-on is already detected.

.EXAMPLE
Install-MCDWinPEComponents
Downloads and installs WinPE add-on with default settings.

.EXAMPLE
Install-MCDWinPEComponents -SkipIfInstalled
Installs WinPE add-on only if not already installed.
#>
function Install-MCDWinPEComponents
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
        $existing = Get-MCDADKInstaller -IncludeWinPE
        if ($existing.HasWinPEAddOn)
        {
            Write-MCDLog -Message '[WinPEInstall] Windows PE add-on is already installed. Skipping installation.' -Level Info
            return $existing
        }
    }

    # Check if ADK is installed first
    $adkInfo = Get-MCDADKInstaller
    if (-not $adkInfo.IsInstalled)
    {
        throw 'Windows ADK must be installed before installing the Windows PE add-on. Run Install-MCDADK first.'
    }

    Write-MCDLog -Message '[WinPEInstall] Starting Windows PE add-on installation.' -Level Info

    # Get download URL from Microsoft docs
    $winPEUrl = Get-MCDADKDownloadUrl -Component 'WinPE'
    if ([string]::IsNullOrWhiteSpace($winPEUrl))
    {
        throw 'Failed to retrieve Windows PE add-on download URL from Microsoft documentation.'
    }

    Write-MCDLog -Message "[WinPEInstall] WinPE add-on download URL: $winPEUrl" -Level Verbose

    # Download the installer
    $installerPath = Join-Path -Path $env:TEMP -ChildPath 'adkwinpesetup.exe'

    if ($PSCmdlet.ShouldProcess('adkwinpesetup.exe', 'Download WinPE add-on installer'))
    {
        $null = Start-MCDADKDownloadWithRetry -Uri $winPEUrl -DestinationPath $installerPath -Force
    }

    # Build installation arguments
    if ([string]::IsNullOrWhiteSpace($InstallPath))
    {
        $InstallPath = "${env:ProgramFiles(x86)}\Windows Kits\10"
    }

    $arguments = "/quiet /installpath `"$InstallPath`" /features OptionId.WindowsPreinstallationEnvironment"

    Write-MCDLog -Message "[WinPEInstall] Installing Windows PE add-on to: $InstallPath" -Level Info
    Write-MCDLog -Message "[WinPEInstall] Installation arguments: $arguments" -Level Verbose

    if ($PSCmdlet.ShouldProcess('Windows PE add-on', 'Install'))
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
                    Write-MCDLog -Message '[WinPEInstall] Windows PE add-on installation completed successfully.' -Level Info
                }
                3010
                {
                    Write-MCDLog -Message '[WinPEInstall] Windows PE add-on installation completed successfully. A reboot is required.' -Level Warning
                }
                default
                {
                    throw "Windows PE add-on installation failed with exit code: $($process.ExitCode)"
                }
            }
        }
        finally
        {
            # Clean up installer
            if (Test-Path -Path $installerPath)
            {
                Write-MCDLog -Message '[WinPEInstall] Cleaning up WinPE add-on installer.' -Level Verbose
                Remove-Item -Path $installerPath -Force -ErrorAction SilentlyContinue
            }
        }
    }

    # Return updated installation info
    return Get-MCDADKInstaller -IncludeWinPE
}
