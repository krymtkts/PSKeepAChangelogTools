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

    $script:KeepAChangelogNewLine
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

function Assert-KeepAChangelogManifestReleaseNotesValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.Language.ScriptBlockAst] $ManifestAst,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $ReleaseNotes,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    $rootHashtable = $ManifestAst.Find(
        { param($ast) $ast -is [System.Management.Automation.Language.HashtableAst] },
        $false
    )
    $pathResolution = if ($rootHashtable -is [System.Management.Automation.Language.HashtableAst]) {
        Resolve-KeepAChangelogManifestReleaseNotesPath -HashtableAst $rootHashtable
    }
    if ($null -eq $pathResolution -or $null -eq $pathResolution.ValueAst) {
        throw "Could not validate PrivateData.PSData.ReleaseNotes in updated manifest: $Path"
    }

    try {
        $validatedReleaseNotes = $pathResolution.ValueAst.SafeGetValue()
    }
    catch {
        throw "Could not evaluate PrivateData.PSData.ReleaseNotes in updated manifest: $Path. $($_.Exception.Message)"
    }
    if ($validatedReleaseNotes -isnot [string] -or $validatedReleaseNotes -cne $ReleaseNotes) {
        throw "Updated manifest ReleaseNotes did not match the requested value: $Path"
    }
}

function Resolve-KeepAChangelogManifestReleaseNotesPath {
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.Language.HashtableAst] $HashtableAst,

        [int] $Depth = 0
    )

    $path = @('PrivateData', 'PSData', 'ReleaseNotes')
    foreach ($pair in $HashtableAst.KeyValuePairs) {
        if (
            $pair.Item1 -is [System.Management.Automation.Language.StringConstantExpressionAst] -and
            $pair.Item1.Value -eq $path[$Depth] -and
            $pair.Item2.PipelineElements.Count -eq 1 -and
            $pair.Item2.PipelineElements[0] -is [System.Management.Automation.Language.CommandExpressionAst]
        ) {
            $valueAst = $pair.Item2.PipelineElements[0].Expression
            if ($Depth -eq 2) {
                return [pscustomobject]@{
                    HashtableAst = $HashtableAst
                    ValueAst = $valueAst
                    MissingDepth = 0
                }
            }
            if ($valueAst -isnot [System.Management.Automation.Language.HashtableAst]) {
                return $null
            }

            return Resolve-KeepAChangelogManifestReleaseNotesPath `
                -HashtableAst $valueAst `
                -Depth ($Depth + 1)
        }
    }

    [pscustomobject]@{
        HashtableAst = $HashtableAst
        ValueAst = $null
        MissingDepth = 3 - $Depth
    }
}

function Get-KeepAChangelogManifestReleaseNotesTarget {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Content
    )

    $tokens = $null
    $parseErrors = $null
    $manifestAst = [System.Management.Automation.Language.Parser]::ParseInput(
        $Content,
        [ref] $tokens,
        [ref] $parseErrors
    )
    if ($parseErrors.Count -gt 0) {
        throw "Manifest contains syntax errors: $($parseErrors[0].Message)"
    }
    $rootHashtable = $manifestAst.Find(
        { param($ast) $ast -is [System.Management.Automation.Language.HashtableAst] },
        $false
    )
    if ($rootHashtable -isnot [System.Management.Automation.Language.HashtableAst]) {
        return $null
    }

    $pathResolution = Resolve-KeepAChangelogManifestReleaseNotesPath -HashtableAst $rootHashtable
    if ($null -eq $pathResolution) {
        return $null
    }

    $target = $pathResolution.ValueAst
    if ($null -eq $target -and $pathResolution.MissingDepth -eq 1) {
        $releaseNotesComments = @($tokens | Where-Object {
                $_.Kind -eq [System.Management.Automation.Language.TokenKind]::Comment -and
                $_.Extent.StartOffset -ge $pathResolution.HashtableAst.Extent.StartOffset -and
                $_.Extent.EndOffset -le $pathResolution.HashtableAst.Extent.EndOffset -and
                $_.Text -match '^#\s*ReleaseNotes\s*='
            })
        if ($releaseNotesComments.Count -gt 1) {
            return $null
        }
        if ($releaseNotesComments.Count -eq 1) {
            $target = $releaseNotesComments[0]
        }
    }

    $missingDepth = if ($null -ne $target) { 0 } else { $pathResolution.MissingDepth }
    [pscustomobject]@{
        HashtableAst = $pathResolution.HashtableAst
        MissingDepth = $missingDepth
        Target = $target
    }
}

function Get-KeepAChangelogIndentAtOffset {
    param(
        [Parameter(Mandatory)]
        [string] $Content,

        [Parameter(Mandatory)]
        [int] $Offset
    )

    $lineStart = $Content.LastIndexOf("`n", [Math]::Max(0, $Offset - 1)) + 1
    $linePrefix = $Content.Substring($lineStart, $Offset - $lineStart)
    [regex]::Match($linePrefix, '^[ \t]*').Value
}

function New-KeepAChangelogMissingReleaseNotesContent {
    param(
        [Parameter(Mandatory)]
        [int] $MissingDepth,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $ReleaseNotes,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $HashtableIndent,

        [Parameter(Mandatory)]
        [string] $IndentUnit,

        [Parameter(Mandatory)]
        [string] $NewLine
    )

    $valueIndent = $HashtableIndent + $IndentUnit
    for ($depth = 1; $depth -lt $MissingDepth; $depth++) {
        $valueIndent += $IndentUnit
    }
    $content = @("${valueIndent}ReleaseNotes = @'", $ReleaseNotes, "'@") -join $NewLine

    if ($MissingDepth -ge 2) {
        $valueIndent = $valueIndent.Substring(0, $valueIndent.Length - $IndentUnit.Length)
        $content = @("${valueIndent}PSData = @{", $content, "$valueIndent}") -join $NewLine
    }
    if ($MissingDepth -eq 3) {
        $valueIndent = $valueIndent.Substring(0, $valueIndent.Length - $IndentUnit.Length)
        $content = @("${valueIndent}PrivateData = @{", $content, "$valueIndent}") -join $NewLine
    }

    $content
}

function Get-KeepAChangelogManifestReleaseNotesEdit {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Content,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $ReleaseNotes,

        [Parameter(Mandatory)]
        [string] $NewLine
    )

    $targetInfo = Get-KeepAChangelogManifestReleaseNotesTarget -Content $Content
    if ($null -eq $targetInfo) {
        return $null
    }
    if ($null -ne $targetInfo.Target) {
        $replacementStart = if ($targetInfo.Target -is [System.Management.Automation.Language.Token]) {
            "ReleaseNotes = @'"
        }
        else {
            "@'"
        }
        return [pscustomobject]@{
            StartOffset = $targetInfo.Target.Extent.StartOffset
            EndOffset = $targetInfo.Target.Extent.EndOffset
            Replacement = @($replacementStart, $ReleaseNotes, "'@") -join $NewLine
        }
    }

    $hashtableAst = $targetInfo.HashtableAst
    $hashtableIndent = Get-KeepAChangelogIndentAtOffset -Content $Content -Offset $hashtableAst.Extent.StartOffset
    $indentUnit = '    '
    if ($hashtableAst.KeyValuePairs.Count -gt 0) {
        $firstKeyIndent = Get-KeepAChangelogIndentAtOffset `
            -Content $Content `
            -Offset $hashtableAst.KeyValuePairs[0].Item1.Extent.StartOffset
        if ($firstKeyIndent.StartsWith($hashtableIndent) -and $firstKeyIndent.Length -gt $hashtableIndent.Length) {
            $indentUnit = $firstKeyIndent.Substring($hashtableIndent.Length)
        }
    }
    $pathContent = New-KeepAChangelogMissingReleaseNotesContent `
        -MissingDepth $targetInfo.MissingDepth `
        -ReleaseNotes $ReleaseNotes `
        -HashtableIndent $hashtableIndent `
        -IndentUnit $indentUnit `
        -NewLine $NewLine

    $closingBraceOffset = $hashtableAst.Extent.EndOffset - 1
    $closingLineStart = $Content.LastIndexOf("`n", [Math]::Max(0, $closingBraceOffset - 1)) + 1
    $closingLinePrefix = $Content.Substring($closingLineStart, $closingBraceOffset - $closingLineStart)
    if ($closingLineStart -gt $hashtableAst.Extent.StartOffset -and $closingLinePrefix -match '^[ \t]*$') {
        $startOffset = $closingLineStart
        $replacement = $pathContent + $NewLine
    }
    else {
        $startOffset = $closingBraceOffset
        $replacement = $NewLine + $pathContent + $NewLine + $hashtableIndent
    }

    [pscustomobject]@{
        StartOffset = $startOffset
        EndOffset = $startOffset
        Replacement = $replacement
    }
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

    $newLine = $script:KeepAChangelogNewLine
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
    $normalizedReleaseNotes = ($ReleaseNotes -replace "`r?`n", $newLine).TrimEnd("`r", "`n")
    $edit = Get-KeepAChangelogManifestReleaseNotesEdit `
        -Content $content `
        -ReleaseNotes $normalizedReleaseNotes `
        -NewLine $newLine
    if ($null -eq $edit) {
        throw "Could not resolve PrivateData.PSData.ReleaseNotes in manifest: $ManifestPath"
    }

    $updatedContent = $content.Substring(0, $edit.StartOffset) + $edit.Replacement + $content.Substring($edit.EndOffset)
    $parseTokens = $null
    $parseErrors = $null
    $updatedAst = [System.Management.Automation.Language.Parser]::ParseInput(
        $updatedContent,
        [ref] $parseTokens,
        [ref] $parseErrors
    )
    if ($parseErrors.Count -gt 0) {
        throw "Could not create a valid manifest from ReleaseNotes: $ManifestPath. $($parseErrors[0].Message)"
    }
    Assert-KeepAChangelogManifestReleaseNotesValue `
        -ManifestAst $updatedAst `
        -ReleaseNotes $normalizedReleaseNotes `
        -Path $ManifestPath

    if ($PSCmdlet.ShouldProcess($ManifestPath, 'Update manifest ReleaseNotes')) {
        Write-KeepAChangelogManifestFile `
            -Path $ManifestPath `
            -Content $updatedContent `
            -Encoding $manifestFile.Encoding `
            -ByteOrderMark $manifestFile.ByteOrderMark
    }
}
