# Default manifest: what install.ps1 sets up.
# To change anything without editing this file, create a personal manifest with only the values you
# want to change, at ~/.config/devenv/manifest.psd1 (or pass -Manifest <path>, or set $env:DEVENV_MANIFEST).
# Sections merge key by key, so you can change a single color; lists (like Extensions) replace the default list.
@{
    # Apps installed with winget (IDs from: winget search <name>). bootstrap.ps1 installs PowerShell 7 and
    # Git itself to clone the repo; the rest are installed by install.ps1. Uninstall leaves apps installed.
    Packages = @(
        'Microsoft.PowerShell'
        'Git.Git'
        'Microsoft.WindowsTerminal'
        'GitHub.cli'
        'Microsoft.VisualStudioCode'
        'Microsoft.PowerToys'
        'Microsoft.AzureCLI'
        'Anthropic.Claude'
        'Anthropic.ClaudeCode'
    )

    # Global git config (git config --global <key> <value>). Put your identity in your personal manifest:
    #   Git = @{ 'user.name' = 'Your Name'; 'user.email' = 'you@example.com' }
    Git      = @{
        'init.defaultBranch' = 'main'
    }

    # WSL: adds a line loading bash/dualline-prompt.sh to ~/.bashrc. Distro is the WSL distribution to set
    # up; leave it empty for the default one.
    Wsl      = @{
        Distro = ''
    }

    # The dual line prompt, for both PowerShell and bash (Sync-DevEnv generates each shell's config from this)
    Prompt   = @{
        Palette             = @{
            # Section backgrounds, left to right
            section0  = '#061621'
            section1  = '#0B293D'
            section2  = '#22577A'
            section3  = '#38A3A5'
            section4  = '#57CC99'
            section5  = '#80ED99'
            # Text on dark and light sections
            textlight = '#80ED99'
            textdark  = '#000000'
            # The lines joining the two prompt lines, the chevron, and the chevron after a failed command
            frame     = '#22577A'
            chevron   = '#80ED99'
            error     = '#E74856'
        }
        # Segments, left to right. Each is drawn on the next section color (the first on section0, and so on),
        # so the palette needs a section for each. Available: os (plus the user when elevated or over SSH),
        # path, git, docker, time, and gap (an empty section).
        Segments            = @('os', 'path', 'git', 'docker', 'gap', 'time')
        # Segments in the VS Code integrated terminal; leave out to use Segments there too
        VSCodeSegments      = @('os', 'path', 'git', 'gap', 'docker', 'time')
        # How many folders of the path to show
        DirTruncationLength = 3
        # .NET format, converted for bash. Supports H, HH, h, hh, m, mm, s, ss and tt.
        TimeFormat          = 'HH:mm'
    }

    Font     = @{
        # Name of the release zip at https://github.com/ryanoasis/nerd-fonts/releases, without .zip
        Name = 'IosevkaTerm'
        # Font family name, used by Windows Terminal and VS Code
        Face = 'IosevkaTerm Nerd Font'
    }

    Terminal = @{
        # Added to Windows Terminal and made the default for all profiles
        ColorScheme = @{
            name                = 'Custom'
            background          = '#000000'
            foreground          = '#A5FFB8'
            cursorColor         = '#80ED99'
            selectionBackground = '#80ED99'
            black               = '#0C0C0C'
            red                 = '#AB2022'
            green               = '#01663E'
            yellow              = '#A8A431'
            blue                = '#183E57'
            purple              = '#9853A8'
            cyan                = '#1B6E6C'
            white               = '#CCCCCC'
            brightBlack         = '#767676'
            brightRed           = '#E74856'
            brightGreen         = '#05FF9C'
            brightYellow        = '#FFF730'
            brightBlue          = '#4497F0'
            brightPurple        = '#E77EFF'
            brightCyan          = '#40FFFB'
            brightWhite         = '#F2F2F2'
        }
    }

    VSCode   = @{
        # Merged into VS Code's user settings; any other settings you have are left alone.
        # editor.fontFamily and terminal.integrated.fontFamily are set from Font.Face unless given here.
        Settings   = @{
            'workbench.colorTheme'                         = 'Dualline Dark'
            'editor.fontWeight'                            = 'normal'
            'editor.fontLigatures'                         = $false
            'window.zoomLevel'                             = 1
            'terminal.integrated.fontSize'                 = 16
            'terminal.integrated.fontWeight'               = 'bold'
            'terminal.integrated.fontWeightBold'           = 'bold'
            # These two keep VS Code from adjusting the prompt colors, so they match Windows Terminal
            'terminal.integrated.minimumContrastRatio'     = 1
            'terminal.integrated.drawBoldTextInBrightColors' = $false
        }

        # Extension IDs; get your current list with: code --list-extensions
        Extensions = @(
            'angular.ng-template'
            'anthropic.claude-code'
            'github.vscode-github-actions'
            'ms-azuretools.vscode-azure-github-copilot'
            'ms-azuretools.vscode-azure-mcp-server'
            'ms-azuretools.vscode-azureresourcegroups'
            'ms-azuretools.vscode-containers'
            'ms-azuretools.vscode-docker'
            'ms-dotnettools.csdevkit'
            'ms-dotnettools.csharp'
            'ms-dotnettools.vscode-dotnet-runtime'
            'ms-kubernetes-tools.vscode-kubernetes-tools'
            'ms-vscode-remote.remote-containers'
            'ms-vscode-remote.remote-wsl'
            'ms-vscode.powershell'
            'redhat.vscode-yaml'
        )
    }
}
