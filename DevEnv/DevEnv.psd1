@{
    RootModule           = 'DevEnv.psm1'
    ModuleVersion        = '0.5.0'
    GUID                 = '0873aa5c-f43d-4dc0-a9d2-315d29a23dab'
    Author               = 'knippel-dev'
    Copyright            = '(c) knippel-dev. MIT License.'
    Description          = 'Sets up a Windows dev environment from a manifest: apps, Nerd Font, Windows Terminal, PowerShell and WSL prompt, VS Code and git config.'
    PowerShellVersion    = '7.2'
    CompatiblePSEditions = @('Core')
    FunctionsToExport    = @('Install-DevEnv', 'Sync-DevEnv', 'Get-DevEnv', 'Uninstall-DevEnv')
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            ProjectUri = 'https://github.com/knippel-dev/dev-env-customization'
            LicenseUri = 'https://github.com/knippel-dev/dev-env-customization/blob/main/LICENSE'
        }
    }
}
