<#
    .SYNOPSIS
    MCD Configuration class for storing and managing module configuration.

    .DESCRIPTION
    The MCDConfig class represents the main configuration object for the MCD module.
    It provides methods to load configuration from JSON files and save configuration back.
    This class is designed to work in both full Windows and WinPE environments (PS 5.1+).
#>
class MCDConfig
{
    # Configuration version for compatibility checking
    [string] $Version = '1.0'

    # Root path for MCD workspace data
    [string] $WorkspacePath

    # Default settings hashtable
    [hashtable] $Defaults = @{}

    # Logging configuration
    [hashtable] $Logging = @{
        Level    = 'Info'
        FileName = 'mcd.log'
    }

    # Default constructor
    MCDConfig()
    {
        $this.WorkspacePath = Join-Path -Path $env:ProgramData -ChildPath 'MCD'
    }

    # Constructor with custom workspace path
    MCDConfig([string] $WorkspacePath)
    {
        $this.WorkspacePath = $WorkspacePath
    }

    <#
        .SYNOPSIS
        Loads configuration from a JSON file.

        .DESCRIPTION
        Static method that reads a JSON configuration file and returns an MCDConfig object.
        If optional fields are missing, defaults are applied.

        .PARAMETER Path
        The path to the JSON configuration file.

        .OUTPUTS
        [MCDConfig] The loaded configuration object.
    #>
    static [MCDConfig] Load([string] $Path)
    {
        if (-not (Test-Path -Path $Path -PathType Leaf))
        {
            throw "Configuration file not found: $Path"
        }

        $jsonContent = Get-Content -Path $Path -Raw -ErrorAction Stop
        $configData = $jsonContent | ConvertFrom-Json

        $config = [MCDConfig]::new()

        # Apply loaded values, keeping defaults for missing properties
        if ($null -ne $configData.Version)
        {
            $config.Version = $configData.Version
        }

        if ($null -ne $configData.WorkspacePath)
        {
            $config.WorkspacePath = $configData.WorkspacePath
        }

        if ($null -ne $configData.Defaults)
        {
            # Convert PSCustomObject to hashtable for PS 5.1 compatibility
            $config.Defaults = [MCDConfig]::ConvertToHashtable($configData.Defaults)
        }

        if ($null -ne $configData.Logging)
        {
            $config.Logging = [MCDConfig]::ConvertToHashtable($configData.Logging)
        }

        return $config
    }

    <#
        .SYNOPSIS
        Saves the configuration to a JSON file.

        .DESCRIPTION
        Serializes the configuration object to JSON and writes it to the specified path.
        Creates the parent directory if it does not exist.

        .PARAMETER Path
        The path where the configuration file will be saved.
    #>
    [void] Save([string] $Path)
    {
        $parentDir = Split-Path -Path $Path -Parent
        if (-not [string]::IsNullOrEmpty($parentDir) -and -not (Test-Path -Path $parentDir))
        {
            New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
        }

        $configObject = [ordered]@{
            Version       = $this.Version
            WorkspacePath = $this.WorkspacePath
            Defaults      = $this.Defaults
            Logging       = $this.Logging
        }

        $json = $configObject | ConvertTo-Json -Depth 10

        # Write using .NET for consistent encoding (UTF8 without BOM)
        [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
    }

    <#
        .SYNOPSIS
        Converts a PSCustomObject to a hashtable.

        .DESCRIPTION
        Helper method for PS 5.1 compatibility when deserializing JSON.

        .PARAMETER InputObject
        The PSCustomObject to convert.

        .OUTPUTS
        [hashtable] The converted hashtable.
    #>
    hidden static [hashtable] ConvertToHashtable([object] $InputObject)
    {
        if ($null -eq $InputObject)
        {
            return @{}
        }

        if ($InputObject -is [hashtable])
        {
            return $InputObject
        }

        $hashtable = @{}

        foreach ($property in $InputObject.PSObject.Properties)
        {
            $value = $property.Value
            if ($value -is [System.Management.Automation.PSCustomObject])
            {
                $hashtable[$property.Name] = [MCDConfig]::ConvertToHashtable($value)
            }
            else
            {
                $hashtable[$property.Name] = $value
            }
        }

        return $hashtable
    }

    <#
        .SYNOPSIS
        Returns a string representation of the configuration.

        .OUTPUTS
        [string] A description of the configuration.
    #>
    [string] ToString()
    {
        return "MCDConfig v$($this.Version) - WorkspacePath: $($this.WorkspacePath)"
    }
}
