# ==============================================================================
# THE LOG — THE SERVICE
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\Dto\InstanceDto.psm1

# The log: one file, one line per entry - when, level, words, all carried by
# the Dto the caller built - and the same line echoed to the terminal the
# window was launched from. The session opens with a dated header. A path
# that cannot be written leaves the echo alone and nothing throws: a log that
# breaks the app is worse than no log.
class LoggerService {
    hidden [string]$_path = ""

    LoggerService([string]$path) {
        $this._path = "$path"
        $directory = Split-Path -Parent $this._path
        if ($directory) {
            try { $null = New-Item -ItemType Directory -Path $directory -Force -ErrorAction Stop } catch { }
        }
        $stamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        $this.Append("==== session $stamp ====")
    }

    # The entry, rendered and written - the file first, the terminal after.
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
