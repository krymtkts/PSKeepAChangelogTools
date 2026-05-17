Set-StrictMode -Version Latest

$script:PSKeepAChangelogToolsRoot = Split-Path -Parent $PSScriptRoot
$script:PSKeepAChangelogToolsNewLine = "`n"

function Resolve-KeepAChangelogPath {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    Join-Path (Get-Location) 'CHANGELOG.md'
}

function Read-KeepAChangelogSections {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Changelog not found: $Path"
    }

    $content = Get-Content -LiteralPath $Path -Raw
    $headerPattern = '(?m)^## \[(?<Name>[^\]]+)\](?<Suffix>(?: - .+)?)\r?$'
    $headerMatches = [System.Text.RegularExpressions.Regex]::Matches($content, $headerPattern)
    $sections = [System.Collections.Generic.List[object]]::new()

    for ($index = 0; $index -lt $headerMatches.Count; $index++) {
        $headerMatch = $headerMatches[$index]
        $bodyStartIndex = $headerMatch.Index + $headerMatch.Length
        $bodyEndIndex = $content.Length

        if ($index + 1 -lt $headerMatches.Count) {
            $bodyEndIndex = $headerMatches[$index + 1].Index
        }

        $rawBody = $content.Substring($bodyStartIndex, $bodyEndIndex - $bodyStartIndex).TrimStart("`r", "`n")
        $footerMatch = [System.Text.RegularExpressions.Regex]::Match($rawBody, '(?m)^---\s*\r?$')
        if ($footerMatch.Success) {
            $rawBody = $rawBody.Substring(0, $footerMatch.Index)
        }

        $sections.Add([pscustomobject]@{
                Version = $headerMatch.Groups['Name'].Value
                Heading = $headerMatch.Value.TrimEnd("`r", "`n")
                Body = $rawBody.TrimEnd("`r", "`n")
            })
    }

    $sections.ToArray()
}

function Find-KeepAChangelogSection {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Version
    )

    $section = Read-KeepAChangelogSections -Path $Path |
        Where-Object { $_.Version -eq $Version } |
        Select-Object -First 1

    if (-not $section) {
        throw "Changelog entry not found for version: $Version"
    }

    $section
}

function Get-KeepAChangelogSections {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Path = (Resolve-KeepAChangelogPath)
    )

    Read-KeepAChangelogSections -Path $Path
}

function Get-KeepAChangelogSection {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Path = (Resolve-KeepAChangelogPath),

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Version
    )

    Find-KeepAChangelogSection -Path $Path -Version $Version
}

function Get-KeepAChangelogEntry {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Path = (Resolve-KeepAChangelogPath),

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Version
    )

    (Find-KeepAChangelogSection -Path $Path -Version $Version).Body
}

function Get-ChangelogSections {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Path = (Get-ChangelogPath)
    )

    Read-KeepAChangelogSections -Path $Path
}

function Get-ChangelogPath {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    Join-Path $script:PSKeepAChangelogToolsRoot 'CHANGELOG.md'
}

function Get-ChangelogSection {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Path = (Get-ChangelogPath),

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Version
    )

    Find-KeepAChangelogSection -Path $Path -Version $Version
}

function Get-ChangelogEntry {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Path = (Get-ChangelogPath),

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Version
    )

    (Find-KeepAChangelogSection -Path $Path -Version $Version).Body
}

function ConvertFrom-ReleaseTagToVersion {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ReleaseTag
    )

    $normalizedTag = $ReleaseTag -replace '^refs/tags/', ''
    $match = [System.Text.RegularExpressions.Regex]::Match($normalizedTag, '^v(?<Version>.+)$')
    if (-not $match.Success) {
        throw "Release tag must use the form v<version>: $ReleaseTag"
    }

    $match.Groups['Version'].Value
}

function Test-KeepAChangelogReleaseMetadata {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Path = (Resolve-KeepAChangelogPath),

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Version,

        [Parameter()]
        [AllowNull()]
        [string] $ReleaseTag
    )

    Find-KeepAChangelogSection -Path $Path -Version $Version | Out-Null

    if ([string]::IsNullOrWhiteSpace($ReleaseTag)) {
        return $true
    }

    $tagVersion = ConvertFrom-ReleaseTagToVersion -ReleaseTag $ReleaseTag
    if ($tagVersion -ne $Version) {
        throw "Release tag version does not match manifest version. Tag: $tagVersion, Manifest: $Version"
    }

    $true
}

function Assert-ReleaseMetadata {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Path = (Get-ChangelogPath),

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Version,

        [Parameter()]
        [AllowNull()]
        [string] $ReleaseTag
    )

    Test-KeepAChangelogReleaseMetadata -Path $Path -Version $Version -ReleaseTag $ReleaseTag | Out-Null
}
