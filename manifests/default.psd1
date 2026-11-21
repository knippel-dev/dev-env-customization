# Default manifest: what install.ps1 sets up.
# To change anything without editing this file, create a personal manifest with only the values you
# want to change, at ~/.config/devenv/manifest.psd1 (or pass -Manifest <path>, or set $env:DEVENV_MANIFEST).
# Sections merge key by key, so you can change a single color; lists (like Extensions) replace the default list.
@{
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
