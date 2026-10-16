using module ..\Dtos\InstanceDto.psm1

class LoggerService {
    hidden [string]$_path = ""

    LoggerService([string]$path) {
        $this._path = "$path"
        $directory = Split-Path -Parent $this._path
        if ($directory) {
            try { $null = New-Item -ItemType Directory -Path $directory -Force -ErrorAction Stop } catch { }
        }
        try {
            if ((Test-Path -LiteralPath $this._path) -and (Get-Item -LiteralPath $this._path).Length -gt 1MB) {
                Move-Item -LiteralPath $this._path -Destination "$($this._path).1" -Force -ErrorAction Stop
            }
        } catch { }
        $stamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        $this.Append("==== session $stamp ====")
    }

    [void] Write([LogEntryDto]$entry) {
        $stamp = $entry.When.ToString("yyyy-MM-dd HH:mm:ss")
        $this.Append("$stamp [$($entry.Level)] $($entry.Message)")
    }

    hidden [void] Append([string]$line) {
        if ($this._path) {
            try { Add-Content -LiteralPath $this._path -Value $line -ErrorAction Stop } catch { }
        }
        try { Write-Host $line } catch { }
    }
}
