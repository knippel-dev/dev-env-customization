# Runs PSScriptAnalyzer and the Pester tests, the same way CI does. Exits with 1 if anything fails.
# Needs Pester 5.5+ and PSScriptAnalyzer:
#   Install-Module Pester, PSScriptAnalyzer -Scope CurrentUser -SkipPublisherCheck
# Run with:  pwsh -File tests/Invoke-Checks.ps1 [-SkipAnalyzer] [-SkipTests]
[CmdletBinding()]
param(
    [switch]$SkipAnalyzer,
    [switch]$SkipTests
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$failed = $false

Push-Location $root
try {
    if (-not $SkipAnalyzer) {
        Import-Module PSScriptAnalyzer
        # The files git tracks or would track (so plan/ and the generated prompt config are skipped), one at a
        # time: running the analyzer on the whole folder with -Recurse can fail inside the analyzer
        $files = git ls-files --cached --others --exclude-standard -- '*.ps1' '*.psm1' '*.psd1' |
            Where-Object { Test-Path -LiteralPath $_ }
        $findings = foreach ($file in $files) {
            Invoke-ScriptAnalyzer -Path $file -Settings (Join-Path $root 'PSScriptAnalyzerSettings.psd1')
        }
        if ($findings) {
            $findings | Format-Table RuleName, Severity, ScriptName, Line, Message -AutoSize -Wrap | Out-Host
            Write-Output "PSScriptAnalyzer: $(@($findings).Count) findings in $(@($files).Count) files"
            $failed = $true
        }
        else { Write-Output "PSScriptAnalyzer: no findings in $(@($files).Count) files" }
    }

    if (-not $SkipTests) {
        Import-Module Pester -MinimumVersion 5.5
        $config = New-PesterConfiguration
        $config.Run.Path = Join-Path $root 'tests'
        $config.Run.PassThru = $true
        $config.Output.Verbosity = 'Detailed'
        $result = Invoke-Pester -Configuration $config
        if ($result.Result -ne 'Passed') { $failed = $true }
    }
}
finally { Pop-Location }

if ($failed) { exit 1 }
