# Writes text as UTF-8 without a BOM. Windows Terminal and VS Code hold their settings files briefly
# while reloading them, so a locked file is retried a few times before giving up.
function Write-FileWithRetry {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value,
        # Don't add a newline after $Value
        [switch]$NoNewline,
        [int]$Attempts = 5
    )
    for ($attempt = 1; ; $attempt++) {
        try {
            Set-Content -LiteralPath $Path -Value $Value -Encoding utf8NoBOM -NoNewline:$NoNewline -ErrorAction Stop
            return
        }
        catch [IO.IOException] {
            if ($attempt -ge $Attempts) { throw }
            Start-Sleep -Milliseconds 500
        }
    }
}
