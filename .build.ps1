<#
.Synopsis
    Invoke-Build tasks
#>

# Build script parameters
[CmdletBinding(DefaultParameterSetName = 'Default')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Variables are used in script blocks and argument completers')]
param(
    [Parameter(Position = 0, ParameterSetName = 'Default')]
    [Parameter(Position = 0, ParameterSetName = 'Publish')]
    [ValidateSet('Init', 'Clean', 'Build', 'Lint', 'UnitTest', 'IntegrationTest', 'TestAll', 'ReleaseNotes', 'Stage', 'Import', 'ValidateReleaseMetadata', 'ReleaseTestAll', 'ReleaseTag', 'Release')]
    [string[]] $Tasks = @('UnitTest'),

    [Parameter()]
    [switch] $DisableCoverage,

    [Parameter(ParameterSetName = 'Publish', Mandatory)]
    [switch] $PushToGallery,

    [Parameter(ParameterSetName = 'Publish', Mandatory)]
    [ValidateNotNull()]
    [securestring] $ApiKey,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $ReleaseTag
)

# Required PowerShell version check.
if ($PSVersionTable.PSVersion -lt [Version]'5.1') {
    throw "This build requires PowerShell 5.1+. Current: $($PSVersionTable.PSVersion)."
}

. (Join-Path $PSScriptRoot 'tools/Build.Helpers.ps1')

# If invoked directly (not dot-sourced by Invoke-Build), hand off execution to Invoke-Build through pslrm.
if ($MyInvocation.InvocationName -ne '.') {
    Assert-CommandAvailable -Name 'Invoke-PSLResource'

    $invokeBuildArguments = @(
        $Tasks
        $PSCommandPath
    )
    if ($DisableCoverage) {
        $invokeBuildArguments += '-DisableCoverage'
    }
    if ($PSBoundParameters.ContainsKey('ReleaseTag')) {
        $invokeBuildArguments += '-ReleaseTag'
        $invokeBuildArguments += $ReleaseTag
    }
    if ($PushToGallery) {
        $invokeBuildArguments += '-PushToGallery'
        $invokeBuildArguments += '-ApiKey'
        $invokeBuildArguments += $ApiKey
    }

    try {
        Invoke-PSLResource -Path $PSScriptRoot -CommandName 'Invoke-Build' -ArgumentTokens $invokeBuildArguments
        exit 0
    }
    catch {
        Write-Error $_
        exit 1
    }
}

# --- Setup ---

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ModuleScript = Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.psm1' | Select-Object -First 1
if (-not $ModuleScript) {
    throw "Module script (.psm1) not found under: $PSScriptRoot"
}

$ModuleName = $ModuleScript.BaseName
$ModuleManifest = Get-Item -LiteralPath (Join-Path $PSScriptRoot "$ModuleName.psd1")
$ChangelogPath = Join-Path $PSScriptRoot 'CHANGELOG.md'
$ModuleSourcePath = (Resolve-Path (Join-Path $PSScriptRoot 'src')).Path
$TestsPath = (Resolve-Path (Join-Path $PSScriptRoot 'tests')).Path
$ToolsPath = (Resolve-Path (Join-Path $PSScriptRoot 'tools')).Path
$ModuleVersion = Import-PowerShellDataFile -Path $ModuleManifest.FullName | Get-FullModuleVersion
$ModulePublishPath = Join-Path $PSScriptRoot (Join-Path 'publish' $ModuleName)
$PublishModuleManifest = Join-Path $ModulePublishPath "${ModuleName}.psd1"
$FullChangelogUrl = 'https://github.com/krymtkts/PSKeepAChangelogTools/blob/main/CHANGELOG.md'
$ScriptAnalyzerSettingsPath = Join-Path $PSScriptRoot 'PSScriptAnalyzerSettings.psd1'

# --- Tasks (Invoke-Build) ---

Task Init {
    Write-Host "Module: ${ModuleName} ver${ModuleVersion} root=${ModuleSourcePath} publish=${ModulePublishPath}" -ForegroundColor Magenta
    Write-Host "Parameters: $($PSBoundParameters | ConvertTo-Json -Compress)" -ForegroundColor Green

    'git', 'Invoke-Build', 'Invoke-ScriptAnalyzer', 'Invoke-Pester' | Assert-CommandAvailable

    if (-not (Test-Path -LiteralPath $ScriptAnalyzerSettingsPath -PathType Leaf)) {
        throw "PSScriptAnalyzer settings file not found: $ScriptAnalyzerSettingsPath"
    }

    New-Item -ItemType Directory -Path $ModulePublishPath -Force | Out-Null
}

Task Clean Init, {
    Write-Host 'Cleaning build artifacts.' -ForegroundColor Yellow

    if (Test-Path -LiteralPath $ModulePublishPath -PathType Container) {
        Remove-Item -LiteralPath $ModulePublishPath -Recurse -Force
    }

    @('testResults*.xml', 'coverage*.xml') | ForEach-Object {
        Get-ChildItem -LiteralPath $PSScriptRoot -Filter $_ -File -ErrorAction SilentlyContinue
    } | Remove-Item -Force
}

Task Build Clean, {
    Write-Host 'Building module.' -ForegroundColor Yellow

    Test-ModuleManifest -Path $ModuleManifest.FullName -ErrorAction Stop | Format-List
    if (-not (Test-Path -LiteralPath $ModuleSourcePath -PathType Container)) {
        throw "Module source directory not found: $ModuleSourcePath"
    }
}

Task Lint Build, {
    Write-Host 'Running PSScriptAnalyzer.' -ForegroundColor Yellow

    $issues = @(
        @(
            (Join-Path $PSScriptRoot '.build.ps1'),
            $ToolsPath,
            $ModuleScript.FullName,
            $ModuleSourcePath,
            $TestsPath
        ) | Invoke-ScriptAnalyzer -Recurse -Settings $ScriptAnalyzerSettingsPath
    )
    if ($issues.Count -gt 0) {
        $issues
        throw 'Invoke-ScriptAnalyzer reported issues.'
    }
}

Task UnitTest Lint, {
    Write-Host 'Running unit tests.' -ForegroundColor Yellow

    $parameters = @{
        TestPath = 'tests/unit'
        TestResultOutputPath = 'testResults.xml'
        ModuleName = $ModuleName
    }
    if (-not $DisableCoverage) {
        $parameters.CoverageOutputPath = 'coverage.xml'
    }
    Invoke-TestTask @parameters
}

Task IntegrationTest Stage, {
    Write-Host 'Running integration tests against staged module artifacts.' -ForegroundColor Yellow

    $parameters = @{
        TestPath = 'tests/integration'
        TestResultOutputPath = 'testResults.integration.xml'
        ModuleRoot = $ModulePublishPath
        ModuleName = $ModuleName
    }
    if (-not $DisableCoverage) {
        $parameters.CoverageOutputPath = 'coverage.integration.xml'
    }
    Invoke-TestTask @parameters
}

Task TestAll UnitTest, IntegrationTest

Task ReleaseNotes Import, {
    Write-Host 'Syncing module manifest ReleaseNotes from CHANGELOG.md.' -ForegroundColor Yellow

    $releaseNotes = Get-KeepAChangelogManifestReleaseNotes -Path $ChangelogPath -Version $ModuleVersion -FullChangelogUrl $FullChangelogUrl
    Set-KeepAChangelogManifestReleaseNotes -ManifestPath $ModuleManifest.FullName -ReleaseNotes $releaseNotes
}

Task ValidateReleaseParameters Init, {
    Write-Host 'Validating release parameters.' -ForegroundColor Yellow

    if ([string]::IsNullOrWhiteSpace($ReleaseTag)) {
        throw '-ReleaseTag is required.'
    }
}

Task ReleaseTestAll Import, {
    Write-Host 'Running release tests against staged module artifacts.' -ForegroundColor Yellow

    $parameters = @{
        TestPath = 'tests/unit'
        TestResultOutputPath = 'testResults.release.xml'
        ModuleRoot = $ModulePublishPath
        ModuleName = $ModuleName
    }
    if (-not $DisableCoverage) {
        $parameters.CoverageOutputPath = 'coverage.release.xml'
    }
    Invoke-TestTask @parameters

    $integrationTestParameters = @{
        TestPath = 'tests/integration'
        TestResultOutputPath = 'testResults.integration.release.xml'
        ModuleRoot = $ModulePublishPath
        ModuleName = $ModuleName
    }
    if (-not $DisableCoverage) {
        $integrationTestParameters.CoverageOutputPath = 'coverage.integration.release.xml'
    }
    Invoke-TestTask @integrationTestParameters
}

Task Stage Build, {
    Write-Host "Staging module for release at $PublishModuleManifest." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $ModulePublishPath -Force | Out-Null

    Copy-Item -LiteralPath $ModuleManifest.FullName -Destination $PublishModuleManifest -Force
    Copy-Item -LiteralPath $ModuleScript.FullName -Destination (Join-Path $ModulePublishPath $ModuleScript.Name) -Force
    Copy-Item -LiteralPath $ModuleSourcePath -Destination (Join-Path $ModulePublishPath 'src') -Recurse -Force
}

Task Import Stage, {
    Write-Host "Importing module $PublishModuleManifest" -ForegroundColor Yellow

    Remove-Module -Name $ModuleName -Force -ErrorAction SilentlyContinue
    Import-Module -Name $PublishModuleManifest -Force
    $module = Get-Module -Name $ModuleName
    if (-not $module) {
        throw "Failed to import module: $PublishModuleManifest"
    }
    else {
        $module | Format-List
        Write-Host "Successfully imported module: $($module.Name) version $($module.Version)" -ForegroundColor Green
    }
}

Task ValidateReleaseMetadata ValidateReleaseParameters, Import, {
    Write-Host 'Validating release metadata.' -ForegroundColor Yellow

    Assert-KeepAChangelogReleaseMetadata -Path $ChangelogPath -Version $ModuleVersion -ReleaseTag $ReleaseTag
}

Task ReleaseTag ValidateReleaseMetadata, {
    Write-Host 'Creating a signed release tag from CHANGELOG.md.' -ForegroundColor Yellow

    $run = {
        param(
            [Parameter(Mandatory)]
            [ValidateNotNull()]
            [scriptblock] $Command,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string] $FailureMessage
        )

        $output = @(
            & $Command 2>&1 |
                ForEach-Object { "$_" } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
        if (-not $LASTEXITCODE) {
            return , $output
        }
        if ($output.Count -eq 0) {
            throw $FailureMessage
        }
        throw "$FailureMessage`n$($output -join "`n")"
    }

    $gitReleaseTag = ($ReleaseTag -replace '^refs/tags/', '').Trim()
    $statusOutput = & $run { git status --porcelain=v1 --untracked-files=all } 'Failed to inspect git working tree status.'
    if ($statusOutput.Count -gt 0) {
        throw "Git working tree must be clean before release tagging. Remaining changes: $($statusOutput -join '; ')"
    }

    $existingTag = & $run { git tag --list $gitReleaseTag } "Failed to inspect local release tag '$gitReleaseTag'."
    if ($existingTag.Count -gt 0) {
        throw "Local release tag '$gitReleaseTag' already exists."
    }

    $releaseNotes = Get-KeepAChangelogEntry -Path $ChangelogPath -ReleaseTag $ReleaseTag
    $tagMessage = if ($releaseNotes.EndsWith("`n")) { $releaseNotes } else { "$releaseNotes`n" }
    $null = & $run {
        git tag --sign --cleanup=verbatim $gitReleaseTag --message $tagMessage
    } "Failed to create signed release tag '$gitReleaseTag'."

    Write-Host "Created local signed release tag '$gitReleaseTag'." -ForegroundColor Green
}

Task Release ValidateReleaseMetadata, ReleaseTestAll, {
    Write-Host "Releasing module $ModulePublishPath" -ForegroundColor Magenta

    if ($PushToGallery -and $null -eq $ApiKey) {
        throw '-ApiKey is required when -PushToGallery is specified.'
    }

    if (-not (Test-Path -LiteralPath $PublishModuleManifest -PathType Leaf)) {
        throw "Publish manifest not found. Run Stage before Release: $PublishModuleManifest"
    }

    Write-Host "Release ${ModuleName}! version=${ModuleVersion} dryrun=$(-not $PushToGallery)" -ForegroundColor Magenta

    $module = Import-PowerShellDataFile -Path $PublishModuleManifest
    $manifestModuleVersion = $module | Get-FullModuleVersion
    if ($manifestModuleVersion -ne $ModuleVersion) {
        throw "Version inconsistency between staged manifest and project manifest. Staged: ${manifestModuleVersion}, Project: ${ModuleVersion}"
    }

    Set-PSResourceRepository -Name PSGallery -Trusted -ApiVersion V2

    $parameters = @{
        Path = $ModulePublishPath
        Repository = 'PSGallery'
        WhatIf = -not $PushToGallery
        Verbose = $true
    }
    if ($PushToGallery) {
        $parameters.ApiKey = ConvertFrom-SecureStringToPlainText -SecureString $ApiKey
    }
    Publish-PSResource @parameters
}

Task . UnitTest
