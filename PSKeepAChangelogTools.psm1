Set-StrictMode -Version Latest

$filesToLoad = @(
    'src/KeepAChangelog.Core.ps1'
    'src/Private.ManifestReleaseNotes.ps1'
)

foreach ($relativePath in $filesToLoad) {
    $filePath = Join-Path $PSScriptRoot $relativePath
    if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
        throw "Required module source file not found: $filePath"
    }

    . $filePath
}
