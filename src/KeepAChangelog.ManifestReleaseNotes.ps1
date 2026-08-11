Set-StrictMode -Version Latest

function Read-KeepAChangelogManifestFile {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $encoding = [System.Text.UTF8Encoding]::new($false, $true)
    $byteOrderMarkLength = 0

    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $encoding = [System.Text.UTF8Encoding]::new($false, $true)
        $byteOrderMarkLength = 3
    }
    elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        $encoding = [System.Text.UnicodeEncoding]::new($false, $false, $true)
        $byteOrderMarkLength = 2
    }
    elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
        $encoding = [System.Text.UnicodeEncoding]::new($true, $false, $true)
        $byteOrderMarkLength = 2
    }

    try {
        $content = $encoding.GetString($bytes, $byteOrderMarkLength, $bytes.Length - $byteOrderMarkLength)
    }
    catch [System.Text.DecoderFallbackException] {
        throw "Could not decode manifest using a supported encoding: $Path"
    }

    [byte[]] $byteOrderMark = [byte[]]::new(0)
    if ($byteOrderMarkLength -gt 0) {
        $byteOrderMark = [byte[]] $bytes[0..($byteOrderMarkLength - 1)]
    }

    [pscustomobject]@{
        Content = $content
        Encoding = $encoding
        ByteOrderMark = $byteOrderMark
    }
}

function Get-KeepAChangelogManifestNewLine {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Content
    )

    $match = [System.Text.RegularExpressions.Regex]::Match($Content, "`r`n|`n|`r")
    if ($match.Success) {
        return $match.Value
    }

    Get-KeepAChangelogNewLine
}

function Write-KeepAChangelogManifestFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Content,

        [Parameter(Mandatory)]
        [System.Text.Encoding] $Encoding,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [byte[]] $ByteOrderMark
    )

    $contentBytes = $Encoding.GetBytes($Content)
    $fileBytes = [byte[]]::new($ByteOrderMark.Length + $contentBytes.Length)
    if ($ByteOrderMark.Length -gt 0) {
        [System.Buffer]::BlockCopy($ByteOrderMark, 0, $fileBytes, 0, $ByteOrderMark.Length)
    }
    [System.Buffer]::BlockCopy($contentBytes, 0, $fileBytes, $ByteOrderMark.Length, $contentBytes.Length)
    [System.IO.File]::WriteAllBytes($Path, $fileBytes)
}

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

    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
        throw "Manifest not found: $ManifestPath"
    }

    $manifestFile = Read-KeepAChangelogManifestFile -Path $ManifestPath
    $content = $manifestFile.Content
    $newLine = Get-KeepAChangelogManifestNewLine -Content $content
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
        Write-KeepAChangelogManifestFile -Path $ManifestPath -Content $updatedContent -Encoding $manifestFile.Encoding -ByteOrderMark $manifestFile.ByteOrderMark
    }
}
