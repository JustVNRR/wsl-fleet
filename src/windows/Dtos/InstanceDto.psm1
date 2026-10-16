using module .\PackCatalogDto.psm1

class WslIndexDto {

    [string]$Name
    [long]$Size
    [bool]$IsArchive
    [string]$Docker
    [string]$Path = ""
    [string]$Archived = ""
}

class WslOrphanDto {

    [string]$Name
    [string]$Path
    [long]$Size
}

class WslBuildSourceDto {

    [string]$Name
    [string]$Path
    [string]$Family
    [bool]$Uploaded
}

class WslBuildPackDto {

    [string]$Name
    [string]$Family
    [string]$Description
    [bool]$Shell
}

class GetBuildSourcesResponseDto {

    [WslBuildSourceDto[]]$Dockerfiles = @()
    [WslBuildSourceDto[]]$Onboardings = @()
    [WslBuildSourceDto[]]$Recipes = @()
}

class NewRecipeDto {

    [string]$Name
}

class UploadRecipeDto {

    [string]$Kind
    [string]$Source
    [string]$FileName
}

class ExportRecipeDto {

    [string]$Path
    [string]$Target
}

class MigrateResponseDto {

    [string[]]$Moved = @()
    [string]$Target
}

class WslIconDto {

    [string]$Text
    [string]$Top
    [string]$Bottom
    [string]$TextColor
}

enum WslBuildType {
    Dockerfile
    Image
    Registry
    Recipe
}

class BuildDto {

    [string]$Name
    [string]$User
    [WslBuildType]$BuildType
    [string]$BuildPath
    [string]$Context
    [string]$Onboarding
    [string]$Font
    [string]$ColourScheme
    [WslIconDto]$Icon
    [string[]]$Packs = @()
    [bool]$KeepImage = $true
    [bool]$RegisterDocker = $false
}

enum WslRecipeStatus {
    Ok
    Warning
    Nok
}

class BuildResponseDto {

    [string]$InstanceName
    [WslRecipeStatus]$Status
    [string[]]$Messages = @()
}

class RemoveDto {

    [string]$InstanceName
    [bool]$ArchiveFirst = $false
}

class CompactDto {

    [string]$InstanceName
    [bool]$ArchiveFirst = $false
}

class CompactResponseDto {

    [string]$InstanceName
    [bool]$Archived
    [bool]$Restarted
    [long]$SizeBefore
    [long]$SizeAfter
    [long]$Gained
}

class GetAppearanceResponseDto {

    [string]$Font
    [string]$ColourScheme
    [WslIconDto]$Icon
    [bool]$HasFragment
    [string]$IconPath
}

class SetAppearanceDto {

    [string]$InstanceName
    [string]$Font
    [string]$ColourScheme
    [WslIconDto]$Icon
    [string]$IconImage
}

class WslIconPairDto {

    [string]$Name
    [string]$Top
    [string]$Bottom
    [string]$TextColor
}

class GetPacksResponseDto {

    [string[]]$Installed = @()
    [WslPackDto[]]$Candidate = @()
    [string[]]$Removable = @()
}

class ManagePacksDto {

    [string]$InstanceName
    [string[]]$ToAdd = @()
    [string[]]$ToRemove = @()
}

class ManagePacksResponseDto {

    [string]$InstanceName
    [string]$Outcome
    [int]$ExitCode
    [string[]]$Installed = @()
    [string[]]$Removed = @()
    [string[]]$Failed = @()
}

class WslColorSchemeDto {

    [string]$Name
    [string]$Background
    [string]$Foreground
    [string]$Black
    [string]$DarkRed
    [string]$DarkGreen
    [string]$DarkYellow
    [string]$DarkBlue
    [string]$DarkMagenta
    [string]$DarkCyan
    [string]$Gray
    [string]$DarkGray
    [string]$Red
    [string]$Green
    [string]$Yellow
    [string]$Blue
    [string]$Magenta
    [string]$Cyan
    [string]$White
}

class ArchiveDto {

    [string]$InstanceName
    [string]$Format
    [bool]$Permit = $false
}

class ArchiveResponseDto {

    [string]$InstanceName
    [string]$ArchiveDir
    [string]$Tar
    [string]$LookFont
    [string]$LookColourScheme
    [string]$Docker
    [bool]$Stopped
}

class RestoreDto {

    [string]$ArchiveName
    [string]$InstanceName
}

class DuplicateDto {

    [string]$SourceName
    [string]$CopyName
}

class DeleteArchiveResponseDto {

    [string]$ArchiveName
}

class RestoreResponseDto {

    [string]$ArchiveName
    [string]$InstanceName
}

class DuplicateResponseDto {

    [string]$SourceName
    [string]$CopyName
}

class RestartResponseDto {

    [string]$InstanceName
}

class OpenResponseDto {

    [string]$InstanceName
    [bool]$Profile
}

class SetAppearanceResponseDto {

    [string]$InstanceName
    [string[]]$Changes = @()
}

class WslConfigResponseDto {

    [string]$Path
    [bool]$Created
}

class RegisterDockerDto {

    [string]$InstanceName
    [bool]$Restart = $true
}

class RegisterDockerResponseDto {

    [string]$InstanceName
    [string]$Restart = ""
}

class UnregisterDockerDto {

    [string]$InstanceName
    [bool]$Restart = $true
}

class UnregisterDockerResponseDto {

    [string]$InstanceName
    [string]$Restart = ""
}

class LogEntryDto {

    [DateTime]$When
    [string]$Level
    [string]$Message
}

