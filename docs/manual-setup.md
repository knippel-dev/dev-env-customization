# Manual setup

`bootstrap.ps1` and `Sync-DevEnv` do all of this for you (see the [README](../README.md)). These steps are for setting things up by hand, or for picking only some pieces. Paths use `C:\code\dev-env-customization`; change them to wherever the repo is.

1. Install a [Nerd Font](https://www.nerdfonts.com/)
    - Nerd Fonts provide the icons that let the prompt go beyond plain ASCII.
    - The choice is up to you; the default is 'IosevkaTerm Nerd Font'.
    - Mono variants may make the icons very small.

2. Get a local copy of the repo
    - Clone it (so you can pick up changes with `git pull`) or download a copy.
    - For WSL, the prompt can load from the Windows copy through `/mnt/c` (step 4), so a second clone isn't needed.

3. Configure PowerShell to use the prompt
    - Dot source the script from your PowerShell [profile](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles). For the prompt to apply everywhere for your user, use the 'Current User, All Hosts' profile (`$PROFILE.CurrentUserAllHosts`).
    ```powershell
    . "C:\code\dev-env-customization\powershell\dualline-prompt.ps1"
    ```
    - For the VS Code integrated terminal, add `-Variant VSCode`, which uses the manifest's `VSCodeSegments` (by default, the docker segment one section to the right).
    ```powershell
    . "C:\code\dev-env-customization\powershell\dualline-prompt.ps1" -Variant VSCode
    ```
    - Open a new terminal, or run `. $PROFILE`, to load it.
    - Without `Sync-DevEnv`, the prompt uses the settings in `manifests/default.psd1`.

4. Configure bash (WSL) to use the prompt
    - Source the script from your `~/.bashrc`. Needs bash 4.2 or newer.
    ```bash
    source /mnt/c/code/dev-env-customization/bash/dualline-prompt.sh
    ```
    - Open a new terminal, or run `source ~/.bashrc`, to load it.
    - Without `Sync-DevEnv`, bash uses its built-in settings, which match `manifests/default.psd1`.

5. Set the Nerd Font in [Windows Terminal](https://learn.microsoft.com/en-us/windows/terminal/tutorials/custom-prompt-setup#install-a-nerd-font)
    - Only the Nerd Font section of that guide applies; the rest is about the Oh My Posh prompt engine.
    - Windows Terminal > Settings > Defaults (or a specific profile) > Appearance > Font face > the Nerd Font you installed.

6. Configure VS Code
    - `Sync-DevEnv -Component VSCode` installs the Dualline Dark theme, applies the appearance settings (color theme, Nerd Font for the editor and [integrated terminal](https://code.visualstudio.com/docs/terminal/appearance#_text-style), font sizes and weights, zoom level, terminal color handling) and installs the extensions, all from the `VSCode` section of the manifest.
    - Settings are merged into your existing `settings.json`, so other settings are left alone. If anything changes, the original is backed up to `settings.json.bak`.
    - Extensions are installed with the `code` command, which needs VS Code on your PATH (the default for the VS Code installer).
    - `terminal.integrated.minimumContrastRatio` and `terminal.integrated.drawBoldTextInBrightColors` keep VS Code from adjusting the prompt colors, so they match Windows Terminal.
