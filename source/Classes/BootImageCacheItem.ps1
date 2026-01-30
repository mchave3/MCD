<#
.SYNOPSIS
Represents a cached boot image entry.

.DESCRIPTION
The BootImageCacheItem class represents a boot image that has been cached
locally for faster access during USB creation or deployment operations.
#>
class BootImageCacheItem
{
    [string]$Id
    [string]$SourcePath
    [string]$CachePath
    [string]$Architecture
    [string]$Version
    [long]$SizeBytes
    [string]$Hash
    [string]$HashAlgorithm = 'SHA256'
    [datetime]$CachedAt
    [datetime]$LastAccessedAt
    [bool]$IsValid

    BootImageCacheItem()
    {
        $this.Id = [guid]::NewGuid().ToString()
        $this.CachedAt = Get-Date
        $this.LastAccessedAt = Get-Date
        $this.IsValid = $false
    }

    BootImageCacheItem([string]$sourcePath, [string]$cachePath)
    {
        if ([string]::IsNullOrWhiteSpace($sourcePath))
        {
            throw [System.ArgumentException]::new('SourcePath cannot be null or empty.', 'sourcePath')
        }
        if ([string]::IsNullOrWhiteSpace($cachePath))
        {
            throw [System.ArgumentException]::new('CachePath cannot be null or empty.', 'cachePath')
        }

        $this.Id = [guid]::NewGuid().ToString()
        $this.SourcePath = $sourcePath
        $this.CachePath = $cachePath
        $this.CachedAt = Get-Date
        $this.LastAccessedAt = Get-Date
        $this.IsValid = $false
    }

    [void]Validate()
    {
        if ([string]::IsNullOrWhiteSpace($this.SourcePath))
        {
            throw [System.InvalidOperationException]::new('SourcePath is required.')
        }
        if ([string]::IsNullOrWhiteSpace($this.CachePath))
        {
            throw [System.InvalidOperationException]::new('CachePath is required.')
        }
        if ($this.SizeBytes -lt 0)
        {
            throw [System.InvalidOperationException]::new('SizeBytes cannot be negative.')
        }
        if (-not [string]::IsNullOrWhiteSpace($this.Architecture) -and $this.Architecture -notin @('amd64', 'arm64'))
        {
            throw [System.InvalidOperationException]::new("Invalid architecture: '$($this.Architecture)'. Must be 'amd64' or 'arm64'.")
        }
    }

    [void]UpdateLastAccessed()
    {
        $this.LastAccessedAt = Get-Date
    }

    [hashtable]ToHashtable()
    {
        return @{
            id             = $this.Id
            sourcePath     = $this.SourcePath
            cachePath      = $this.CachePath
            architecture   = $this.Architecture
            version        = $this.Version
            sizeBytes      = $this.SizeBytes
            hash           = $this.Hash
            hashAlgorithm  = $this.HashAlgorithm
            cachedAt       = $this.CachedAt.ToString('o')
            lastAccessedAt = $this.LastAccessedAt.ToString('o')
            isValid        = $this.IsValid
        }
    }

    [string]ToJson()
    {
        return $this.ToHashtable() | ConvertTo-Json -Depth 10
    }

    static [BootImageCacheItem]FromHashtable([hashtable]$data)
    {
        $model = [BootImageCacheItem]::new()
        $model.Id = if ($data.id) { $data.id } else { [guid]::NewGuid().ToString() }
        $model.SourcePath = $data.sourcePath
        $model.CachePath = $data.cachePath
        $model.Architecture = $data.architecture
        $model.Version = $data.version
        $model.SizeBytes = if ($data.sizeBytes) { $data.sizeBytes } else { 0 }
        $model.Hash = $data.hash
        $model.HashAlgorithm = if ($data.hashAlgorithm) { $data.hashAlgorithm } else { 'SHA256' }
        if ($data.cachedAt)
        {
            if ($data.cachedAt -is [datetime])
            {
                $model.CachedAt = $data.cachedAt
            }
            else
            {
                $model.CachedAt = [datetime]::Parse($data.cachedAt, $null, [System.Globalization.DateTimeStyles]::RoundtripKind)
            }
        }
        if ($data.lastAccessedAt)
        {
            if ($data.lastAccessedAt -is [datetime])
            {
                $model.LastAccessedAt = $data.lastAccessedAt
            }
            else
            {
                $model.LastAccessedAt = [datetime]::Parse($data.lastAccessedAt, $null, [System.Globalization.DateTimeStyles]::RoundtripKind)
            }
        }
        $model.IsValid = $data.isValid -eq $true
        return $model
    }

    static [BootImageCacheItem]FromJson([string]$json)
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
        return [BootImageCacheItem]::FromHashtable($data)
    }
}
