BeforeAll {
    $projectRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..\..\..')).Path

    . (Join-Path -Path $projectRoot -ChildPath 'source\Private\Core\IO\Invoke-MCDDownload.ps1')
    . (Join-Path -Path $projectRoot -ChildPath 'source\Private\OperatingSystem\ConvertFrom-MCDProductsXml.ps1')
    . (Join-Path -Path $projectRoot -ChildPath 'source\Private\OperatingSystem\Update-MCDWindowsEsdCatalogCache.ps1')
}

Describe 'Update-MCDWindowsEsdCatalogCache' {
    It 'Writes stable JSON for offline ProductsXmlInputs' {
        $out = Join-Path -Path $env:TEMP -ChildPath ('mcd-esd-cache-test-' + [guid]::NewGuid())
        $null = New-Item -Path $out -ItemType Directory -Force

        try {
            $fixture = Join-Path -Path $projectRoot -ChildPath 'tests\TestData\products.sample.xml'

            Update-MCDWindowsEsdCatalogCache -OutputDirectory $out -ProductsXmlInputs @(
                @{ SourceFwlinkId = '2156292'; Path = $fixture }
            ) -ClientTypes @('CLIENTCONSUMER', 'CLIENTBUSINESS') -IncludeUrl -MinimumItemCount 1

            $jsonPath = Join-Path -Path $out -ChildPath 'WindowsESD.json'
            Test-Path -Path $jsonPath | Should -BeTrue

            $first = Get-Content -Path $jsonPath -Raw
            Update-MCDWindowsEsdCatalogCache -OutputDirectory $out -ProductsXmlInputs @(
                @{ SourceFwlinkId = '2156292'; Path = $fixture }
            ) -ClientTypes @('CLIENTCONSUMER', 'CLIENTBUSINESS') -IncludeUrl -MinimumItemCount 1

            $second = Get-Content -Path $jsonPath -Raw
            $first | Should -Be $second
        }
        finally {
            Remove-Item -Path $out -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
