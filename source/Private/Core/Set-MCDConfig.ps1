function Set-MCDConfig
{
    <#
      .SYNOPSIS
      Saves the MCD configuration to a JSON file.

      .DESCRIPTION
      This function serializes an MCDConfig object to JSON and writes it to the specified
      file path. It supports the WhatIf and Confirm parameters for safe operation.

      .EXAMPLE
      $config = Get-MCDConfig
      $config.Logging.Level = 'Debug'
      Set-MCDConfig -Config $config

      Modifies the logging level and saves the configuration.

      .EXAMPLE
      Set-MCDConfig -Config $config -Path 'D:\Backup\mcd-config.json'

      Saves the configuration to a custom backup location.

      .EXAMPLE
      Set-MCDConfig -Config $config -WhatIf

      Shows what would happen without actually saving the configuration.

      .PARAMETER Config
      The MCDConfig object to save. This parameter is mandatory.

      .PARAMETER Path
      The path where the configuration file will be saved. Defaults to the standard
      MCD configuration location at $env:ProgramData\MCD\config.json.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [MCDConfig]
        $Config,

        [Parameter()]
        [string]
        $Path = (Join-Path -Path $env:ProgramData -ChildPath 'MCD\config.json')
    )

    process
    {
        if ($PSCmdlet.ShouldProcess($Path, 'Save MCD configuration'))
        {
            Write-Verbose -Message "Saving MCD configuration to: $Path"

            try
            {
                $Config.Save($Path)
                Write-Verbose -Message "Configuration saved successfully: $($Config.ToString())"
            }
            catch
            {
                Write-Error -Message "Failed to save configuration to '$Path': $($_.Exception.Message)"
                throw
            }
        }
        else
        {
            Write-Verbose -Message "WhatIf: Would save configuration to: $Path"
        }
    }
}
