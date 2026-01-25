BeforeAll {
    $projectRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..\..\..')).Path

    . (Join-Path -Path $projectRoot -ChildPath 'source\Private\OperatingSystem\ConvertFrom-MCDProductsXml.ps1')
}

Describe 'ConvertFrom-MCDProductsXml' {
    It 'Extracts only .esd entries and preserves deterministic ordering' {
        $fixture = Join-Path -Path $projectRoot -ChildPath 'tests\TestData\products.sample.xml'
        [xml]$x = Get-Content -Path $fixture -Raw

        $items = ConvertFrom-MCDProductsXml -ProductsXml $x -SourceFwlinkId '2156292' -ClientTypes @('CLIENTCONSUMER', 'CLIENTBUSINESS') -IncludeUrl

        $items.Count | Should -Be 2
        ($items.fileName | Sort-Object) | Should -Be @('Win10_22H2_French_x64.esd', 'Win11_23H2_English_x64.esd')
        $items[0].sha1 | Should -Be 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
        $items[0].url | Should -Match 'CLIENTCONSUMER'
        $items[1].url | Should -Match 'CLIENTBUSINESS'
    }
}
