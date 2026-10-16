
class WslPackDto {
    [string]$Name
    [string]$Description
    [string]$Family
}

class CreatePackDto {
    [string]$SourceName
    [string]$NewName
    [string]$Description
}

class SetPackDescriptionDto {
    [string]$PackName
    [string]$Description
}
