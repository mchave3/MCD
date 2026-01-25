# MCT ESD Catalog (products.cab / products.xml)

This document explains the technical mechanism used by Microsoft's Media Creation Tool (MCT)
to expose downloadable Windows installation media as ESD files, and how this repository
builds a deterministic, pre-generated catalog from that data.

The goal of the catalog is to be consumed by WinPE tooling (and other automation) without
having to re-discover URLs at runtime.

## Terminology

- MCT: Media Creation Tool.
- ESD: Electronic Software Download. In practice, an ESD is a WIM-family image container
  (often starting with the `MSWIM` magic) hosted on Microsoft's delivery CDN.
- CAB: Microsoft Cabinet archive. MCT downloads a CAB which contains an XML manifest.
- products.xml / products.xml inside a CAB: XML that describes available MCT media files.
- fwlink: Microsoft redirect service `https://go.microsoft.com/fwlink/?LinkId=...`.
- buildMajor: The 5-digit Windows build number (e.g. `19045`, `22631`, `26100`).
- UBR: Update Build Revision. The part after the dot in `19045.3803`.

## High-Level Data Flow

At a high level, the workflow is:

1. Discover which MCT catalog CAB files to use.
2. Download each CAB.
3. Extract `products.xml` (or another XML manifest) from the CAB.
4. Parse the MCT XML and enumerate ESD file entries.
5. Normalize + deduplicate + sort deterministically.
6. Write `WindowsESD.json` and `WindowsESD.xml` into the repo cache.

## Data Sources

### Microsoft fwlinks (latest catalog per Windows major)

These fwlinks are widely used by open source tools and point to the latest MCT catalog CAB:

- Windows 10 latest catalog: `https://go.microsoft.com/fwlink/?LinkId=841361`
- Windows 11 latest catalog: `https://go.microsoft.com/fwlink/?LinkId=2156292`

These are useful for "latest only" scenarios.

In our generated cache, these are exposed at the top-level as `latestFwlinks`.

### WORProject getversions (enumeration of historical catalogs)

Microsoft does not publish an official "list all historical MCT catalog CABs" endpoint.
To build a more complete catalog (including older Windows 10/11 releases), this project
uses the WORProject MCT Catalogs API as a discovery mechanism:

- Endpoint: `https://worproject.com/dldserv/esd/getversions.php`
- Documentation: `https://worproject.com/guides/mct-catalogs-api`

This endpoint returns, for each Windows major version, a set of releases with:

- `build` (e.g. `19045.3803`)
- `date` (e.g. `20250303`)
- `cabLink` (direct URL to the CAB)
- `latestCabLink` (the Microsoft fwlink for the latest)

Important: WORProject is not Microsoft. We only use it to enumerate catalog sources.
When a CAB is hosted on `download.microsoft.com`, the actual catalog data is still
retrieved from Microsoft.

## Release Selection Rules (buildMajor + UBR)

WORProject can return multiple UBRs for the same buildMajor.
Example for Windows 10 `19045`:

- `19045.2006`
- `19045.2965`
- `19045.3803`

For each Windows major (10/11), we group by `buildMajor` and select the release with the
highest UBR. This yields one CAB per buildMajor, which matches the intent:

- Keep a "current" snapshot for each buildMajor.
- Avoid redundant work and duplicated ESD entries.

Implementation details:

- `buildMajor` and `buildUbr` come from parsing the WORProject `build` field.
- If UBR ties (rare), the latest `date` wins.

## CAB Extraction and XML Parsing

MCT catalogs are CABs containing an XML manifest. This project uses `expand.exe`
(available on Windows runners and typical Windows environments) to extract the manifest.

The parser expects the MCT schema shape:

- `MCT.Catalogs.Catalog.PublishedMedia.Files.File`

Each `File` node represents a downloadable media artifact. The most important fields are
usually:

- `FileName`
- `FilePath` (direct URL to the ESD file)
- `Sha1` (may be present / may be empty)
- `Size`
- `Architecture`
- `LanguageCode`
- `Edition`

## Filtering and Normalization

### ESD-only filtering

We only keep entries where `FileName` ends with `.esd`.

### Client type filtering (consumer/business)

Modern catalogs often encode a client category in the URL/filename (examples):

- `CLIENTCONSUMER`
- `CLIENTBUSINESS`

By default, the generator attempts to filter to these categories when present.
However, some older catalogs do not include these markers. To avoid dropping entire
older releases, the filter is "best effort":

- If filtering yields at least one entry, keep the filtered set.
- If filtering yields zero entries, fall back to all ESD entries from that catalog.

### Build extraction from ESD file name

For sorting and selection we parse build info from `FileName` when it matches:

- `(?<major>\d{5})\.(?<ubr>\d+)`

This produces `buildMajor` and `buildUbr` for each item.

## Deduplication and Ordering

### Deduplication

ESD entries can appear multiple times across sources and catalogs.
We deduplicate deterministically:

- Prefer `sha1` as the identity key when present.
- Otherwise use a fallback key based on `url` + `fileName`.

### Ordering (newest first)

To keep the cache easy to scan and stable for diffing, we sort in descending order:

- Windows 11 first, then Windows 10.
- Within a Windows major: higher `buildMajor` first.
- Within a buildMajor: higher `buildUbr` first.

This produces an ordering like:

- Windows 11 `26200.*`
- Windows 11 `26100.*`
- Windows 11 `22631.*`
- ...
- Windows 10 `19045.*`
- Windows 10 `19044.*`
- ...
- Windows 10 `17763.*`

## Cache Outputs

Generated files:

- JSON: `source/Cache/Operating System/WindowsESD.json`
- XML: `source/Cache/Operating System/WindowsESD.xml`

The JSON schema reference is:

- `docs/Schema/WindowsEsdCatalog.schema.json`

The cache has a top-level `latestFwlinks` array which lists the Microsoft fwlinks for the
latest Windows 10 and Windows 11 catalogs. These fwlinks should not be interpreted as
"the fwlink for a specific historical build"; they always point to the current latest.

### Deterministic formatting

Both outputs are written with deterministic formatting to keep diffs reviewable:

- UTF-8 without BOM
- Stable CRLF newlines
- Pretty-printed JSON (no `-Compress`)
- Indented XML
- No timestamps embedded in the catalog

## Implementation in This Repo

Core implementation files:

- Source discovery + generation:
  - `source/Private/OperatingSystem/Update-MCDWindowsEsdCatalogCache.ps1`
- XML parsing + normalization:
  - `source/Private/OperatingSystem/ConvertFrom-MCDProductsXml.ps1`
- Download helper:
  - `source/Private/Core/IO/Invoke-MCDDownload.ps1`

Build task wrapper:

- `.build/UpdateWindowsEsdCatalogCache.build.ps1`

GitHub Actions workflow:

- `.github/workflows/update-windows-esd-catalog.yml`

## How to Regenerate Locally

Use the build task:

```powershell
pwsh -NoProfile -File ./build.ps1 -Tasks Update_WindowsEsdCatalogCache
```

Run tests:

```powershell
pwsh -NoProfile -File ./build.ps1 -Tasks test
```

## Configuration Knobs

The generator supports parameters that can be changed depending on your needs:

- `UseWorProject` (default: true)
  - When true, uses WORProject for source enumeration.
  - When false, uses the two fwlinks only (latest Win10 + latest Win11).
- `WorProjectVersionsUri`
  - Override the getversions endpoint.
- `MinimumBuildMajorWin10` (default: 0)
  - Include older Windows 10 build majors.
- `MinimumBuildMajorWin11` (default: 22000)
  - Keep Windows 11 set reasonably bounded unless you explicitly choose otherwise.
- `ClientTypes` (default: `CLIENTCONSUMER`, `CLIENTBUSINESS`)
  - Used as a best-effort filter.
- `IncludeUrl` (default: true)
  - When true, commits direct ESD download URLs into the catalog.
- `MinimumItemCount`
  - Sanity threshold to detect unexpected schema drift.

## Failure Modes and Troubleshooting

### DNS / "Unknown host" for historical CABs

Some historical CAB links can be hosted on domains that might not resolve from your
environment (or from GitHub runners depending on regional restrictions).
When a CAB download fails, the generator:

- Emits a warning
- Skips that source
- Continues building the rest of the catalog

This is intentional: silently replacing a historical CAB with the latest fwlink CAB
would corrupt the intent of selecting a specific buildMajor.

### Older catalogs missing client markers

Some older MCT catalogs do not contain the `CLIENTCONSUMER/CLIENTBUSINESS` markers.
In that case, client filtering is disabled automatically for that catalog.

## References

- WORProject MCT Catalogs API: `https://worproject.com/guides/mct-catalogs-api`
- FFU example implementation (fwlink -> CAB -> products.xml): `source/Examples/FFU-main/FFUDevelopment/BuildFFUVM.ps1`
