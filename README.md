# dev-env-customization
This repo contains files for customizing the Windows Terminal (PowerShell, WSL) and VS Code Integrated Terminal with a custom dual line prompt using [Nerd Fonts](https://www.nerdfonts.com/). The prompt is written in plain PowerShell and bash, so no prompt engine needs to be installed. It also contains a custom color scheme for Windows Terminal to go with the custom prompt.

- `manifests/default.psd1` - what gets set up: apps, Nerd Font, Windows Terminal color scheme, VS Code settings and extensions, git config (see [Customization](#customization))
- `DevEnv/` - the PowerShell module that sets everything up (see [Commands](#commands))
- `install.ps1` - installs DevEnv from the repo by running `Install-DevEnv`, before its commands are available
- `bootstrap.ps1` - sets up a new Windows machine: installs PowerShell 7 and Git, clones this repo and runs `install.ps1`
- `powershell/dualline-prompt.ps1` - prompt for PowerShell (Windows Terminal and VS Code)
- `bash/dualline-prompt.sh` - the same prompt for bash (WSL Ubuntu)
- `vscode/theme/` - the Dualline Dark color theme for VS Code

# Quick Start (new Windows machine)
Open the built-in **Windows PowerShell** (no need to install anything first) and run:
```powershell
irm https://raw.githubusercontent.com/knippel-dev/dev-env-customization/main/bootstrap.ps1 | iex
```
This uses `winget` to install [PowerShell 7](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows) (which the prompt and the `DevEnv` module need) and [Git](https://git-scm.com/) if they're missing, clones this repo to `$HOME\code\dev-env-customization` and runs `install.ps1`. That makes the `DevEnv` commands available in every PowerShell session (see [Commands](#commands)) and sets up each of these components, which you can also sync on their own:
- `Packages` installs the apps in the manifest with winget: PowerShell 7, Git, GitHub CLI, VS Code, PowerToys, Azure CLI, Claude and Claude Code
- `Font` installs IosevkaTerm Nerd Font for the current user (no admin needed)
- `Terminal` adds the Custom color scheme to Windows Terminal and makes it and the Nerd Font the defaults for all profiles
- `Prompt` adds the prompt to your PowerShell 7 profile, using `-Variant VSCode` automatically in the VS Code terminal
- `VSCode` applies the VS Code settings, theme and extensions
- `Git` applies global git config, like `init.defaultBranch`
- `Wsl` adds the bash prompt to `~/.bashrc` in WSL, if WSL is installed

Running it again skips anything already done. Settings files are merged rather than replaced, and the original is backed up to `<file>.bak` whenever one changes. If you already have the repo and PowerShell 7, run `install.ps1` directly.

To pass options, run the bootstrap as a script block:
```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/knippel-dev/dev-env-customization/main/bootstrap.ps1))) -Manifest ~\my-manifest.psd1
```
- `-Path` - where to clone the repo (default `$HOME\code\dev-env-customization`)
- `-Manifest` - a personal manifest (see [Customization](#customization))
- `-SkipInstall` - only install PowerShell 7 and Git and clone, without running `install.ps1`

These can also be set with `$env:DEVENV_DIR`, `$env:DEVENV_MANIFEST` and `$env:DEVENV_SKIP_INSTALL = '1'` before using the `irm | iex` form.

Afterwards, restart Windows Terminal and VS Code and sign in to GitHub with `gh auth login`. If you install WSL later, run `Sync-DevEnv -Component Wsl`. The manual steps below are for setting things up by hand; their paths use `C:\code\dev-env-customization`, so change them to wherever the repo was cloned.

# Commands
The `DevEnv` module in the repo has four commands. Each takes `-Component` (`Packages`, `Font`, `Terminal`, `Prompt`, `VSCode`, `Git`, `Wsl`; all of them by default) and `-Manifest`, and returns one row per thing it checked or changed. `Get-Help <command> -Full` has the details.

| Command | Does |
|---|---|
| `Install-DevEnv` | Installs DevEnv: adds the repo folder to your user `PSModulePath`, so these commands work in every PowerShell session without `Import-Module`, then runs `Sync-DevEnv`. `install.ps1` runs it. |
| `Sync-DevEnv` | Makes the machine match the manifest. Run it any time, like after changing your manifest or pulling the repo. |
| `Get-DevEnv` | Shows what matches the manifest and what `Sync-DevEnv` would change, without changing anything. |
| `Uninstall-DevEnv` | Removes the customizations and the `PSModulePath` entry (asks to confirm). With `-Component`, removes only those components. |

```powershell
Get-DevEnv                               # what's set up, and what Sync-DevEnv would change
Sync-DevEnv -WhatIf                      # preview the changes
Sync-DevEnv                              # apply the manifest
Sync-DevEnv -Component Terminal, VSCode  # only some components
Uninstall-DevEnv -WhatIf                 # preview what would be removed
Uninstall-DevEnv                         # remove everything
```
`install.ps1` takes the same `-Component`, `-Manifest` and `-WhatIf` parameters as `Install-DevEnv`. Before `Install-DevEnv` has run (or in a terminal opened before it ran), load the commands with `Import-Module "$HOME\code\dev-env-customization\DevEnv"`.

`Uninstall-DevEnv` only undoes what DevEnv set: the color scheme, VS Code and git settings that still have the manifest's values (anything you changed afterwards is kept), the lines that load the prompt in your PowerShell profile and `~/.bashrc`, the Dualline Dark theme and the Nerd Font. Apps, other VS Code extensions and the repo itself are left in place. Close Windows Terminal and VS Code before removing the font, since they keep it in use.

# Setup
This guide is geared towards Windows Terminals using PowerShell Core and WSL Ubuntu Bash.

1. Install a [Nerd Font](https://www.nerdfonts.com/)
    - Nerd Fonts provide the nifty icons which allow you to create custom prompts beyond the basic ASCII.
    - The choice is up to you but the one used in the preview pictures is 'IosevkaTerm Nerd Font'.
    - * Mono fonts may cause the icons to become very small

2. Get a local copy of the customization files
    - You can either clone this repository or download a copy locally. Cloning makes it easy to pick up changes made in the repository.
    - If you are using WSL then this also needs to be done within the distribution if you want the custom prompt to apply there.

3. Configure PowerShell to use the prompt
    - Dot source the script from your PowerShell [Profile](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles?view=powershell-7.3). To have the prompt apply more universally for your user, update the 'Current User, All Hosts' profile.
    ```powershell
    . "C:\code\dev-env-customization\powershell\dualline-prompt.ps1"
    ```
    - For the VS Code Integrated Terminal, add `-Variant VSCode`, which moves the docker section one place to the right.
    ```powershell
    . "C:\code\dev-env-customization\powershell\dualline-prompt.ps1" -Variant VSCode
    ```
    - Open a new terminal, or run `. $PROFILE`, to load it.

4. Configure bash (WSL) to use the prompt
    - `Sync-DevEnv -Component Wsl` does this for you, loading the script from the Windows copy of the repo (through `/mnt/c`).
    - By hand: source the script from your `~/.bashrc`. Requires bash 4.2 or newer.
    ```bash
    source ~/repos/dev-env-customization/bash/dualline-prompt.sh
    ```
    - Open a new terminal, or run `source ~/.bashrc`, to load it.

5. Configure [Windows Terminal](https://learn.microsoft.com/en-us/windows/terminal/tutorials/custom-prompt-setup#install-a-nerd-font) to use Nerd Font
    - Just focus on the Nerd Font section as the rest of the guide goes into using Oh My Posh prompt engine.
    - Windows Terminal > Settings > {defaults | specific profile} > Appearance > Font Face > {Nerd Font you installed}

6. Configure VS Code
    - Run the install script for the `VSCode` component to install the Dualline Dark theme, apply the appearance settings (color theme, Nerd Font for the editor and [Integrated Terminal](https://code.visualstudio.com/docs/terminal/appearance#_text-style), font sizes and weights, zoom level, terminal color handling) and install the extensions.
    ```powershell
    & "C:\code\dev-env-customization\install.ps1" -Component VSCode
    ```
    - The settings and extensions come from the `VSCode` section of the manifest.
    - Settings are merged into your existing `settings.json`, so other settings are left alone. If anything changes, the original is backed up to `settings.json.bak`.
    - Extensions are installed with the `code` command, which needs VS Code on your PATH (the default for the VS Code installer). Extensions already installed are skipped.
    - `minimumContrastRatio` and `drawBoldTextInBrightColors` keep VS Code from adjusting the prompt colors, so they match Windows Terminal.

# VS Code Theme Files
`vscode/theme/` is the Dualline Dark color theme, packaged and installed as a local extension by the install script (no Node or `vsce` needed).

# Dualline Dark Theme
VS Code's Default Dark Modern with the syntax colors swapped for the prompt palette. The window, sidebar and tab colors are unchanged.

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

The theme is derived from VS Code's MIT licensed default themes, see `vscode/theme/NOTICE.txt`.

# Prompt Sections
- OS icon, plus the username only when running over SSH, or `Administrator` / `root` in red when running elevated
- Directory truncated to the last 3 folders, starting at the repo folder when inside a git repo
- Git branch and status symbols (`=` conflicted, `$` stashed, `✘` deleted, `»` renamed, `!` modified, `+` staged, `?` untracked, `⇡⇣⇕` ahead/behind)
- Docker context, only in folders containing a Dockerfile or compose file and when the context is not the default
- Time (`HH:mm`)

# Customization
`manifests/default.psd1` describes what `Sync-DevEnv` sets up:
- `Packages` - winget IDs of the apps to install (find them with `winget search <name>`)
- `Git` - global git config, as `'key' = 'value'`. Put your identity in your personal manifest rather than the default, since the default is shared: `Git = @{ 'user.name' = 'Your Name'; 'user.email' = 'you@example.com' }`
- `Wsl.Distro` - the WSL distribution to add the bash prompt to; empty for the default one
- `Font` - the Nerd Font to install (`Name`, the release zip) and the font family Windows Terminal and VS Code use (`Face`)
- `Terminal.ColorScheme` - the Windows Terminal color scheme
- `VSCode.Settings` and `VSCode.Extensions` - settings merged into VS Code's `settings.json`, and extensions to install

To change any of it without editing the repo, create a personal manifest with only the values you want to change. It is merged over the default: sections merge key by key, and lists (like `Extensions`) replace the default list.
```powershell
# ~/.config/devenv/manifest.psd1
@{
    Font     = @{ Name = 'CascadiaCode'; Face = 'CaskaydiaCove Nerd Font' }
    Terminal = @{ ColorScheme = @{ background = '#101010' } }
}
```
The personal manifest is the first one found of: `-Manifest <path>` (on `install.ps1` or any `DevEnv` command), `$env:DEVENV_MANIFEST`, `~/.config/devenv/manifest.psd1`. Then run `Sync-DevEnv` (or `Get-DevEnv` first, to see what would change).

The prompt's color palette, directory truncation length and time format are still set at the top of each prompt script. Keep the PowerShell and bash scripts in sync if you use both.

The prompt only runs `git` when inside a git repo, and runs it once per prompt, so it stays fast (a few milliseconds outside a repo).
