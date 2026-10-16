
class WslDockerImageDto {
    [string]$Name
    [string]$Path
    [bool]$Uploaded
}

class IsRegistryImageValidResponseDto {
    [bool]$Valid
    [string]$Why
}
