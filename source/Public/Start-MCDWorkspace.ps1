function Start-MCDWorkspace
{
    <#
      .SYNOPSIS
      Starts the MCD Workspace environment for creating and managing deployment media.

      .DESCRIPTION
      This function initializes the MCD Workspace environment on a full Windows system.
      It validates prerequisites, loads or creates configuration, initializes the workspace
      directory structure, and optionally launches the graphical user interface for
      managing WinPE deployment media.

      .EXAMPLE
      Start-MCDWorkspace

      Starts the workspace with default settings and launches the GUI.

      .EXAMPLE
      Start-MCDWorkspace -Name 'ProductionDeploy' -NoGui

      Initializes a named workspace without launching the GUI, returning the workspace object.

      .EXAMPLE
      Start-MCDWorkspace -ConfigPath 'D:\MCD\custom-config.json' -Verbose

      Starts the workspace using a custom configuration file with verbose output.

      .PARAMETER Name
      The name of the workspace to initialize or use. Defaults to 'Default'.
      Each workspace has its own directory structure and configuration.

      .PARAMETER ConfigPath
      The path to the MCD configuration file. If not specified, uses the default
      location at $env:ProgramData\MCD\config.json.

      .PARAMETER NoGui
      If specified, skips launching the graphical user interface and returns the
      initialized workspace object. Useful for scripted operations and testing.

      .OUTPUTS
      [MCDWorkspace] When -NoGui is specified, returns the initialized workspace object.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    [OutputType([MCDWorkspace])]
    param
    (
        [Parameter()]
        [string]
        $Name = 'Default',

        [Parameter()]
        [string]
        $ConfigPath,

        [Parameter()]
        [switch]
        $NoGui
    )

    begin
    {
        Write-Verbose -Message 'Starting MCD Workspace...'
    }

    process
    {
        # Check prerequisites
        Write-Verbose -Message 'Checking prerequisites...'
        $prereqsPassed = Test-MCDPrerequisite -Mode Workspace

        if (-not $prereqsPassed)
        {
            throw 'Prerequisites check failed. Please resolve the issues and try again.'
        }

        # Load or create configuration
        Write-Verbose -Message 'Loading configuration...'

        $configParams = @{
            CreateIfMissing = $true
        }

        if (-not [string]::IsNullOrEmpty($ConfigPath))
        {
            $configParams['Path'] = $ConfigPath
        }

        $config = Get-MCDConfig @configParams

        # Create and initialize workspace
        Write-Verbose -Message "Initializing workspace: $Name"

        $workspace = [MCDWorkspace]::new($Name, $config)

        if ($PSCmdlet.ShouldProcess($workspace.Path, 'Initialize workspace'))
        {
            $workspace.Initialize()

            # Validate workspace
            if (-not $workspace.Validate())
            {
                throw "Workspace validation failed for: $($workspace.Path)"
            }

            Write-Verbose -Message "Workspace initialized successfully: $($workspace.ToString())"
        }

        # Return workspace object if NoGui is specified
        if ($NoGui)
        {
            Write-Verbose -Message 'NoGui specified, returning workspace object.'
            return $workspace
        }

        # Launch GUI (MVP: placeholder - actual WPF implementation to follow)
        Write-Verbose -Message 'GUI mode not yet implemented in MVP. Use -NoGui for scripted operations.'
        Write-Warning -Message 'GUI mode is not yet implemented. Use -NoGui parameter for scripted operations.'

        return $workspace
    }

    end
    {
        Write-Verbose -Message 'MCD Workspace initialization complete.'
    }
}
