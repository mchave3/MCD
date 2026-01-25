function ConvertFrom-MCDProductsXml
{
    <#
    .SYNOPSIS
    Converts a Microsoft products.xml into normalized ESD catalog items.

    .DESCRIPTION
    Parses an MCT products.xml (typically extracted from a Microsoft fwlink CAB)
    and returns a deterministic, normalized set of items representing downloadable
    Windows ESD entries.

    .PARAMETER ProductsXml
    The products.xml loaded as an [xml] object.

    .PARAMETER SourceFwlinkId
    The fwlink id used to obtain the CAB that contained this products.xml.

    .PARAMETER ClientTypes
    Client type filters that must appear in the FilePath (e.g. CLIENTCONSUMER,
    CLIENTBUSINESS). Use both to build a combined catalog.

    .PARAMETER IncludeUrl
    Includes the FilePath (direct download URL) in returned items.

    .PARAMETER IncludeKey
    Includes the Key field from products.xml if present.

    .EXAMPLE
    [xml]$x = Get-Content -Path .\products.xml -Raw
    ConvertFrom-MCDProductsXml -ProductsXml $x -SourceFwlinkId 2156292 -ClientTypes @('CLIENTCONSUMER','CLIENTBUSINESS')
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [xml]
        $ProductsXml,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $SourceFwlinkId,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $ClientTypes = @('CLIENTCONSUMER', 'CLIENTBUSINESS'),

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $IncludeUrl,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $IncludeKey
    )

    $fileNodes = @()
    try
    {
        $fileNodes = @($ProductsXml.MCT.Catalogs.Catalog.PublishedMedia.Files.File)
    }
    catch
    {
        throw "products.xml did not contain expected node path: MCT.Catalogs.Catalog.PublishedMedia.Files.File"
    }

    if (-not $fileNodes -or $fileNodes.Count -lt 1)
    {
        return @()
    }

    $clientTypeRegex = ($ClientTypes | ForEach-Object { [regex]::Escape($_) }) -join '|'

    $items = foreach ($f in $fileNodes)
    {
        if (-not $f)
        {
            continue
        }

        $fileName = [string]$f.FileName
        if (-not $fileName)
        {
            continue
        }

        if (-not ($fileName -like '*.esd'))
        {
            continue
        }

        $filePath = [string]$f.FilePath
        if (-not $filePath)
        {
            continue
        }

        if ($clientTypeRegex -and (-not ([regex]::IsMatch($filePath, $clientTypeRegex))))
        {
            continue
        }

        $sha1 = [string]$f.Sha1
        $sizeText = [string]$f.Size
        $sizeBytes = $null
        if ($sizeText)
        {
            [long]$tmp = 0
            if ([long]::TryParse($sizeText, [ref]$tmp))
            {
                $sizeBytes = $tmp
            }
        }

        $architecture = [string]$f.Architecture
        $languageCode = [string]$f.LanguageCode
        $language = [string]$f.Language
        $edition = [string]$f.Edition

        $isRetailOnlyText = [string]$f.IsRetailOnly
        $isRetailOnly = $null
        if ($isRetailOnlyText)
        {
            $isRetailOnly = ($isRetailOnlyText -match '^(?i:true)$')
        }

        $mctId = $null
        if ($f.PSObject.Properties.Name -contains 'id')
        {
            $mctId = [string]$f.id
        }

        $clientType = $null
        $m = [regex]::Match($filePath, $clientTypeRegex)
        if ($m.Success)
        {
            $clientType = $m.Value
        }

        $build = $null
        $buildMajor = $null
        $buildMatch = [regex]::Match($fileName, '(\d{5})\.(\d+)')
        if ($buildMatch.Success)
        {
            $build = $buildMatch.Value
            [int]$tmpMajor = 0
            if ([int]::TryParse($buildMatch.Groups[1].Value, [ref]$tmpMajor))
            {
                $buildMajor = $tmpMajor
            }
        }

        $windowsRelease = $null
        if ($buildMajor)
        {
            $windowsRelease = if ($buildMajor -ge 22000) { 11 } else { 10 }
        }

        $out = [ordered]@{
            sourceFwlinkId = $SourceFwlinkId
            mctId          = $mctId
            clientType     = $clientType
            windowsRelease = $windowsRelease
            build          = $build
            buildMajor     = $buildMajor
            architecture   = $architecture
            languageCode   = $languageCode
            language       = $language
            edition        = $edition
            fileName       = $fileName
            sizeBytes      = $sizeBytes
            sha1           = $sha1
            isRetailOnly   = $isRetailOnly
        }

        if ($IncludeUrl)
        {
            $out.url = $filePath
        }

        if ($IncludeKey)
        {
            $key = $null
            if ($f.PSObject.Properties.Name -contains 'Key')
            {
                $key = [string]$f.Key
            }
            $out.key = $key
        }

        [PSCustomObject]$out
    }

    # Deterministic ordering.
    $items | Sort-Object -Property @(
        @{ Expression = { $_.sha1 } },
        @{ Expression = { $_.url } },
        @{ Expression = { $_.fileName } },
        @{ Expression = { $_.languageCode } },
        @{ Expression = { $_.architecture } },
        @{ Expression = { $_.edition } }
    )
}
