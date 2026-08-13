---
document type: cmdlet
external help file: PSKeepAChangelogTools-Help.xml
HelpUri: https://github.com/krymtkts/PSKeepAChangelogTools/blob/main/docs/PSKeepAChangelogTools/Get-KeepAChangelogEntry.md
Locale: en-US
Module Name: PSKeepAChangelogTools
ms.date: 08-13-2026
PlatyPS schema version: 2024-05-01
title: Get-KeepAChangelogEntry
---

# Get-KeepAChangelogEntry

## SYNOPSIS

Get the body of a changelog section by version or release tag.

## SYNTAX

### ByVersion (Default)

```
Get-KeepAChangelogEntry -Version <string> [-Path <string>]
```

### ByReleaseTag

```
Get-KeepAChangelogEntry -ReleaseTag <string> [-Path <string>]
```

## ALIASES

## DESCRIPTION

Reads a Keep a Changelog style file and returns the body of one versioned section.
The section heading and file-ending footer link definitions are not included.

Specify either `Version` or `ReleaseTag`.
A release tag can use the form `v<version>` or `refs/tags/v<version>`.

## EXAMPLES

### Example 1

```powershell
Get-KeepAChangelogEntry -Version '1.2.0'
```

Get the body of version `1.2.0` from `CHANGELOG.md` in the current directory.

### Example 2

```powershell
Get-KeepAChangelogEntry -ReleaseTag 'refs/tags/v1.2.0'
```

Get the body of version `1.2.0` from `CHANGELOG.md` in the current directory.

## PARAMETERS

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
    Position: Named
    IsRequired: false
    ValueFromPipeline: false
    ValueFromPipelineByPropertyName: false
    ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ""
```

### -ReleaseTag

The release tag used to select a changelog version.
The accepted forms are `v<version>` and `refs/tags/v<version>`.

```yaml
Type: System.String
DefaultValue: ""
SupportsWildcards: false
Aliases: []
ParameterSets:
  - Name: ByReleaseTag
    Position: Named
    IsRequired: true
    ValueFromPipeline: false
    ValueFromPipelineByPropertyName: false
    ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ""
```

### -Version

The changelog version that identifies the section body to return.

```yaml
Type: System.String
DefaultValue: ""
SupportsWildcards: false
Aliases: []
ParameterSets:
  - Name: ByVersion
    Position: Named
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

The changelog section body without its heading or footer link definitions.

## NOTES

The command throws an error when the requested version is not present.

## RELATED LINKS

- [PSKeepAChangelogTools module](https://github.com/krymtkts/PSKeepAChangelogTools/blob/main/docs/PSKeepAChangelogTools/PSKeepAChangelogTools.md)
