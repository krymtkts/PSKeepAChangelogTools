---
document type: cmdlet
external help file: PSKeepAChangelogTools-Help.xml
HelpUri: https://github.com/krymtkts/PSKeepAChangelogTools/blob/main/docs/PSKeepAChangelogTools/Get-KeepAChangelogSection.md
Locale: en-US
Module Name: PSKeepAChangelogTools
ms.date: 08-13-2026
PlatyPS schema version: 2024-05-01
title: Get-KeepAChangelogSection
---

# Get-KeepAChangelogSection

## SYNOPSIS

Get changelog sections or a section for a specific version.

## SYNTAX

### List (Default)

```
Get-KeepAChangelogSection [-Path <string>] [<CommonParameters>]
```

### ByVersion

```
Get-KeepAChangelogSection -Version <string> [-Path <string>]
```

## ALIASES

## DESCRIPTION

Reads a Keep a Changelog style file and returns parsed sections in file order.
Each section contains `Version`, `Heading`, and `Body` properties.

When you specify `Version`, the command returns the matching section.
File-ending footer link definitions are not included in any section body.

## EXAMPLES

### Example 1

```powershell
Get-KeepAChangelogSection -Path './CHANGELOG.md'
```

Get every parsed section from the specified changelog.

### Example 2

```powershell
Get-KeepAChangelogSection -Version '1.2.0'
```

Get the section for version `1.2.0` from `CHANGELOG.md` in the current directory.

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

### -Version

The changelog version to return.

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

### System.Object[]

The parsed changelog sections when `Version` is not specified.

### System.Object

A parsed changelog section when you specify `Version`.

## NOTES

The command throws an error when a requested version is not present.

## RELATED LINKS

- [Get-KeepAChangelogEntry](https://github.com/krymtkts/PSKeepAChangelogTools/blob/main/docs/PSKeepAChangelogTools/Get-KeepAChangelogEntry.md)
- [PSKeepAChangelogTools module](https://github.com/krymtkts/PSKeepAChangelogTools/blob/main/docs/PSKeepAChangelogTools/PSKeepAChangelogTools.md)
