function Get-MCDConfig
{
    <#
      .SYNOPSIS
      Loads the MCD configuration from a JSON file.

      .DESCRIPTION
      This function reads the MCD configuration from a JSON file and returns an MCDConfig
      object. If the configuration file does not exist, it can optionally create a new
      configuration with default values.

      .EXAMPLE
      $config = Get-MCDConfig

      Loads the configuration from the default location.

      .EXAMPLE
      $config = Get-MCDConfig -Path 'D:\MCD\config.json'

      Loads the configuration from a custom path.

      .EXAMPLE
      $config = Get-MCDConfig -CreateIfMissing

      Creates a new configuration file with defaults if it doesn't exist.

      .PARAMETER Path
      The path to the configuration file. Defaults to the standard MCD configuration
      location at $env:ProgramData\MCD\config.json.

      .PARAMETER CreateIfMissing
      If specified and the configuration file does not exist, creates a new configuration
      with default values and saves it to the specified path.

      .OUTPUTS
      [MCDConfig] The loaded or newly created configuration object.
    #>
    [CmdletBinding()]
    [OutputType([MCDConfig])]
    param
    (
        [Parameter()]
        [string]
        $Path = (Join-Path -Path $env:ProgramData -ChildPath 'MCD\config.json'),

        [Parameter()]
        [switch]
        $CreateIfMissing
    )

    process
    {
        Write-Verbose -Message "Loading MCD configuration from: $Path"

        if (Test-Path -Path $Path -PathType Leaf)
        {
            try
            {
                $config = [MCDConfig]::Load($Path)
                Write-Verbose -Message "Configuration loaded successfully: $($config.ToString())"
                return $config
            }
            catch
            {
                Write-Error -Message "Failed to load configuration from '$Path': $($_.Exception.Message)"
                throw
            }
        }
        elseif ($CreateIfMissing)
        {
            Write-Verbose -Message 'Configuration file not found. Creating new configuration with defaults.'

            $config = [MCDConfig]::new()

            try
            {
                $config.Save($Path)
                Write-Verbose -Message "Default configuration saved to: $Path"
            }
            catch
            {
                Write-Warning -Message "Failed to save default configuration: $($_.Exception.Message)"
            }

            return $config
        }
        else
        {
            throw "Configuration file not found: $Path"
        }
    }
}
