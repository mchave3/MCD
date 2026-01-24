function Start-MCDWinPE
{
    <#
      .SYNOPSIS
      Starts the MCD deployment process in the WinPE environment.

      .DESCRIPTION
      This function is the main entry point for Windows deployment operations in WinPE.
      It initializes the deployment environment, checks network connectivity, loads
      configuration, and orchestrates the deployment workflow including the wizard GUI
      and image application process.

      .EXAMPLE
      Start-MCDWinPE

      Starts the WinPE deployment process with default settings and launches the GUI.

      .EXAMPLE
      Start-MCDWinPE -NoGui -Verbose

      Starts the deployment in scripted mode without the GUI, with verbose output.

      .EXAMPLE
      Start-MCDWinPE -ConfigPath 'D:\MCD\deploy-config.json' -WorkingPath 'X:\Deploy'

      Starts deployment with custom configuration and working directory.

      .PARAMETER ConfigPath
      The path to the MCD configuration file. If not specified, searches for configuration
      on USB drives or uses built-in defaults.

      .PARAMETER WorkingPath
      The working directory for deployment operations. Defaults to 'X:\MCD' which is
      the standard location in the WinPE RAM disk.

      .PARAMETER NoGui
      If specified, skips launching the graphical user interface and returns the
      deployment object. Useful for fully automated deployments.

      .OUTPUTS
      [MCDDeployment] When -NoGui is specified, returns the initialized deployment object.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    [OutputType([MCDDeployment])]
    param
    (
        [Parameter()]
        [string]
        $ConfigPath,

        [Parameter()]
        [string]
        $WorkingPath = 'X:\MCD',

        [Parameter()]
        [switch]
        $NoGui
    )

    begin
    {
        Write-Verbose -Message 'Starting MCD WinPE deployment...'
    }

    process
    {
        # Check prerequisites
        Write-Verbose -Message 'Checking prerequisites...'
        $prereqsPassed = Test-MCDPrerequisite -Mode WinPE

        if (-not $prereqsPassed)
        {
            Write-Warning -Message 'Prerequisites check returned warnings. Proceeding with caution.'
        }

        # Test network connectivity (best-effort, don't fail if unavailable)
        Write-Verbose -Message 'Testing network connectivity...'
        $networkAvailable = Test-MCDNetwork

        if ($networkAvailable)
        {
            Write-Verbose -Message 'Network connectivity confirmed.'
        }
        else
        {
            Write-Warning -Message 'Network connectivity not available. Some features may be limited.'
        }

        # Load configuration
        Write-Verbose -Message 'Loading configuration...'

        $config = $null

        if (-not [string]::IsNullOrEmpty($ConfigPath) -and (Test-Path -Path $ConfigPath))
        {
            $config = Get-MCDConfig -Path $ConfigPath
        }
        else
        {
            # Try to find configuration on USB drives
            $usbDrives = Get-Volume | Where-Object {
                $_.DriveType -eq 'Removable' -or $_.FileSystemLabel -eq 'MCDData'
            }

            foreach ($drive in $usbDrives)
            {
                $usbConfigPath = Join-Path -Path "$($drive.DriveLetter):" -ChildPath 'MCD\config.json'
                if (Test-Path -Path $usbConfigPath)
                {
                    Write-Verbose -Message "Found configuration on USB: $usbConfigPath"
                    $config = Get-MCDConfig -Path $usbConfigPath
                    break
                }
            }

            # Use default configuration if no config found
            if ($null -eq $config)
            {
                Write-Verbose -Message 'No configuration found, using defaults.'
                $config = [MCDConfig]::new()
                $config.WorkspacePath = $WorkingPath
            }
        }

        # Create and initialize deployment
        Write-Verbose -Message 'Initializing deployment session...'

        $deployment = [MCDDeployment]::new($config, $WorkingPath)

        if ($PSCmdlet.ShouldProcess($WorkingPath, 'Initialize deployment environment'))
        {
            $deployment.Initialize()

            # Log deployment start
            $deployment.StartStep('01-Initialize')
            $deployment.LogStep('01-Initialize', "Deployment session started: $($deployment.SessionId)")
            $deployment.LogStep('01-Initialize', "Working path: $WorkingPath")
            $deployment.LogStep('01-Initialize', "Network available: $networkAvailable")
            $deployment.CompleteStep('01-Initialize', $true)

            Write-Verbose -Message "Deployment initialized: $($deployment.ToString())"
        }

        # Return deployment object if NoGui is specified
        if ($NoGui)
        {
            Write-Verbose -Message 'NoGui specified, returning deployment object.'
            return $deployment
        }

        # Launch GUI (MVP: placeholder - actual WPF implementation to follow)
        Write-Verbose -Message 'GUI mode not yet implemented in MVP. Use -NoGui for scripted operations.'
        Write-Warning -Message 'GUI mode is not yet implemented. Use -NoGui parameter for scripted deployments.'

        return $deployment
    }

    end
    {
        Write-Verbose -Message 'MCD WinPE initialization complete.'
    }
}
