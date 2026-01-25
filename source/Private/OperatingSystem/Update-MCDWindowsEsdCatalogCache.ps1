function Update-MCDWindowsEsdCatalogCache
{
    <#
    .SYNOPSIS
    Generates the in-repo Windows ESD catalog cache.

    .DESCRIPTION
    Builds a deterministic JSON (and XML) catalog of downloadable Windows ESD media
    by downloading Microsoft fwlink CAB(s), extracting products.xml, parsing
    MCT.Catalogs.Catalog.PublishedMedia.Files.File, filtering ESD entries, and writing
    the output to the specified cache directory.

    .PARAMETER OutputDirectory
    Output directory where catalog files will be written.

    .PARAMETER Fwlinks
    List of fwlink sources to download. Each entry must provide Id and Url.

    .PARAMETER ClientTypes
    Client type filters that must appear in the FilePath (e.g. CLIENTCONSUMER,
    CLIENTBUSINESS). Use both to build a combined catalog.

    .PARAMETER ProductsXmlInputs
    Optional offline inputs (for tests) to avoid downloading. Each entry must provide
    SourceFwlinkId and Path to a products.xml file.

    .PARAMETER IncludeUrl
    Includes direct download URLs in the committed catalog.

    .PARAMETER IncludeKey
    Includes the Key field from products.xml in the committed catalog.

    .PARAMETER MinimumItemCount
    Minimum number of items expected in the resulting catalog. If the generated
    catalog contains fewer items, the function throws to detect fwlink/schema drift.

    .EXAMPLE
    Update-MCDWindowsEsdCatalogCache -OutputDirectory '.\source\Cache\Operating System'
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $OutputDirectory,

        [Parameter()]
        [ValidateNotNull()]
        [hashtable[]]
        $Fwlinks = @(
            @{ Id = '841361';  Url = 'https://go.microsoft.com/fwlink/?LinkId=841361';  Purpose = 'Windows 10 products.cab' },
            @{ Id = '2156292'; Url = 'https://go.microsoft.com/fwlink/?LinkId=2156292'; Purpose = 'Windows 11 products.cab' }
        ),

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $ClientTypes = @('CLIENTCONSUMER', 'CLIENTBUSINESS'),

        [Parameter()]
        [ValidateNotNull()]
        [hashtable[]]
        $ProductsXmlInputs = @(),

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $IncludeUrl = $true,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $IncludeKey

        ,

        [Parameter()]
        [ValidateRange(0, 1000000)]
        [int]
        $MinimumItemCount = 100
    )

    function New-MCDDeterministicJson
    {
        param(
            [Parameter(Mandatory = $true)]
            [object]$Object
        )

        # ConvertTo-Json preserves property order for ordered hashtables/PSCustomObject.
        # Output must remain deterministic but human-readable.
        $json = ConvertTo-Json -InputObject $Object -Depth 8
        $json = ($json -replace "`r?`n", "`r`n").TrimEnd("`r", "`n")
        $json
    }

    function Write-MCDUtf8NoBomFile
    {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Path,
            [Parameter(Mandatory = $true)]
            [string]$Content
        )

        $encoding = New-Object System.Text.UTF8Encoding($false)
        $normalized = ($Content -replace "`r?`n", "`r`n").TrimEnd("`r", "`n") + "`r`n"
        [System.IO.File]::WriteAllText($Path, $normalized, $encoding)
    }

    function Write-MCDDeterministicXml
    {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Path,
            [Parameter(Mandatory = $true)]
            [hashtable]$Catalog
        )

        $settings = New-Object System.Xml.XmlWriterSettings
        $settings.OmitXmlDeclaration = $false
        $settings.Indent = $true
        $settings.IndentChars = '  '
        $settings.NewLineChars = "`r`n"
        $settings.NewLineHandling = [System.Xml.NewLineHandling]::Replace
        $settings.Encoding = New-Object System.Text.UTF8Encoding($false)

        $writer = [System.Xml.XmlWriter]::Create($Path, $settings)
        try
        {
            $writer.WriteStartDocument()
            $writer.WriteStartElement('WindowsEsdCatalog')
            $writer.WriteAttributeString('schemaVersion', [string]$Catalog.schemaVersion)

            $writer.WriteStartElement('Sources')
            foreach ($s in $Catalog.sources)
            {
                $writer.WriteStartElement('Source')
                $writer.WriteAttributeString('fwlinkId', [string]$s.id)
                $writer.WriteAttributeString('url', [string]$s.url)
                if ($s.cabSha256) { $writer.WriteAttributeString('cabSha256', [string]$s.cabSha256) }
                if ($s.productsXmlSha256) { $writer.WriteAttributeString('productsXmlSha256', [string]$s.productsXmlSha256) }
                if ($s.purpose) { $writer.WriteAttributeString('purpose', [string]$s.purpose) }
                $writer.WriteEndElement()
            }
            $writer.WriteEndElement()

            $writer.WriteStartElement('Items')
            foreach ($i in $Catalog.items)
            {
                $writer.WriteStartElement('Item')
                foreach ($p in $i.PSObject.Properties)
                {
                    if ($null -eq $p.Value) { continue }
                    $writer.WriteStartElement($p.Name)
                    $writer.WriteString([string]$p.Value)
                    $writer.WriteEndElement()
                }
                $writer.WriteEndElement()
            }
            $writer.WriteEndElement()

            $writer.WriteEndElement()
            $writer.WriteEndDocument()
        }
        finally
        {
            $writer.Dispose()
        }
    }

    $expandExe = Join-Path -Path $env:SystemRoot -ChildPath 'System32\expand.exe'
    if (-not (Test-Path -Path $expandExe))
    {
        throw "Required tool not found: $expandExe"
    }

    if (-not (Test-Path -Path $OutputDirectory))
    {
        $null = New-Item -Path $OutputDirectory -ItemType Directory -Force
    }

    $sources = @()
    $itemsAll = @()

    $tempRoot = Join-Path -Path $env:TEMP -ChildPath ('mcd-esd-catalog-' + [guid]::NewGuid())
    $null = New-Item -Path $tempRoot -ItemType Directory -Force
    try
    {
        $inputs = @()
        if ($ProductsXmlInputs -and $ProductsXmlInputs.Count -gt 0)
        {
            $inputs = $ProductsXmlInputs
        }
        else
        {
            $inputs = $Fwlinks
        }

        foreach ($src in $inputs)
        {
            $sourceId = [string]$src.SourceFwlinkId
            if (-not $sourceId)
            {
                $sourceId = [string]$src.Id
            }
            if (-not $sourceId)
            {
                throw 'Each source must provide Id or SourceFwlinkId.'
            }

            $purpose = [string]$src.Purpose
            $url = [string]$src.Url
            $xmlPath = [string]$src.Path
            $cabSha256 = $null

            if (-not $xmlPath)
            {
                if (-not $url)
                {
                    throw "Source '$sourceId' is missing Url."
                }

                $cabPath = Join-Path -Path $tempRoot -ChildPath ("products_$sourceId.cab")
                $null = Invoke-MCDDownload -Uri $url -DestinationPath $cabPath
                $cabSha256 = (Get-FileHash -Path $cabPath -Algorithm SHA256).Hash.ToLowerInvariant()

                $xmlPath = Join-Path -Path $tempRoot -ChildPath ("products_$sourceId.xml")
                & $expandExe '-F:products.xml' $cabPath $xmlPath | Out-Null
            }

            if (-not (Test-Path -Path $xmlPath))
            {
                throw "products.xml was not found for source '$sourceId' (expected '$xmlPath')."
            }

            $productsXmlSha256 = (Get-FileHash -Path $xmlPath -Algorithm SHA256).Hash.ToLowerInvariant()

            [xml]$x = Get-Content -Path $xmlPath -Raw
            $items = ConvertFrom-MCDProductsXml -ProductsXml $x -SourceFwlinkId $sourceId -ClientTypes $ClientTypes -IncludeUrl:$IncludeUrl -IncludeKey:$IncludeKey
            $itemsAll += @($items)

            $sources += [PSCustomObject]([ordered]@{
                    id                = $sourceId
                    url               = $url
                    purpose           = $purpose
                    cabSha256         = $cabSha256
                    productsXmlSha256 = $productsXmlSha256
                })
        }
    }
    finally
    {
        Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    if (-not $itemsAll -or $itemsAll.Count -lt 1)
    {
        throw 'No ESD items were produced from products.xml inputs.'
    }

    # Deterministic de-dup: prefer sha1 when present.
    $dedupMap = [ordered]@{}
    foreach ($i in $itemsAll)
    {
        $key = $null
        if ($i.sha1)
        {
            $key = 'sha1:' + [string]$i.sha1
        }
        else
        {
            $key = 'fp:' + [string]$i.url + '|fn:' + [string]$i.fileName
        }

        if (-not $dedupMap.Contains($key))
        {
            $dedupMap[$key] = $i
        }
    }

    $itemsSorted = @($dedupMap.Values) | Sort-Object -Property @(
        @{ Expression = { $_.sha1 } },
        @{ Expression = { $_.url } },
        @{ Expression = { $_.fileName } },
        @{ Expression = { $_.languageCode } },
        @{ Expression = { $_.architecture } },
        @{ Expression = { $_.edition } }
    )

    $catalog = [ordered]@{
        schemaVersion = 1
        sources       = @($sources | Sort-Object -Property id)
        items         = $itemsSorted
    }

    # Sanity check to detect schema drift or broken downloads.
    if ($catalog.items.Count -lt $MinimumItemCount)
    {
        throw ("Catalog looks unexpectedly small (items={0}, minimum={1}). Fwlink/schema may have changed." -f $catalog.items.Count, $MinimumItemCount)
    }

    $jsonPath = Join-Path -Path $OutputDirectory -ChildPath 'WindowsESD.json'
    $xmlPathOut = Join-Path -Path $OutputDirectory -ChildPath 'WindowsESD.xml'

    $json = New-MCDDeterministicJson -Object $catalog

    $writeJson = $true
    if (Test-Path -Path $jsonPath)
    {
        $existing = Get-Content -Path $jsonPath -Raw -ErrorAction SilentlyContinue
        if ($existing)
        {
            $existingNorm = ($existing -replace "`r?`n", "`r`n").TrimEnd("`r", "`n")
            $jsonNorm = ($json -replace "`r?`n", "`r`n").TrimEnd("`r", "`n")
            if ($existingNorm -eq $jsonNorm)
            {
                $writeJson = $false
            }
        }
    }

    $writeXml = $writeJson -or (-not (Test-Path -Path $xmlPathOut))

    if ($writeJson)
    {
        Write-MCDUtf8NoBomFile -Path $jsonPath -Content $json
    }

    if ($writeXml)
    {
        Write-MCDDeterministicXml -Path $xmlPathOut -Catalog $catalog
    }
}
