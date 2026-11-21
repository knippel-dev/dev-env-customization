# dev-env-customization
This repo contains files for customizing the Windows Terminal (PowerShell, WSL) and VS Code Integrated Terminal with a custom dual line prompt using [Nerd Fonts](https://www.nerdfonts.com/). The prompt is written in plain PowerShell and bash, so no prompt engine needs to be installed. It also contains a custom color scheme for Windows Terminal to go with the custom prompt.

- `manifests/default.psd1` - what gets set up: Nerd Font, Windows Terminal color scheme, VS Code settings and extensions (see [Customization](#customization))
- `DevEnv/` - the PowerShell module that sets everything up (see [Commands](#commands))
- `install.ps1` - applies everything by running `Install-DevEnv`, without importing the module first
- `bootstrap.ps1` - sets up a new Windows machine: installs the tools below, clones this repo and runs `install.ps1`
- `powershell/dualline-prompt.ps1` - prompt for PowerShell (Windows Terminal and VS Code)
- `bash/dualline-prompt.sh` - the same prompt for bash (WSL Ubuntu)
- `vscode/theme/` - the Dualline Dark color theme for VS Code

# Quick Start (new Windows machine)
Open the built-in **Windows PowerShell** (no need to install anything first) and run:
```powershell
irm https://raw.githubusercontent.com/knippel-dev/dev-env-customization/main/bootstrap.ps1 | iex
```
This uses `winget` to install anything missing out of:
- [PowerShell 7](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows) (`Microsoft.PowerShell`), which the prompt and the `DevEnv` module need
- [Git](https://git-scm.com/) (`Git.Git`)
- [GitHub CLI](https://cli.github.com/) (`GitHub.cli`)
- [VS Code](https://code.visualstudio.com/) (`Microsoft.VisualStudioCode`)

It then clones this repo to `$HOME\code\dev-env-customization` and runs `install.ps1`, which does setup steps 1, 3, 5 and 6 below. Each of these is a component you can also set up on its own:
- `Font` installs IosevkaTerm Nerd Font for the current user (no admin needed)
- `Terminal` adds the Custom color scheme to Windows Terminal and makes it and the Nerd Font the defaults for all profiles
- `Prompt` adds the prompt to your PowerShell 7 profile, using `-Variant VSCode` automatically in the VS Code terminal
- `VSCode` applies the VS Code settings, theme and extensions

Running it again skips anything already done. Settings files are merged rather than replaced, and the original is backed up to `<file>.bak` whenever one changes. Set `$env:DEVENV_DIR` first to clone somewhere else, `$env:DEVENV_SKIP_INSTALL = '1'` to only install the tools and clone, or `$env:DEVENV_MANIFEST` to use a personal manifest (see [Customization](#customization)). If you already have the repo and PowerShell 7, run `install.ps1` directly.

Afterwards, restart Windows Terminal and VS Code, sign in to GitHub with `gh auth login` and, for WSL, follow step 4 below. The manual steps below are for setting things up by hand; their paths use `C:\code\dev-env-customization`, so change them to wherever the repo was cloned.

# Commands
The `DevEnv` module in the repo has three commands. Each takes `-Component` (`Font`, `Terminal`, `Prompt`, `VSCode`; all of them by default) and `-Manifest`, and returns one row per thing it checked or changed. `Get-Help <command> -Full` has the details.
```powershell
Import-Module "$HOME\code\dev-env-customization\DevEnv"

Get-DevEnvStatus                            # what's set up, and what Install-DevEnv would change
Install-DevEnv -WhatIf                      # preview the changes
Install-DevEnv                              # set everything up
Install-DevEnv -Component Terminal, VSCode  # only some components
Uninstall-DevEnv -WhatIf                    # preview what would be removed
Uninstall-DevEnv                            # remove it (asks to confirm)
```
`install.ps1` takes the same `-Component`, `-Manifest` and `-WhatIf` parameters as `Install-DevEnv`.

`Uninstall-DevEnv` only undoes what `Install-DevEnv` set: the color scheme, and settings that still have the manifest's values (anything you changed afterwards is kept), the profile block that loads the prompt, the Dualline Dark theme and the Nerd Font. Other VS Code extensions are left installed. Close Windows Terminal and VS Code before removing the font, since they keep it in use.

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
    - Source the script from your `~/.bashrc`. Requires bash 4.2 or newer.
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

To change a color, edit the hex values in `vscode/theme/themes/dualline-dark-color-theme.json` (search for the old value, since each color is used by several rules) and run `install.ps1 -Component VSCode` again. It reinstalls the theme whenever a theme file changed. If VS Code doesn't pick up the change, run **Developer: Reload Window** from the command palette.

The theme is derived from VS Code's MIT licensed default themes, see `vscode/theme/NOTICE.txt`.

# Prompt Sections
- OS icon, plus the username only when running over SSH, or `Administrator` / `root` in red when running elevated
- Directory truncated to the last 3 folders, starting at the repo folder when inside a git repo
- Git branch and status symbols (`=` conflicted, `$` stashed, `✘` deleted, `»` renamed, `!` modified, `+` staged, `?` untracked, `⇡⇣⇕` ahead/behind)
- Docker context, only in folders containing a Dockerfile or compose file and when the context is not the default
- Time (`HH:mm`)

# Customization
`manifests/default.psd1` describes what `Install-DevEnv` sets up:
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
The personal manifest is the first one found of: `-Manifest <path>` (on `install.ps1` or any `DevEnv` command), `$env:DEVENV_MANIFEST`, `~/.config/devenv/manifest.psd1`. Then run `install.ps1` again.

The prompt's color palette, directory truncation length and time format are still set at the top of each prompt script. Keep the PowerShell and bash scripts in sync if you use both.

The prompt only runs `git` when inside a git repo, and runs it once per prompt, so it stays fast (a few milliseconds outside a repo).
