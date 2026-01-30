<#
.SYNOPSIS
Represents the Windows ADK installer information.

.DESCRIPTION
The ADKInstallerModel class represents information about Windows Assessment
and Deployment Kit (ADK) installation, including version and component paths.
#>
class ADKInstallerModel
{
    [string]$Version
    [string]$InstallPath
    [string]$WinPEAddOnPath
    [bool]$IsInstalled
    [bool]$HasWinPEAddOn
    [string]$DismPath
    [string]$OscdimgPath
    [datetime]$DetectedAt

    ADKInstallerModel()
    {
        $this.DetectedAt = Get-Date
        $this.IsInstalled = $false
        $this.HasWinPEAddOn = $false
    }

    ADKInstallerModel([string]$installPath)
    {
        if ([string]::IsNullOrWhiteSpace($installPath))
        {
            throw [System.ArgumentException]::new('InstallPath cannot be null or empty.', 'installPath')
        }

        $this.InstallPath = $installPath
        $this.DetectedAt = Get-Date
        $this.IsInstalled = $false
        $this.HasWinPEAddOn = $false
    }

    [void]Validate()
    {
        if ($this.IsInstalled -and [string]::IsNullOrWhiteSpace($this.InstallPath))
        {
            throw [System.InvalidOperationException]::new('InstallPath is required when IsInstalled is true.')
        }
        if ($this.HasWinPEAddOn -and [string]::IsNullOrWhiteSpace($this.WinPEAddOnPath))
        {
            throw [System.InvalidOperationException]::new('WinPEAddOnPath is required when HasWinPEAddOn is true.')
        }
    }

    [hashtable]ToHashtable()
    {
        return @{
            version        = $this.Version
            installPath    = $this.InstallPath
            winPEAddOnPath = $this.WinPEAddOnPath
            isInstalled    = $this.IsInstalled
            hasWinPEAddOn  = $this.HasWinPEAddOn
            dismPath       = $this.DismPath
            oscdimgPath    = $this.OscdimgPath
            detectedAt     = $this.DetectedAt.ToString('o')
        }
    }

    [string]ToJson()
    {
        return $this.ToHashtable() | ConvertTo-Json -Depth 10
    }

    static [ADKInstallerModel]FromHashtable([hashtable]$data)
    {
        $model = [ADKInstallerModel]::new()
        $model.Version = $data.version
        $model.InstallPath = $data.installPath
        $model.WinPEAddOnPath = $data.winPEAddOnPath
        $model.IsInstalled = $data.isInstalled -eq $true
        $model.HasWinPEAddOn = $data.hasWinPEAddOn -eq $true
        $model.DismPath = $data.dismPath
        $model.OscdimgPath = $data.oscdimgPath
        if ($data.detectedAt)
        {
            if ($data.detectedAt -is [datetime])
            {
                $model.DetectedAt = $data.detectedAt
            }
            else
            {
                $model.DetectedAt = [datetime]::Parse($data.detectedAt, $null, [System.Globalization.DateTimeStyles]::RoundtripKind)
            }
        }
        return $model
    }

    static [ADKInstallerModel]FromJson([string]$json)
    {
        $data = $json | ConvertFrom-Json -AsHashtable -ErrorAction SilentlyContinue
        if (-not $data)
        {
            $obj = $json | ConvertFrom-Json
            $data = @{}
            foreach ($prop in $obj.PSObject.Properties)
            {
                $data[$prop.Name] = $prop.Value
            }
        }
        return [ADKInstallerModel]::FromHashtable($data)
    }
}
