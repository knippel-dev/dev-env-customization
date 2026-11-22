# dev-env-customization

[![CI](https://github.com/knippel-dev/dev-env-customization/actions/workflows/ci.yml/badge.svg)](https://github.com/knippel-dev/dev-env-customization/actions/workflows/ci.yml)

Sets up a Windows dev environment from one manifest: apps, a Nerd Font, Windows Terminal colors, a dual line prompt for PowerShell and bash (WSL), VS Code settings, theme and extensions, and git config. It runs as a PowerShell module, `DevEnv`, so you can preview changes, check what's set up, re-sync after changing the manifest, and remove it all again.

The prompt is plain PowerShell and bash, so no prompt engine is needed.

## Quick start (new Windows machine)
Open the built-in **Windows PowerShell** (nothing needs to be installed first) and run:
```powershell
irm https://raw.githubusercontent.com/knippel-dev/dev-env-customization/main/bootstrap.ps1 | iex
```
This installs [PowerShell 7](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows) and [Git](https://git-scm.com/) with `winget` if they're missing, clones this repo to `$HOME\code\dev-env-customization` and runs `install.ps1`. That makes the `DevEnv` commands available in every PowerShell session and sets up all the [components](#components). It's safe to run again: anything already done is skipped.

Afterwards, restart Windows Terminal and VS Code and sign in to GitHub with `gh auth login`.

To pass options, run the bootstrap as a script block:
```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/knippel-dev/dev-env-customization/main/bootstrap.ps1))) -Manifest ~\my-manifest.psd1
```
| Option | Environment variable | Does |
|---|---|---|
| `-Path` | `DEVENV_DIR` | Where to clone the repo (default `$HOME\code\dev-env-customization`) |
| `-Manifest` | `DEVENV_MANIFEST` | A personal manifest (see [Customization](#customization)) |
| `-Ref` | `DEVENV_REF` | A tag or branch to clone, like `v0.5.0` (default `main`) |
| `-SkipInstall` | `DEVENV_SKIP_INSTALL = '1'` | Only install PowerShell 7 and Git and clone, without running `install.ps1` |

The environment variables work with the `irm | iex` form. If you already have the repo and PowerShell 7, run `install.ps1` directly.

## Components
| Component | Sets up |
|---|---|
| `Packages` | Apps from the manifest, with winget: PowerShell 7, Git, Windows Terminal, GitHub CLI, VS Code, PowerToys, Azure CLI, Claude and Claude Code |
| `Font` | IosevkaTerm Nerd Font, for the current user (no admin needed) |
| `Terminal` | The Custom color scheme in Windows Terminal, and it and the Nerd Font as the defaults for all profiles |
| `Prompt` | The [prompt](#prompt)'s config from the manifest, and the prompt in your PowerShell 7 profile (using `-Variant VSCode` in the VS Code terminal) |
| `VSCode` | VS Code settings, the [Dualline Dark theme](#vs-code-theme) and extensions |
| `Git` | Global git config, like `init.defaultBranch` |
| `Wsl` | The bash prompt in `~/.bashrc` in WSL, loaded from the Windows copy of the repo through `/mnt/c` |

Settings files are merged rather than replaced, and the original is backed up to `<file>.bak` whenever one changes.

## Commands
| Command | Does |
|---|---|
| `Install-DevEnv` | Adds the repo folder to your user `PSModulePath`, so these commands work in every PowerShell session without `Import-Module`, then runs `Sync-DevEnv`. `install.ps1` runs it. |
| `Sync-DevEnv` | Makes the machine match the manifest. Run it any time, like after changing your manifest or pulling the repo. |
| `Get-DevEnv` | Shows what matches the manifest and what `Sync-DevEnv` would change, without changing anything. |
| `Uninstall-DevEnv` | Removes the customizations and the `PSModulePath` entry (asks to confirm). With `-Component`, removes only those components. |

Each takes `-Component` (any of the [components](#components); all of them by default) and `-Manifest`, and returns one row per thing it checked or changed. `Get-Help <command> -Full` has the details.
```powershell
Get-DevEnv                               # what's set up, and what Sync-DevEnv would change
Sync-DevEnv -WhatIf                      # preview the changes
Sync-DevEnv                              # apply the manifest
Sync-DevEnv -Component Terminal, VSCode  # only some components
Uninstall-DevEnv -WhatIf                 # preview what would be removed
Uninstall-DevEnv                         # remove everything
```
`install.ps1` takes the same `-Component`, `-Manifest` and `-WhatIf` parameters as `Install-DevEnv`. In a terminal opened before `Install-DevEnv` ran, load the commands with `Import-Module "$HOME\code\dev-env-customization\DevEnv"`.

`Uninstall-DevEnv` only undoes what DevEnv set: the color scheme, VS Code and git settings that still have the manifest's values (anything you changed afterwards is kept), the lines that load the prompt in your PowerShell profile and `~/.bashrc`, the generated prompt config, the Dualline Dark theme and the Nerd Font. Apps, other VS Code extensions and the repo itself are left in place. Close Windows Terminal and VS Code before removing the font, since they keep it in use.

## Customization
`manifests/default.psd1` describes what `Sync-DevEnv` sets up:
- `Packages` - winget IDs of the apps to install (find them with `winget search <name>`)
- `Git` - global git config, as `'key' = 'value'`. Put your identity in your personal manifest rather than the default, since the default is shared: `Git = @{ 'user.name' = 'Your Name'; 'user.email' = 'you@example.com' }`
- `Wsl.Distro` - the WSL distribution to add the bash prompt to; empty for the default one
- `Font` - the Nerd Font to install (`Name`, the release zip) and the font family Windows Terminal and VS Code use (`Face`)
- `Terminal.ColorScheme` - the Windows Terminal color scheme
- `VSCode.Settings` and `VSCode.Extensions` - settings merged into VS Code's `settings.json`, and extensions to install
- `Prompt` - the prompt, for both PowerShell and bash:
  - `Palette` - `section0`, `section1`, ... are the segment backgrounds from left to right; `textlight` / `textdark` the text on them; `frame` the lines joining the two prompt lines; `chevron` and `error` the chevron normally and after a failed command
  - `Segments` - the [segments](#prompt) from left to right. Each is drawn on the next section color, so the palette needs a `section` for each one.
  - `VSCodeSegments` - the segments in the VS Code integrated terminal (by default, docker one section further right)
  - `DirTruncationLength` - how many folders of the path to show
  - `TimeFormat` - a .NET time format such as `HH:mm` or `h:mm tt`, converted for bash

To change any of it without editing the repo, create a personal manifest with only the values you want to change. It's merged over the default: sections merge key by key, and lists (like `Extensions`) replace the default list.
```powershell
# ~/.config/devenv/manifest.psd1
@{
    Git      = @{ 'user.name' = 'Your Name'; 'user.email' = 'you@example.com' }
    Font     = @{ Name = 'CascadiaCode'; Face = 'CaskaydiaCove Nerd Font' }
    Terminal = @{ ColorScheme = @{ background = '#101010' } }
    Prompt   = @{ Palette = @{ section0 = '#1A1A2E' }; TimeFormat = 'h:mm tt' }
}
```
The personal manifest is the first one found of: `-Manifest <path>` (on `install.ps1` or any `DevEnv` command), `$env:DEVENV_MANIFEST`, `~/.config/devenv/manifest.psd1`. Then run `Sync-DevEnv` (or `Get-DevEnv` first, to see what would change). Invalid prompt settings, like an unknown segment or a missing section color, are reported as `Failed` with what's wrong.

## Prompt
Line 1 shows these segments, in the order set by the manifest:
- `os` - OS icon, plus the username only when running over SSH, or `Administrator` / `root` in red when running elevated
- `path` - directory truncated to the last 3 folders, starting at the repo folder when inside a git repo
- `git` - branch and status symbols (`=` conflicted, `$` stashed, `✘` deleted, `»` renamed, `!` modified, `+` staged, `?` untracked, `⇡⇣⇕` ahead/behind)
- `docker` - Docker context, only in folders containing a Dockerfile or compose file and when the context is not the default
- `time` - the time (`HH:mm`)
- `gap` - an empty section, for the color gradient

Line 2 is the chevron you type after. It turns red when the last command failed.

`Sync-DevEnv` generates each shell's config from the manifest (`powershell/dualline-prompt.config.psd1` and `bash/dualline-prompt.config.sh`, not committed), so the two prompts always match; open a new terminal to see changes. The prompt only runs `git` inside a git repo, once per prompt, so it stays fast. To set it up by hand instead, see [docs/manual-setup.md](docs/manual-setup.md).

## VS Code theme
Dualline Dark is VS Code's Default Dark Modern with the syntax colors swapped for the prompt palette. The window, sidebar and tab colors are unchanged. `vscode/theme/` is packaged and installed as a local extension by `Sync-DevEnv` (no Node or `vsce` needed).

| Syntax | Color | Palette |
|---|---|---|
| Plain text, punctuation, operators | `#9CCFE8` | Pale blue |
| Variables, parameters, properties | `#7CB5DC` | Mid blue |
| Keywords and storage (`if`, `public`, `return`) | `#38A3A5` | section3 |
| Functions and methods | `#57CC99` | section4 |
| Strings | `#80ED99` | section5 |
| Types, classes, namespaces | `#5B9BD0` | section2, lightened so it is readable |
| Selection background | `#22577A` | section2 |
| Numbers, constants, enum members | `#C7F9CC` | Mint, the lightest color of the prompt palette family |
| Comments (italic) | `#6A8FA6` | Muted blue-gray |

To change a color, edit the hex values in `vscode/theme/themes/dualline-dark-color-theme.json` (search for the old value, since each color is used by several rules) and run `Sync-DevEnv -Component VSCode`. It reinstalls the theme whenever a theme file changed. If VS Code doesn't pick up the change, run **Developer: Reload Window** from the command palette.

The theme is derived from VS Code's MIT licensed default themes; see `vscode/theme/NOTICE.txt`.

## Repo layout
| Path | Contents |
|---|---|
| `bootstrap.ps1` | Sets up a new machine: installs PowerShell 7 and Git, clones the repo, runs `install.ps1` |
| `install.ps1` | Runs `Install-DevEnv` from the repo, before the commands are available |
| `manifests/default.psd1` | What gets set up |
| `DevEnv/` | The PowerShell module: `Public/` has the commands, `Private/` one file per component plus shared helpers |
| `powershell/`, `bash/` | The prompt scripts |
| `vscode/theme/` | The Dualline Dark color theme |
| `tests/` | Pester tests and `Invoke-Checks.ps1` |
| `docs/` | [Manual setup](docs/manual-setup.md) |

## Development
Run the same checks as CI (PSScriptAnalyzer and the Pester tests) before opening a pull request:
```powershell
Install-Module Pester, PSScriptAnalyzer -Scope CurrentUser -SkipPublisherCheck   # once
./tests/Invoke-Checks.ps1
```
The tests don't change your machine: they work on temporary files, a throwaway registry key and a temporary git config, with winget and WSL mocked (bash runs in Git Bash).

Each change goes through a pull request to `main`, which [CI](.github/workflows/ci.yml) checks. `main` is what `bootstrap.ps1` installs, so it has to keep working. Releases are tagged `v<version>` from the `ModuleVersion` in `DevEnv/DevEnv.psd1`, with notes in [CHANGELOG.md](CHANGELOG.md).

## License
[MIT](LICENSE)
