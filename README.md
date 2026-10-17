# dev-env-customization
This repo contains files for customizing the Windows Terminal (PowerShell, WSL) and VS Code Integrated Terminal with a custom dual line prompt using [Nerd Fonts](https://www.nerdfonts.com/). The prompt is written in plain PowerShell and bash, so no prompt engine needs to be installed. It also contains a custom color scheme for Windows Terminal to go with the custom prompt.

- `powershell/dualline-prompt.ps1` - prompt for PowerShell (Windows Terminal and VS Code)
- `bash/dualline-prompt.sh` - the same prompt for bash (WSL Ubuntu)
- `terminal/custom-color-scheme.json` - Windows Terminal color scheme
- `vscode/` - VS Code appearance settings, the Dualline Dark color theme and extensions, with an install script

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
    - Run the install script to install the Dualline Dark theme, apply the appearance settings (color theme, Nerd Font for the editor and [Integrated Terminal](https://code.visualstudio.com/docs/terminal/appearance#_text-style), font sizes and weights, zoom level, terminal color handling) and install the extensions.
    ```powershell
    & "C:\code\dev-env-customization\vscode\install.ps1"
    ```
    - Settings are merged into your existing `settings.json`, so other settings are left alone. If anything changes, the original is backed up to `settings.json.bak`.
    - Extensions are installed with the `code` command, which needs VS Code on your PATH (the default for the VS Code installer). Extensions already installed are skipped.
    - `minimumContrastRatio` and `drawBoldTextInBrightColors` keep VS Code from adjusting the prompt colors, so they match Windows Terminal.

# VS Code Files
- `vscode/settings.json` - only the appearance settings. Add a setting here if you want it applied by the install script.
- `vscode/extensions.txt` - one extension ID per line. Get your current list with `code --list-extensions`.
- `vscode/theme/` - the Dualline Dark color theme, packaged and installed as a local extension by the install script (no Node or `vsce` needed).

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

To change a color, edit the hex values in `vscode/theme/themes/dualline-dark-color-theme.json` (search for the old value, since each color is used by several rules) and run the install script again. It reinstalls the theme whenever that file changed. If VS Code doesn't pick up the change, run **Developer: Reload Window** from the command palette.

The theme is derived from VS Code's MIT licensed default themes, see `vscode/theme/NOTICE.txt`.

# Prompt Sections
- OS icon, plus the username only when running over SSH, or `Administrator` / `root` in red when running elevated
- Directory truncated to the last 3 folders, starting at the repo folder when inside a git repo
- Git branch and status symbols (`=` conflicted, `$` stashed, `✘` deleted, `»` renamed, `!` modified, `+` staged, `?` untracked, `⇡⇣⇕` ahead/behind)
- Docker context, only in folders containing a Dockerfile or compose file and when the context is not the default
- Time (`HH:mm`)

# Customization
The color palette, directory truncation length and time format are set at the top of each script. Keep the PowerShell and bash scripts in sync if you use both.

The prompt only runs `git` when inside a git repo, and runs it once per prompt, so it stays fast (a few milliseconds outside a repo).
