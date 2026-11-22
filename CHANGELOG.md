# Changelog

Notable changes to this project. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/). The version is `ModuleVersion` in `DevEnv/DevEnv.psd1`, and each release is tagged `v<version>`.

## [Unreleased]

### Added
- Windows Terminal (`Microsoft.WindowsTerminal`) in the manifest's packages, for machines that don't have it built in (Windows 10, Windows Server). It's installed before the `Terminal` component applies its settings.

## [0.5.0] - 2026-11-20

The first tagged release. Everything below is new compared to the earlier, untagged scripts.

### Added
- `DevEnv` PowerShell module with four commands, each taking `-Component` and `-Manifest`:
  - `Install-DevEnv` adds the repo to your user `PSModulePath` so the commands work in every session, then runs `Sync-DevEnv`
  - `Sync-DevEnv` makes the machine match the manifest, with `-WhatIf` support and progress output
  - `Get-DevEnv` shows what matches the manifest and what would change
  - `Uninstall-DevEnv` removes only what DevEnv set (values you changed afterwards are kept)
- Components: `Packages` (winget), `Font`, `Terminal`, `Prompt`, `VSCode`, `Git` and `Wsl`
- `manifests/default.psd1`, with personal manifests merged over it from `-Manifest`, `$env:DEVENV_MANIFEST` or `~/.config/devenv/manifest.psd1`
- Prompt settings in the manifest (palette, segment order, path length, time format), generated into config for both PowerShell and bash so the two prompts always match
- The prompt's chevron turns red after a failed command
- `bootstrap.ps1` parameters `-Path`, `-Manifest`, `-SkipInstall` and `-Ref` (clone a specific tag or branch)
- Pester tests, PSScriptAnalyzer settings, `tests/Invoke-Checks.ps1` and a GitHub Actions workflow that runs them on every pull request
- MIT license, `.editorconfig` and `.gitattributes` (shell scripts always LF, which bash in WSL needs)

### Changed
- `bootstrap.ps1` only installs PowerShell 7 and Git; `install.ps1` installs the rest of the apps from the manifest
- `install.ps1` runs `Install-DevEnv`; the separate `fonts/`, `terminal/`, `powershell/` and `vscode/` install scripts are gone
- The Windows Terminal color scheme, VS Code settings and extension list moved from separate files into the manifest
- In the default segment order, the docker segment uses its own section's color

[Unreleased]: https://github.com/knippel-dev/dev-env-customization/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/knippel-dev/dev-env-customization/releases/tag/v0.5.0
