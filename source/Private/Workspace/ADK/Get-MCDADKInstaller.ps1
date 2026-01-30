<#
.SYNOPSIS
Detects installed Windows ADK and WinPE add-on using registry.

.DESCRIPTION
Queries the Windows registry to detect whether the Windows Assessment and
Deployment Kit (ADK) and the Windows PE add-on are installed. Returns an
ADKInstallerModel object with installation details including version, paths,
and component availability.

.PARAMETER IncludeWinPE
When specified, also checks for the WinPE add-on installation status.

.EXAMPLE
$adk = Get-MCDADKInstaller
Returns ADK installation status without WinPE add-on check.

.EXAMPLE
$adk = Get-MCDADKInstaller -IncludeWinPE
Returns ADK installation status including WinPE add-on detection.
#>
function Get-MCDADKInstaller
{
    [CmdletBinding()]
    [OutputType([ADKInstallerModel])]
    param
    (
        [Parameter()]
        [switch]
        $IncludeWinPE
    )

    $model = [ADKInstallerModel]::new()

    # Registry paths for Windows Kits detection
    $installedRootsPath = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Kits\Installed Roots'
    $uninstallPath = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'

    # Display names as they appear in registry
    $adkDisplayName = 'Windows Assessment and Deployment Kit'
    $winPEDisplayName = 'Windows Assessment and Deployment Kit Windows Preinstallation Environment Add-ons'

    Write-MCDLog -Message '[ADK] Detecting Windows ADK installation status.' -Level Verbose

    # Check for KitsRoot10 to get installation path
    $kitsRoot = $null
    if (Test-Path -Path $installedRootsPath)
    {
        $registryKey = Get-Item -Path $installedRootsPath -ErrorAction SilentlyContinue
        if ($null -ne $registryKey)
        {
            $kitsRoot = Get-ItemPropertyValue -Path $installedRootsPath -Name 'KitsRoot10' -ErrorAction SilentlyContinue
        }
    }

    if ([string]::IsNullOrWhiteSpace($kitsRoot))
    {
        Write-MCDLog -Message '[ADK] Windows ADK not detected (KitsRoot10 not found).' -Level Verbose
        return $model
    }

    $adkPath = Join-Path -Path $kitsRoot -ChildPath 'Assessment and Deployment Kit'
    if (-not (Test-Path -Path $adkPath))
    {
        Write-MCDLog -Message "[ADK] ADK path does not exist: $adkPath" -Level Verbose
        return $model
    }

    $model.InstallPath = $adkPath
    $model.IsInstalled = $true

    # Get version from uninstall registry
    if (Test-Path -Path $uninstallPath)
    {
        $uninstallKeys = Get-ChildItem -Path $uninstallPath -ErrorAction SilentlyContinue
        foreach ($key in $uninstallKeys)
        {
            try
            {
                $displayName = $key.GetValue('DisplayName')
                if ($displayName -eq $adkDisplayName)
                {
                    $model.Version = $key.GetValue('DisplayVersion')
                    Write-MCDLog -Message "[ADK] Found ADK version: $($model.Version)" -Level Verbose
                    break
                }
            }
            catch
            {
                # Ignore errors reading registry keys - registry access may fail on certain keys
                Write-Debug -Message "Error reading registry key: $($_.Exception.Message)"
            }
        }
    }

    # Set DISM and Oscdimg paths based on architecture
    $arch = $env:PROCESSOR_ARCHITECTURE
    if ($arch -eq 'AMD64')
    {
        $arch = 'amd64'
    }
    elseif ($arch -eq 'ARM64')
    {
        $arch = 'arm64'
    }
    else
    {
        $arch = 'x86'
    }

    $deploymentToolsPath = Join-Path -Path $adkPath -ChildPath "Deployment Tools\$arch"
    $dismPath = Join-Path -Path $deploymentToolsPath -ChildPath 'DISM\dism.exe'
    $oscdimgPath = Join-Path -Path $deploymentToolsPath -ChildPath 'Oscdimg\oscdimg.exe'

    if (Test-Path -Path $dismPath)
    {
        $model.DismPath = $dismPath
    }

    if (Test-Path -Path $oscdimgPath)
    {
        $model.OscdimgPath = $oscdimgPath
    }

    Write-MCDLog -Message "[ADK] ADK detected at: $adkPath (Version: $($model.Version))" -Level Info

    # Check for WinPE add-on if requested
    if ($IncludeWinPE)
    {
        $winPEPath = Join-Path -Path $adkPath -ChildPath 'Windows Preinstallation Environment'
        if (Test-Path -Path $winPEPath)
        {
            $model.WinPEAddOnPath = $winPEPath
            $model.HasWinPEAddOn = $true
            Write-MCDLog -Message "[ADK] WinPE add-on detected at: $winPEPath" -Level Info
        }
        else
        {
            # Also check registry for explicit WinPE installation
            if (Test-Path -Path $uninstallPath)
            {
                $uninstallKeys = Get-ChildItem -Path $uninstallPath -ErrorAction SilentlyContinue
                foreach ($key in $uninstallKeys)
                {
                    try
                    {
                        $displayName = $key.GetValue('DisplayName')
                        if ($displayName -eq $winPEDisplayName)
                        {
                            $model.WinPEAddOnPath = $winPEPath
                            $model.HasWinPEAddOn = $true
                            Write-MCDLog -Message '[ADK] WinPE add-on detected via registry.' -Level Info
                            break
                        }
                    }
                    catch
                    {
                        # Ignore errors reading registry keys - registry access may fail on certain keys
                        Write-Debug -Message "Error reading registry key: $($_.Exception.Message)"
                    }
                }
            }

            if (-not $model.HasWinPEAddOn)
            {
                Write-MCDLog -Message '[ADK] WinPE add-on not detected.' -Level Verbose
            }
        }
    }

    return $model
}
