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

    .PARAMETER UseWorProject
    If set (default), uses WORProject MCT Catalogs API to enumerate historical CAB
    catalogs and selects the latest UBR per build major.

    .PARAMETER WorProjectVersionsUri
    URI to WORProject getversions endpoint.

    .PARAMETER MinimumBuildMajorWin10
    Minimum build major (e.g. 19041) to include for Windows 10 when using WORProject.

    .PARAMETER MinimumBuildMajorWin11
    Minimum build major (e.g. 22000) to include for Windows 11 when using WORProject.

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
            @{ Id = '841361';  Url = 'https://go.microsoft.com/fwlink/?LinkId=841361';  Purpose = 'Windows 10 products.cab'; WindowsMajor = '10' },
            @{ Id = '2156292'; Url = 'https://go.microsoft.com/fwlink/?LinkId=2156292'; Purpose = 'Windows 11 products.cab'; WindowsMajor = '11' }
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
        $UseWorProject = $true,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $WorProjectVersionsUri = 'https://worproject.com/dldserv/esd/getversions.php',

        [Parameter()]
        [ValidateRange(0, 99999)]
        [int]
        $MinimumBuildMajorWin10 = 0,

        [Parameter()]
        [ValidateRange(0, 99999)]
        [int]
        $MinimumBuildMajorWin11 = 22000,

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

    function Get-MCDFwlinkIdFromUrl
    {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Url
        )

        try
        {
            $u = [System.Uri]$Url
            $query = $u.Query
            if (-not $query)
            {
                return $null
            }

            $m = [regex]::Match($query, '(?i)(?:\?|&)LinkId=(\d+)')
            if ($m.Success)
            {
                return $m.Groups[1].Value
            }
        }
        catch
        {
        }

        $null
    }

    function ConvertTo-MCDWindowsMajor
    {
        param(
            [Parameter(Mandatory = $true)]
            [object]$Value
        )

        if ($null -eq $Value)
        {
            return $null
        }

        $s = [string]$Value
        if (-not $s)
        {
            return $null
        }

        if ($s -match '^\d+$')
        {
            return $s
        }

        $null
    }

    function ConvertTo-MCDBuildParts
    {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Build
        )

        $major = $null
        $ubr = $null

        $m = [regex]::Match($Build, '^(\d{5})(?:\.(\d+))?$')
        if ($m.Success)
        {
            [int]$tmpMajor = 0
            if ([int]::TryParse($m.Groups[1].Value, [ref]$tmpMajor))
            {
                $major = $tmpMajor
            }

            if ($m.Groups[2].Success)
            {
                [int]$tmpUbr = 0
                if ([int]::TryParse($m.Groups[2].Value, [ref]$tmpUbr))
                {
                    $ubr = $tmpUbr
                }
            }
        }

        [pscustomobject]@{
            Major = $major
            Ubr   = $ubr
        }
    }

    $latestFwlinksMap = @{}

    function Add-MCDLatestFwlink
    {
        param(
            [Parameter(Mandatory = $true)]
            [object]$WindowsMajor,
            [Parameter(Mandatory = $true)]
            [string]$FwlinkUrl
        )

        $wm = ConvertTo-MCDWindowsMajor -Value $WindowsMajor
        if (-not $wm)
        {
            return
        }

        $id = Get-MCDFwlinkIdFromUrl -Url $FwlinkUrl
        if (-not $id)
        {
            return
        }

        $latestFwlinksMap[$wm] = [PSCustomObject]([ordered]@{
                windowsMajor = $wm
                fwlinkId     = $id
                fwlinkUrl    = $FwlinkUrl
            })
    }

    function Get-MCDWorProjectSources
    {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Uri
        )

        $resp = Invoke-WebRequest -UseBasicParsing -Uri $Uri -ErrorAction Stop
        [xml]$db = $resp.Content

        $sources = @()

        foreach ($v in @($db.productsDb.versions.version))
        {
            $windowsMajor = [string]$v.number
            if (-not $windowsMajor)
            {
                continue
            }

            $latestFwlinkUrl = [string]$v.latestCabLink
            if ($latestFwlinkUrl)
            {
                Add-MCDLatestFwlink -WindowsMajor $windowsMajor -FwlinkUrl $latestFwlinkUrl
            }

            $bestByBuildMajor = @{}

            foreach ($r in @($v.releases.release))
            {
                $build = [string]$r.build
                $date = [string]$r.date
                $cabUrl = [string]$r.cabLink
                if (-not $build -or -not $cabUrl)
                {
                    continue
                }

                $parts = ConvertTo-MCDBuildParts -Build $build
                if (-not $parts.Major)
                {
                    continue
                }

                $key = [string]$parts.Major
                $current = $bestByBuildMajor[$key]

                $take = $false
                if (-not $current)
                {
                    $take = $true
                }
                else
                {
                    # Prefer highest UBR for a given build major.
                    $curUbr = $current.BuildUbr
                    $newUbr = $parts.Ubr
                    if ($null -eq $curUbr) { $curUbr = -1 }
                    if ($null -eq $newUbr) { $newUbr = -1 }

                    if ($newUbr -gt $curUbr)
                    {
                        $take = $true
                    }
                    elseif ($newUbr -eq $curUbr)
                    {
                        # Tie-breaker: latest date.
                        if ($date -and ($date -gt $current.Date))
                        {
                            $take = $true
                        }
                    }
                }

                if ($take)
                {
                $bestByBuildMajor[$key] = [pscustomobject]@{
                    WindowsMajor    = $windowsMajor
                    LatestFwlinkUrl = $latestFwlinkUrl
                    Build           = $build
                    BuildMajor      = $parts.Major
                    BuildUbr        = $parts.Ubr
                    Date            = $date
                    CabUrl          = $cabUrl
                }
            }
        }

            $selected = @($bestByBuildMajor.Values)

            # Keep the catalog set to a reasonable/supported range by default.
            if ($windowsMajor -eq '10')
            {
                $selected = @($selected | Where-Object { $_.BuildMajor -ge $MinimumBuildMajorWin10 })
            }
            elseif ($windowsMajor -eq '11')
            {
                $selected = @($selected | Where-Object { $_.BuildMajor -ge $MinimumBuildMajorWin11 })
            }

            $sources += $selected
        }

        # Deterministic ordering: newest Windows/build first.
        $sources | Sort-Object -Descending -Property @(
            @{ Expression = { [int]$_.WindowsMajor } },
            @{ Expression = { $_.BuildMajor } },
            @{ Expression = { $_.BuildUbr } },
            @{ Expression = { $_.Date } },
            @{ Expression = { $_.CabUrl } }
        )
    }

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

            $writer.WriteStartElement('LatestFwlinks')
            foreach ($lf in $Catalog.latestFwlinks)
            {
                $writer.WriteStartElement('LatestFwlink')
                if ($lf.windowsMajor) { $writer.WriteAttributeString('windowsMajor', [string]$lf.windowsMajor) }
                if ($lf.fwlinkId) { $writer.WriteAttributeString('fwlinkId', [string]$lf.fwlinkId) }
                if ($lf.fwlinkUrl) { $writer.WriteAttributeString('fwlinkUrl', [string]$lf.fwlinkUrl) }
                $writer.WriteEndElement()
            }
            $writer.WriteEndElement()

            $writer.WriteStartElement('Sources')
            foreach ($s in $Catalog.sources)
            {
                $writer.WriteStartElement('Source')
                if ($s.id) { $writer.WriteAttributeString('id', [string]$s.id) }
                if ($s.windowsMajor) { $writer.WriteAttributeString('windowsMajor', [string]$s.windowsMajor) }
                if ($s.build) { $writer.WriteAttributeString('build', [string]$s.build) }
                if ($null -ne $s.buildMajor) { $writer.WriteAttributeString('buildMajor', [string]$s.buildMajor) }
                if ($null -ne $s.buildUbr) { $writer.WriteAttributeString('buildUbr', [string]$s.buildUbr) }
                if ($s.date) { $writer.WriteAttributeString('date', [string]$s.date) }
                if ($s.cabUrl) { $writer.WriteAttributeString('cabUrl', [string]$s.cabUrl) }
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

    # Seed latest fwlinks from the explicit Fwlinks parameter.
    foreach ($f in @($Fwlinks))
    {
        $fUrl = [string]$f.Url
        if (-not $fUrl)
        {
            continue
        }

        $wm = $null
        if ($f.ContainsKey('WindowsMajor'))
        {
            $wm = $f.WindowsMajor
        }
        elseif ($f.ContainsKey('Purpose'))
        {
            $p = [string]$f.Purpose
            if ($p -match '(?i)Windows\s+11') { $wm = '11' }
            elseif ($p -match '(?i)Windows\s+10') { $wm = '10' }
        }

        Add-MCDLatestFwlink -WindowsMajor $wm -FwlinkUrl $fUrl
    }

    $tempRoot = Join-Path -Path $env:TEMP -ChildPath ('mcd-esd-catalog-' + [guid]::NewGuid())
    $null = New-Item -Path $tempRoot -ItemType Directory -Force
    try
    {
        $inputs = @()
        if ($ProductsXmlInputs -and $ProductsXmlInputs.Count -gt 0)
        {
            $inputs = $ProductsXmlInputs
        }
        elseif ($UseWorProject)
        {
            $inputs = Get-MCDWorProjectSources -Uri $WorProjectVersionsUri
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

            $purpose = [string]$src.Purpose
            $url = [string]$src.Url
            $xmlPath = [string]$src.Path
            $cabSha256 = $null

            $windowsMajor = $null
            $build = $null
            $buildMajor = $null
            $buildUbr = $null
            $date = $null
            $fwlinkUrl = $null
            $fwlinkId = $null
            $cabUrl = $null

            if ($UseWorProject -and (-not $ProductsXmlInputs -or $ProductsXmlInputs.Count -eq 0))
            {
                $windowsMajor = [string]$src.WindowsMajor
                $build = [string]$src.Build
                $buildMajor = $src.BuildMajor
                $buildUbr = $src.BuildUbr
                $date = [string]$src.Date
                $fwlinkUrl = [string]$src.LatestFwlinkUrl
                $cabUrl = [string]$src.CabUrl

                if (-not $cabUrl)
                {
                    throw "WORProject source missing CabUrl for Windows $windowsMajor build '$build'."
                }

                # Some entries are hosted on WORProject as mirrors. Prefer Microsoft-hosted URLs when possible.
                # If the CAB is not hosted by Microsoft, we will attempt it first, then fall back to the fwlink.
                $downloadUrl = $cabUrl
                try
                {
                    $hostName = ([System.Uri]$cabUrl).Host
                    if ($hostName -ieq 'worproject.com' -and $fwlinkUrl)
                    {
                        $downloadUrl = $cabUrl
                    }
                }
                catch
                {
                }

                if (-not $sourceId)
                {
                    # Stable id for the source.
                    $sourceId = "Win{0}_{1}" -f $windowsMajor, $build
                }

                if (-not $purpose)
                {
                    $purpose = "Windows $windowsMajor catalog $build ($date)"
                }

                # When using WORProject sources, use CabUrl as the primary URL.
                $url = $downloadUrl
            }

            if (-not $sourceId)
            {
                throw 'Each source must provide Id/SourceFwlinkId, or enough metadata to build one.'
            }

            if (-not $xmlPath)
            {
                if (-not $url)
                {
                    if ($cabUrl)
                    {
                        $url = $cabUrl
                    }
                    else
                    {
                        throw "Source '$sourceId' is missing Url."
                    }
                }

                $cabPath = Join-Path -Path $tempRoot -ChildPath ("products_$sourceId.cab")
                try
                {
                    $null = Invoke-MCDDownload -Uri $url -DestinationPath $cabPath
                }
                catch
                {
                    if ($UseWorProject)
                    {
                        # Historical CABs may be unreachable from some networks. Do not silently
                        # swap to a different (latest) catalog via fwlink; that would corrupt
                        # the intended build selection.
                        Write-Warning -Message ("Skipping source '{0}' because CAB download failed: {1}" -f $sourceId, $_.Exception.Message)
                        continue
                    }

                    throw
                }
                $cabSha256 = (Get-FileHash -Path $cabPath -Algorithm SHA256).Hash.ToLowerInvariant()

                $xmlPath = Join-Path -Path $tempRoot -ChildPath ("products_$sourceId.xml")
                & $expandExe '-F:products.xml' $cabPath $xmlPath | Out-Null

                if (-not (Test-Path -Path $xmlPath))
                {
                    # Fallback for CABs that don't embed products.xml with expected name.
                    $null = & $expandExe '-F:*.xml' $cabPath $tempRoot
                    $xmlCandidates = @(Get-ChildItem -Path $tempRoot -Filter '*.xml' -File | Where-Object { $_.Name -notlike "products_$sourceId.xml" })
                    if ($xmlCandidates.Count -eq 1)
                    {
                        Copy-Item -Path $xmlCandidates[0].FullName -Destination $xmlPath -Force
                    }
                }
            }

            if (-not (Test-Path -Path $xmlPath))
            {
                throw "products.xml was not found for source '$sourceId' (expected '$xmlPath')."
            }

            $productsXmlSha256 = (Get-FileHash -Path $xmlPath -Algorithm SHA256).Hash.ToLowerInvariant()

            [xml]$x = Get-Content -Path $xmlPath -Raw
            $items = ConvertFrom-MCDProductsXml -ProductsXml $x -SourceFwlinkId $sourceId -ClientTypes $ClientTypes -IncludeUrl:$IncludeUrl -IncludeKey:$IncludeKey
            $itemsAll += @($items)

            if ($UseWorProject -and $buildMajor)
            {
                $matchesExpected = @($items | Where-Object { $_.buildMajor -eq $buildMajor })
                if ($matchesExpected.Count -lt 1)
                {
                    Write-Warning -Message "Source '$sourceId' did not yield any ESD items matching expected buildMajor '$buildMajor'. Keeping items anyway."
                }
            }

            $sources += [PSCustomObject]([ordered]@{
                    id                = $sourceId
                    windowsMajor      = $windowsMajor
                    build             = $build
                    buildMajor        = $buildMajor
                    buildUbr          = $buildUbr
                    date              = $date
                    cabUrl            = $url
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

    $itemsSorted = @($dedupMap.Values) | Sort-Object -Descending -Property @(
        @{ Expression = { $_.windowsRelease } },
        @{ Expression = { $_.buildMajor } },
        @{ Expression = { $_.buildUbr } },
        @{ Expression = { $_.architecture } },
        @{ Expression = { $_.languageCode } },
        @{ Expression = { $_.edition } },
        @{ Expression = { $_.fileName } },
        @{ Expression = { $_.sha1 } }
    )

    $latestFwlinks = @($latestFwlinksMap.Values) | Sort-Object -Descending -Property @(
        @{ Expression = { [int]$_.windowsMajor } },
        @{ Expression = { $_.fwlinkId } },
        @{ Expression = { $_.fwlinkUrl } }
    )

    $catalog = [ordered]@{
        schemaVersion = 1
        latestFwlinks = $latestFwlinks
        sources       = @($sources | Sort-Object -Descending -Property @(
                @{ Expression = { [int]$_.windowsMajor } },
                @{ Expression = { $_.buildMajor } },
                @{ Expression = { $_.buildUbr } },
                @{ Expression = { $_.date } },
                @{ Expression = { $_.id } }
            ))
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
