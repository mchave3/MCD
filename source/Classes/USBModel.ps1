<#
.SYNOPSIS
Represents a USB drive for MCD deployments.

.DESCRIPTION
The USBModel class represents a USB drive that can be used for creating
bootable media or storing deployment profiles.
#>
class USBModel
{
    [string]$DriveLetter
    [string]$DeviceId
    [string]$FriendlyName
    [long]$SizeBytes
    [string]$FileSystem
    [string]$PartitionStyle
    [bool]$IsBootable
    [bool]$IsReady
    [datetime]$DetectedAt

    USBModel()
    {
        $this.DetectedAt = Get-Date
        $this.IsBootable = $false
        $this.IsReady = $false
    }

    USBModel([string]$driveLetter)
    {
        if ([string]::IsNullOrWhiteSpace($driveLetter))
        {
            throw [System.ArgumentException]::new('DriveLetter cannot be null or empty.', 'driveLetter')
        }

        # Normalize drive letter format
        $this.DriveLetter = $driveLetter.TrimEnd(':').ToUpper() + ':'
        $this.DetectedAt = Get-Date
        $this.IsBootable = $false
        $this.IsReady = $false
    }

    [void]Validate()
    {
        if ([string]::IsNullOrWhiteSpace($this.DriveLetter))
        {
            throw [System.InvalidOperationException]::new('DriveLetter is required.')
        }
        if ($this.DriveLetter -notmatch '^[A-Z]:$')
        {
            throw [System.InvalidOperationException]::new("Invalid drive letter format: '$($this.DriveLetter)'. Expected format: 'X:'.")
        }
        if ($this.SizeBytes -lt 0)
        {
            throw [System.InvalidOperationException]::new('SizeBytes cannot be negative.')
        }
    }

    [hashtable]ToHashtable()
    {
        return @{
            driveLetter    = $this.DriveLetter
            deviceId       = $this.DeviceId
            friendlyName   = $this.FriendlyName
            sizeBytes      = $this.SizeBytes
            fileSystem     = $this.FileSystem
            partitionStyle = $this.PartitionStyle
            isBootable     = $this.IsBootable
            isReady        = $this.IsReady
            detectedAt     = $this.DetectedAt.ToString('o')
        }
    }

    [string]ToJson()
    {
        return $this.ToHashtable() | ConvertTo-Json -Depth 10
    }

    static [USBModel]FromHashtable([hashtable]$data)
    {
        $model = [USBModel]::new()
        $model.DriveLetter = $data.driveLetter
        $model.DeviceId = $data.deviceId
        $model.FriendlyName = $data.friendlyName
        $model.SizeBytes = if ($data.sizeBytes) { $data.sizeBytes } else { 0 }
        $model.FileSystem = $data.fileSystem
        $model.PartitionStyle = $data.partitionStyle
        $model.IsBootable = $data.isBootable -eq $true
        $model.IsReady = $data.isReady -eq $true
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

    static [USBModel]FromJson([string]$json)
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
        return [USBModel]::FromHashtable($data)
    }
}
