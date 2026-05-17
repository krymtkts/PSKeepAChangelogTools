Set-StrictMode -Version Latest

function Get-ManifestReleaseNotes {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Path = (Get-ChangelogPath),

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
        ) -join $script:PSKeepAChangelogToolsNewLine
    }

    (@(
        ($sectionTexts -join ($script:PSKeepAChangelogToolsNewLine + $script:PSKeepAChangelogToolsNewLine))
        ''
        "Full CHANGELOG: $FullChangelogUrl"
    ) -join $script:PSKeepAChangelogToolsNewLine).TrimEnd("`r", "`n")
}

function Set-ManifestReleaseNotes {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ManifestPath,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $ReleaseNotes
    )

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
    $normalizedReleaseNotes = ($ReleaseNotes -replace "`r?`n", $script:PSKeepAChangelogToolsNewLine).TrimEnd("`r", "`n")
    $replacement = @(
        "${indent}# ReleaseNotes of this module"
        "${indent}ReleaseNotes = @'"
        $normalizedReleaseNotes
        "'@"
        ''
    ) -join $script:PSKeepAChangelogToolsNewLine

    $updatedContent = $content.Substring(0, $match.Index) + $replacement + $content.Substring($match.Index + $match.Length)

    if (-not $PSCmdlet.ShouldProcess($ManifestPath, 'Update manifest ReleaseNotes')) {
        return
    }

    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($ManifestPath, $updatedContent, $utf8NoBom)
}
