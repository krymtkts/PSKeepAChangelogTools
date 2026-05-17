Set-StrictMode -Version Latest

function Get-KeepAChangelogManifestReleaseNotes {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Path = (Resolve-KeepAChangelogPath),

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Version,

        [Parameter()]
        [ValidateRange(1, 20)]
        [int] $RecentCount = 3,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $FullChangelogUrl
    )

    $newLine = Get-KeepAChangelogNewLine
    $sections = Read-KeepAChangelogSections -Path $Path
    $startIndex = -1
    for ($index = 0; $index -lt $sections.Count; $index++) {
        if ($sections[$index].Version -eq $Version) {
            $startIndex = $index
            break
        }
    }

    if ($startIndex -lt 0) {
        throw "Changelog entry not found for version: $Version"
    }

    $selectedSections = $sections | Select-Object -Skip $startIndex -First $RecentCount
    $sectionTexts = foreach ($section in $selectedSections) {
        @(
            $section.Heading
            ''
            $section.Body
        ) -join $newLine
    }

    (@(
        ($sectionTexts -join ($newLine + $newLine))
        ''
        "Full CHANGELOG: $FullChangelogUrl"
    ) -join $newLine).TrimEnd("`r", "`n")
}

function Set-KeepAChangelogManifestReleaseNotes {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ManifestPath,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $ReleaseNotes
    )

    $newLine = Get-KeepAChangelogNewLine
    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
        throw "Manifest not found: $ManifestPath"
    }

    $content = Get-Content -LiteralPath $ManifestPath -Raw
    $pattern = '(?ms)^(?<Indent>\s*)# ReleaseNotes of this module\s*\r?\n.*?(?=^\k<Indent># Prerelease string of this module\s*$)'
    $match = [System.Text.RegularExpressions.Regex]::Match($content, $pattern)
    if (-not $match.Success) {
        throw "Could not find ReleaseNotes section in manifest: $ManifestPath"
    }

    $indent = $match.Groups['Indent'].Value
    $normalizedReleaseNotes = ($ReleaseNotes -replace "`r?`n", $newLine).TrimEnd("`r", "`n")
    $replacement = @(
        "${indent}# ReleaseNotes of this module"
        "${indent}ReleaseNotes = @'"
        $normalizedReleaseNotes
        "'@"
        ''
    ) -join $newLine

    $updatedContent = $content.Substring(0, $match.Index) + $replacement + $content.Substring($match.Index + $match.Length)

    if ($PSCmdlet.ShouldProcess($ManifestPath, 'Update manifest ReleaseNotes')) {
        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText($ManifestPath, $updatedContent, $utf8NoBom)
    }
}
