---
document type: cmdlet
external help file: PSKeepAChangelogTools-Help.xml
HelpUri: https://github.com/krymtkts/PSKeepAChangelogTools/blob/main/docs/PSKeepAChangelogTools/Get-KeepAChangelogManifestReleaseNotes.md
Locale: en-US
Module Name: PSKeepAChangelogTools
ms.date: 08-13-2026
PlatyPS schema version: 2024-05-01
title: Get-KeepAChangelogManifestReleaseNotes
---

# Get-KeepAChangelogManifestReleaseNotes

## SYNOPSIS

Create module manifest release notes from recent changelog sections.

## SYNTAX

### __AllParameterSets

```
Get-KeepAChangelogManifestReleaseNotes [[-Path] <string>] [-Version] <string> [[-RecentCount] <int>]
 [-FullChangelogUrl] <string> [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

Reads a Keep a Changelog style file and renders release notes beginning with the specified version.
The output starts with the target section.
It includes up to `RecentCount` consecutive sections in changelog order.

The command appends a `Full CHANGELOG` link using `FullChangelogUrl`.
File-ending footer link definitions are not included.

## EXAMPLES

### Example 1

```powershell
$releaseNotes = Get-KeepAChangelogManifestReleaseNotes `
    -Version '1.2.0' `
    -RecentCount 3 `
    -FullChangelogUrl 'https://github.com/example/project/blob/main/CHANGELOG.md'
```

Create manifest release notes for version `1.2.0` and the next two sections in `CHANGELOG.md`.

## PARAMETERS

### -FullChangelogUrl

The URL appended to the generated release notes as the full changelog link.

```yaml
Type: System.String
DefaultValue: ""
SupportsWildcards: false
Aliases: []
ParameterSets:
  - Name: (All)
    Position: 3
    IsRequired: true
    ValueFromPipeline: false
    ValueFromPipelineByPropertyName: false
    ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ""
```

### -Path

The path to the changelog.
The default is `CHANGELOG.md` in the current directory.

```yaml
Type: System.String
DefaultValue: ""
SupportsWildcards: false
Aliases: []
ParameterSets:
  - Name: (All)
    Position: 0
    IsRequired: false
    ValueFromPipeline: false
    ValueFromPipelineByPropertyName: false
    ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ""
```

### -RecentCount

The number of consecutive changelog sections to include at most.
The default is `3`, and the accepted range is `1` through `20`.

```yaml
Type: System.Int32
DefaultValue: "3"
SupportsWildcards: false
Aliases: []
ParameterSets:
  - Name: (All)
    Position: 2
    IsRequired: false
    ValueFromPipeline: false
    ValueFromPipelineByPropertyName: false
    ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ""
```

### -Version

The first changelog version to include in the generated release notes.

```yaml
Type: System.String
DefaultValue: ""
SupportsWildcards: false
Aliases: []
ParameterSets:
  - Name: (All)
    Position: 1
    IsRequired: true
    ValueFromPipeline: false
    ValueFromPipelineByPropertyName: false
    ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ""
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable.
For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.String

The rendered changelog sections followed by a link to the full changelog.

## NOTES

The output uses LF line endings.
You can pass it directly to `Set-KeepAChangelogManifestReleaseNotes`.

## RELATED LINKS

- [Set-KeepAChangelogManifestReleaseNotes](https://github.com/krymtkts/PSKeepAChangelogTools/blob/main/docs/PSKeepAChangelogTools/Set-KeepAChangelogManifestReleaseNotes.md)
- [PSKeepAChangelogTools module](https://github.com/krymtkts/PSKeepAChangelogTools/blob/main/docs/PSKeepAChangelogTools/PSKeepAChangelogTools.md)
