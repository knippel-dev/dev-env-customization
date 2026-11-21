# PSScriptAnalyzer settings, used by tests/Invoke-Checks.ps1, CI and the VS Code PowerShell extension.
# Individual exceptions are suppressed in the code with a justification; these apply to the whole repo.
@{
    ExcludeRules = @(
        # Everything except bootstrap.ps1 runs on PowerShell 7, which reads UTF-8 without a BOM.
        # bootstrap.ps1 runs on Windows PowerShell 5.1, so a test checks it stays plain ASCII.
        'PSUseBOMForUnicodeEncodedFile'
    )
}
