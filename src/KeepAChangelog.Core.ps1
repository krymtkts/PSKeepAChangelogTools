Set-StrictMode -Version Latest

function Resolve-KeepAChangelogPath {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    Join-Path (Get-Location) 'CHANGELOG.md'
}

function Remove-KeepAChangelogFooter {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Content
    )

    $separatorMatches = [System.Text.RegularExpressions.Regex]::Matches($Content, '(?m)^---[ \t]*\r?$')
    if ($separatorMatches.Count -eq 0) {
        return $Content
    }

    $separatorMatch = $separatorMatches[$separatorMatches.Count - 1]
    $footerText = $Content.Substring($separatorMatch.Index + $separatorMatch.Length).TrimStart("`r", "`n")
    $hasLinkDefinition = $false

    foreach ($line in ($footerText -split '\r?\n')) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        if ($line -notmatch '^\[[^\]\r\n]+\]:[ \t]*\S.*$') {
            return $Content
        }

        $hasLinkDefinition = $true
    }

    if ($hasLinkDefinition) {
        $Content.Substring(0, $separatorMatch.Index)
    }
    else {
        $Content
    }
}

function Assert-KeepAChangelogFooterSeparator {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Content
    )

    $lines = $Content -split '\r?\n'
    $hasLinkDefinition = $false

    for ($index = $lines.Count - 1; $index -ge 0; $index--) {
        $line = $lines[$index]
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $linkDefinitionMatch = [System.Text.RegularExpressions.Regex]::Match(
            $line,
            '^\[[^\]\r\n]+\]:[ \t]*\S.*$'
        )
        if (-not $linkDefinitionMatch.Success) {
            if ($line -match '^---[ \t]*$') {
                return
            }

            break
        }

        $hasLinkDefinition = $true
    }

    if ($hasLinkDefinition) {
        throw 'Changelog footer link definitions require a preceding --- separator.'
    }
}

function Get-KeepAChangelogSectionHeaders {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Content
    )

    $linePattern = '(?m)^(?<Text>[^\r\n]*)(?<NewLine>\r?\n|$)'
    $headerPattern = '^## \[(?<Name>[^\]]+)\](?: - .+)?$'
    $fencePattern = '^ {0,3}(?<Marker>`{3,}|~{3,})(?<Tail>.*)$'
    $headers = [System.Collections.Generic.List[object]]::new()
    $versionLines = @{}
    $fenceMarker = $null
    $fenceLength = 0
    $fenceStartLine = 0
    $lineNumber = 0

    foreach ($lineMatch in [System.Text.RegularExpressions.Regex]::Matches($Content, $linePattern)) {
        $lineNumber++
        $line = $lineMatch.Groups['Text'].Value
        $fenceMatch = [System.Text.RegularExpressions.Regex]::Match($line, $fencePattern)

        if ($null -ne $fenceMarker) {
            $marker = $fenceMatch.Groups['Marker'].Value
            $tail = $fenceMatch.Groups['Tail'].Value
            if (
                $fenceMatch.Success -and
                $marker[0] -eq $fenceMarker -and
                $marker.Length -ge $fenceLength -and
                $tail.Trim([char[]] " `t").Length -eq 0
            ) {
                $fenceMarker = $null
            }

            continue
        }

        if ($fenceMatch.Success) {
            $marker = $fenceMatch.Groups['Marker'].Value
            $fenceMarker = $marker[0]
            $fenceLength = $marker.Length
            $fenceStartLine = $lineNumber
            continue
        }

        $headerMatch = [System.Text.RegularExpressions.Regex]::Match($line, $headerPattern)
        if ($headerMatch.Success) {
            $version = $headerMatch.Groups['Name'].Value
            if ($versionLines.ContainsKey($version)) {
                throw "Duplicate changelog version '$version' at lines $($versionLines[$version]) and $lineNumber."
            }
            $versionLines[$version] = $lineNumber

            $headerLength = $line.Length
            if ($lineMatch.Groups['NewLine'].Value.StartsWith("`r")) {
                $headerLength++
            }

            $headers.Add([pscustomobject]@{
                    Index = $lineMatch.Index
                    Length = $headerLength
                    Version = $version
                    Heading = $line
                })
        }
    }

    if ($null -ne $fenceMarker) {
        throw "Unclosed changelog code fence starting at line $fenceStartLine."
    }

    $headers.ToArray()
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

    $rawContent = Get-Content -LiteralPath $Path -Raw
    Assert-KeepAChangelogFooterSeparator -Content $rawContent
    $content = Remove-KeepAChangelogFooter -Content $rawContent
    $headers = @(Get-KeepAChangelogSectionHeaders -Content $content)
    $sections = [System.Collections.Generic.List[object]]::new()

    for ($index = 0; $index -lt $headers.Count; $index++) {
        $header = $headers[$index]
        $bodyStartIndex = $header.Index + $header.Length
        $bodyEndIndex = $content.Length

        if ($index + 1 -lt $headers.Count) {
            $bodyEndIndex = $headers[$index + 1].Index
        }

        $rawBody = $content.Substring($bodyStartIndex, $bodyEndIndex - $bodyStartIndex).TrimStart("`r", "`n")

        $sections.Add([pscustomobject]@{
                Version = $header.Version
                Heading = $header.Heading
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

function Get-KeepAChangelogSection {
    [CmdletBinding(DefaultParameterSetName = 'List')]
    [OutputType([object[]])]
    [OutputType([object])]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Path = (Resolve-KeepAChangelogPath),

        [Parameter(Mandatory, ParameterSetName = 'ByVersion')]
        [ValidateNotNullOrEmpty()]
        [string] $Version
    )

    if ($PSCmdlet.ParameterSetName -eq 'List') {
        Read-KeepAChangelogSections -Path $Path
    }
    else {
        Find-KeepAChangelogSection -Path $Path -Version $Version
    }
}

function Get-KeepAChangelogEntry {
    [CmdletBinding(DefaultParameterSetName = 'ByVersion')]
    [OutputType([string])]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Path = (Resolve-KeepAChangelogPath),

        [Parameter(Mandatory, ParameterSetName = 'ByVersion')]
        [ValidateNotNullOrEmpty()]
        [string] $Version,

        [Parameter(Mandatory, ParameterSetName = 'ByReleaseTag')]
        [ValidateNotNullOrEmpty()]
        [string] $ReleaseTag
    )

    $resolvedVersion = if ($PSCmdlet.ParameterSetName -eq 'ByReleaseTag') {
        ConvertFrom-ReleaseTagToVersion -ReleaseTag $ReleaseTag
    }
    else {
        $Version
    }

    (Find-KeepAChangelogSection -Path $Path -Version $resolvedVersion).Body
}

function Assert-KeepAChangelogReleaseMetadata {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Path = (Resolve-KeepAChangelogPath),

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Version,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ReleaseTag
    )

    Find-KeepAChangelogSection -Path $Path -Version $Version | Out-Null

    if ($PSBoundParameters.ContainsKey('ReleaseTag')) {
        $tagVersion = ConvertFrom-ReleaseTagToVersion -ReleaseTag $ReleaseTag
        if ($tagVersion -ne $Version) {
            throw "Release tag version does not match manifest version. Tag: $tagVersion, Manifest: $Version"
        }
    }
}
