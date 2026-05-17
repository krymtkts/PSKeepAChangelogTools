Set-StrictMode -Version Latest

function Get-PSKeepAChangelogToolsTestModuleRoot {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    if (-not [string]::IsNullOrWhiteSpace($env:PSKEEPACHANGELOGTOOLS_TEST_MODULE_ROOT)) {
        return $env:PSKEEPACHANGELOGTOOLS_TEST_MODULE_ROOT
    }

    (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}
