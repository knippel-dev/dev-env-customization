# dev-env-customization
This repo contains files for customizing the Windows Terminal (PowerShell, WSL) and VS Code Integrated Terminal with a custom dual line prompt using [Nerd Fonts](https://www.nerdfonts.com/). The prompt is written in plain PowerShell and bash, so no prompt engine needs to be installed. It also contains a custom color scheme for Windows Terminal to go with the custom prompt.

- `powershell/dualline-prompt.ps1` - prompt for PowerShell (Windows Terminal and VS Code)
- `bash/dualline-prompt.sh` - the same prompt for bash (WSL Ubuntu)
- `terminal/custom-color-scheme.json` - Windows Terminal color scheme

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

6. Configure [VS Code Integrated Terminal](https://code.visualstudio.com/docs/terminal/appearance#_text-style) to use Nerd Font
    - File > Preferences > Settings > Search Settings 'terminal integrated font family' > Add name of installed Nerd Font

# Prompt Sections
- OS icon, plus the username only when running over SSH, or `Administrator` / `root` in red when running elevated
- Directory truncated to the last 3 folders, starting at the repo folder when inside a git repo
- Git branch and status symbols (`=` conflicted, `$` stashed, `✘` deleted, `»` renamed, `!` modified, `+` staged, `?` untracked, `⇡⇣⇕` ahead/behind)
- Docker context, only in folders containing a Dockerfile or compose file and when the context is not the default
- Time (`HH:mm`)

# Customization
The color palette, directory truncation length and time format are set at the top of each script. Keep the PowerShell and bash scripts in sync if you use both.

The prompt only runs `git` when inside a git repo, and runs it once per prompt, so it stays fast (a few milliseconds outside a repo).
