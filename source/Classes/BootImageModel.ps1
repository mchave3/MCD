<#
.SYNOPSIS
Represents a Windows PE boot image for USB creation.

.DESCRIPTION
The BootImageModel class represents a boot image (WIM/ESD) that can be used
to create bootable USB media for MCD deployments.
#>
class BootImageModel
{
    [string]$Path
    [string]$Name
    [string]$Architecture
    [string]$Version
    [long]$SizeBytes
    [datetime]$CreatedAt
    [bool]$IsValid

    BootImageModel()
    {
        $this.CreatedAt = Get-Date
        $this.IsValid = $false
    }

    BootImageModel([string]$path)
    {
        if ([string]::IsNullOrWhiteSpace($path))
        {
            throw [System.ArgumentException]::new('Path cannot be null or empty.', 'path')
        }

        $this.Path = $path
        $this.Name = [System.IO.Path]::GetFileName($path)
        $this.CreatedAt = Get-Date
        $this.IsValid = $false
    }

    [void]Validate()
    {
        if ([string]::IsNullOrWhiteSpace($this.Path))
        {
            throw [System.InvalidOperationException]::new('Path is required.')
        }
        if ([string]::IsNullOrWhiteSpace($this.Architecture))
        {
            throw [System.InvalidOperationException]::new('Architecture is required.')
        }
        if ($this.Architecture -notin @('amd64', 'arm64'))
        {
            throw [System.InvalidOperationException]::new("Invalid architecture: '$($this.Architecture)'. Must be 'amd64' or 'arm64'.")
        }
    }

    [hashtable]ToHashtable()
    {
        return @{
            path         = $this.Path
            name         = $this.Name
            architecture = $this.Architecture
            version      = $this.Version
            sizeBytes    = $this.SizeBytes
            createdAt    = $this.CreatedAt.ToString('o')
            isValid      = $this.IsValid
        }
    }

    [string]ToJson()
    {
        return $this.ToHashtable() | ConvertTo-Json -Depth 10
    }

    static [BootImageModel]FromHashtable([hashtable]$data)
    {
        $model = [BootImageModel]::new()
        $model.Path = $data.path
        $model.Name = $data.name
        $model.Architecture = $data.architecture
        $model.Version = $data.version
        $model.SizeBytes = if ($data.sizeBytes) { $data.sizeBytes } else { 0 }
        if ($data.createdAt)
        {
            if ($data.createdAt -is [datetime])
            {
                $model.CreatedAt = $data.createdAt
            }
            else
            {
                $model.CreatedAt = [datetime]::Parse($data.createdAt, $null, [System.Globalization.DateTimeStyles]::RoundtripKind)
            }
        }
        $model.IsValid = $data.isValid -eq $true
        return $model
    }

    static [BootImageModel]FromJson([string]$json)
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
        return [BootImageModel]::FromHashtable($data)
    }
}
