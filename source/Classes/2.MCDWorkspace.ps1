<#
    .SYNOPSIS
    MCD Workspace class for managing workspace state in full Windows environment.

    .DESCRIPTION
    The MCDWorkspace class represents a workspace configuration for building and managing
    WinPE deployment media. It provides methods to initialize workspace directory structures
    and validate the workspace configuration.
#>
class MCDWorkspace
{
    # Workspace name (e.g., 'Default', 'SiteMarseille')
    [string] $Name

    # Full path to the workspace directory
    [string] $Path

    # Path to the WinPE template directory
    [string] $TemplatePath

    # Path to the media output directory
    [string] $MediaPath

    # Associated configuration object
    [MCDConfig] $Config

    # Default constructor
    MCDWorkspace()
    {
        $this.Name = 'Default'
    }

    # Constructor with name and config
    MCDWorkspace([string] $Name, [MCDConfig] $Config)
    {
        $this.Name = $Name
        $this.Config = $Config
        $this.InitializePaths()
    }

    <#
        .SYNOPSIS
        Initializes the path properties based on configuration.

        .DESCRIPTION
        Sets up the Path, TemplatePath, and MediaPath properties based on the
        workspace name and configuration settings.
    #>
    hidden [void] InitializePaths()
    {
        if ($null -ne $this.Config)
        {
            $workspacesRoot = Join-Path -Path $this.Config.WorkspacePath -ChildPath 'Workspaces'
            $this.Path = Join-Path -Path $workspacesRoot -ChildPath $this.Name
            $this.TemplatePath = Join-Path -Path $this.Path -ChildPath 'Template'
            $this.MediaPath = Join-Path -Path $this.Path -ChildPath 'Media'
        }
    }

    <#
        .SYNOPSIS
        Initializes the workspace directory structure.

        .DESCRIPTION
        Creates the workspace directory and all required subdirectories including
        Template, Media, Logs, Cache, Drivers, Autopilot, PPKG, and Scripts folders.
    #>
    [void] Initialize()
    {
        # Ensure paths are set
        if ([string]::IsNullOrEmpty($this.Path))
        {
            $this.InitializePaths()
        }

        if ([string]::IsNullOrEmpty($this.Path))
        {
            throw 'Cannot initialize workspace: Path is not configured. Ensure Config is set.'
        }

        # Create main workspace directory
        if (-not (Test-Path -Path $this.Path))
        {
            New-Item -Path $this.Path -ItemType Directory -Force | Out-Null
        }

        # Create required subdirectories
        $subdirectories = @(
            'Template'
            'Media'
            'Logs'
            'Cache'
            'Drivers'
            'Autopilot'
            'PPKG'
            'Scripts'
        )

        foreach ($subdir in $subdirectories)
        {
            $subdirPath = Join-Path -Path $this.Path -ChildPath $subdir
            if (-not (Test-Path -Path $subdirPath))
            {
                New-Item -Path $subdirPath -ItemType Directory -Force | Out-Null
            }
        }

        # Update paths after initialization
        $this.TemplatePath = Join-Path -Path $this.Path -ChildPath 'Template'
        $this.MediaPath = Join-Path -Path $this.Path -ChildPath 'Media'
    }

    <#
        .SYNOPSIS
        Validates the workspace configuration and directory structure.

        .DESCRIPTION
        Checks that all required paths exist and the workspace is properly configured.
        Returns $true if the workspace is valid, $false otherwise.

        .OUTPUTS
        [bool] True if the workspace is valid and ready for use.
    #>
    [bool] Validate()
    {
        # Check if configuration is set
        if ($null -eq $this.Config)
        {
            return $false
        }

        # Check if path is set
        if ([string]::IsNullOrEmpty($this.Path))
        {
            return $false
        }

        # Check if main workspace directory exists
        if (-not (Test-Path -Path $this.Path -PathType Container))
        {
            return $false
        }

        # Check required subdirectories
        $requiredDirs = @('Template', 'Media', 'Logs')
        foreach ($dir in $requiredDirs)
        {
            $dirPath = Join-Path -Path $this.Path -ChildPath $dir
            if (-not (Test-Path -Path $dirPath -PathType Container))
            {
                return $false
            }
        }

        return $true
    }

    <#
        .SYNOPSIS
        Gets the path to the workspace configuration file.

        .OUTPUTS
        [string] The path to workspace.json.
    #>
    [string] GetConfigPath()
    {
        if ([string]::IsNullOrEmpty($this.Path))
        {
            return $null
        }
        return Join-Path -Path $this.Path -ChildPath 'workspace.json'
    }

    <#
        .SYNOPSIS
        Gets the path to the workspace logs directory.

        .OUTPUTS
        [string] The path to the Logs directory.
    #>
    [string] GetLogsPath()
    {
        if ([string]::IsNullOrEmpty($this.Path))
        {
            return $null
        }
        return Join-Path -Path $this.Path -ChildPath 'Logs'
    }

    <#
        .SYNOPSIS
        Gets the path to the workspace cache directory.

        .OUTPUTS
        [string] The path to the Cache directory.
    #>
    [string] GetCachePath()
    {
        if ([string]::IsNullOrEmpty($this.Path))
        {
            return $null
        }
        return Join-Path -Path $this.Path -ChildPath 'Cache'
    }

    <#
        .SYNOPSIS
        Returns a string representation of the workspace.

        .OUTPUTS
        [string] A description of the workspace.
    #>
    [string] ToString()
    {
        return "MCDWorkspace: $($this.Name) at $($this.Path)"
    }
}
