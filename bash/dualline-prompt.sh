# Dual-line prompt in plain bash, the bash counterpart of powershell/dualline-prompt.ps1.
# Load it from ~/.bashrc with:  source ~/repos/dev-env-customization/bash/dualline-prompt.sh
# Needs bash 4.2+ and a Nerd Font in the terminal.
#
# The palette, segments, path length and time format come from the Prompt section of the manifest, through
# dualline-prompt.config.sh next to this script, which Sync-DevEnv generates. The values below are only used
# when it hasn't been generated, and match manifests/default.psd1.

### SETTINGS ###
declare -A _dl_palette=(
    [section0]='#061621'
    [section1]='#0B293D'
    [section2]='#22577A'
    [section3]='#38A3A5'
    [section4]='#57CC99'
    [section5]='#80ED99'
    [textlight]='#80ED99'
    [textdark]='#000000'
    [frame]='#22577A'
    [chevron]='#80ED99'
    [error]='#E74856'
)
_dl_segments=(os path git docker gap time)
# Used in the VS Code integrated terminal
_dl_vscode_segments=(os path git gap docker time)
_dl_dir_truncation_length=3
_dl_dir_truncation_symbol=$'\u2026/'   # …/
_dl_time_format='%H:%M'

# Settings from the manifest, when Sync-DevEnv has generated them
_dl_config=${BASH_SOURCE[0]%/*}/dualline-prompt.config.sh
# shellcheck source=/dev/null
[[ -r $_dl_config ]] && source "$_dl_config"
unset _dl_config
[[ $TERM_PROGRAM == vscode && ${#_dl_vscode_segments[@]} -gt 0 ]] && _dl_segments=("${_dl_vscode_segments[@]}")

### GLYPHS ###
_dl_left_cap=$'\ue0b6'
_dl_arrow=$'\ue0b0'
_dl_right_cap=$'\ue0b4'
_dl_chevron=$'\uf054'
_dl_os_symbol=$'\U000f033d'
_dl_branch=$'\uf418'
_dl_docker=$'\uf308'
_dl_clock=$'\uf4ab'
_dl_top_left=$'\u250c'
_dl_bot_left=$'\u2514'

# Escape sequences are wrapped in \[ \] so bash knows they take up no width.
_dl_esc() { printf '\\[\e[%sm\\]' "$1"; }

_dl_rgb() {
    local hex=${_dl_palette[$1]}
    printf '%d;%d;%d' "0x${hex:1:2}" "0x${hex:3:2}" "0x${hex:5:2}"
}

declare -A _dl_fg _dl_bg
for _dl_name in "${!_dl_palette[@]}"; do
    _dl_fg[$_dl_name]=$(_dl_esc "38;2;$(_dl_rgb "$_dl_name")")
    _dl_bg[$_dl_name]=$(_dl_esc "48;2;$(_dl_rgb "$_dl_name")")
done
unset _dl_name

_dl_reset=$(_dl_esc 0)
_dl_bold=$(_dl_esc 1)
_dl_red=$(_dl_esc 31)
_dl_white=$(_dl_esc 37)

# Walk up from the current directory looking for .git, so we only spawn git inside repos.
_dl_git_root() {
    local dir=$PWD
    while [[ -n $dir ]]; do
        if [[ -e $dir/.git ]]; then _dl_root=$dir; return 0; fi
        dir=${dir%/*}
    done
    [[ -e /.git ]] && { _dl_root=/; return 0; }
    _dl_root=
    return 1
}

_dl_directory() {
    local display truncated=0

    if [[ -n $_dl_root ]]; then
        # Show the path starting at the repo folder.
        local repo_parent=${_dl_root%/*}
        display=${PWD#"$repo_parent"/}
        [[ -n $repo_parent && $repo_parent != "$HOME" ]] && truncated=1
    elif [[ $PWD == "$HOME" || $PWD == "$HOME"/* ]]; then
        display="~${PWD#"$HOME"}"
    else
        display=$PWD
    fi

    local -a parts
    IFS=/ read -ra parts <<< "$display"
    local -a kept=()
    local p
    for p in "${parts[@]}"; do [[ -n $p ]] && kept+=("$p"); done

    if (( ${#kept[@]} > _dl_dir_truncation_length )); then
        kept=("${kept[@]: -_dl_dir_truncation_length}")
        truncated=1
    fi

    local joined
    joined=$(IFS=/; printf '%s' "${kept[*]}")
    [[ $display == /* && $truncated == 0 ]] && joined="/$joined"
    (( truncated )) && joined="$_dl_dir_truncation_symbol$joined"
    _dl_dir=$joined
}

_dl_git() {
    local out
    out=$(git --no-optional-locks status --porcelain=2 --branch 2>/dev/null) || return 1

    local branch='' ahead=0 behind=0
    local conflicted=0 deleted=0 renamed=0 modified=0 staged=0 untracked=0
    local line x y
    while IFS= read -r line; do
        case $line in
            '# branch.head '*)
                branch=${line#'# branch.head '}
                [[ $branch == '(detached)' ]] && branch=HEAD ;;
            '# branch.ab '*)
                [[ $line =~ \+([0-9]+)\ -([0-9]+) ]] && { ahead=${BASH_REMATCH[1]}; behind=${BASH_REMATCH[2]}; } ;;
            'u '*) conflicted=1 ;;
            '? '*) untracked=1 ;;
            [12]' '*)
                x=${line:2:1}; y=${line:3:1}
                [[ ${line:0:1} == 2 ]] && renamed=1
                [[ $x == D || $y == D ]] && deleted=1
                [[ $y == M ]] && modified=1
                [[ $x != . ]] && staged=1 ;;
        esac
    done <<< "$out"

    # Stash check without another git process; falls back to git for worktrees/submodules.
    local stashed=0
    if [[ -d $_dl_root/.git ]]; then
        [[ -e $_dl_root/.git/logs/refs/stash ]] && stashed=1
    else
        git rev-parse --verify --quiet refs/stash >/dev/null 2>&1 && stashed=1
    fi

    # Order and symbols match the status legend in the README.
    local status=''
    (( conflicted ))  && status+='='
    (( stashed ))     && status+='$'
    (( deleted ))     && status+=$'\u2718'   # ✘
    (( renamed ))     && status+=$'\u00bb'   # »
    (( modified ))    && status+='!'
    (( staged ))      && status+='+'
    (( untracked ))   && status+='?'
    if (( ahead > 0 && behind > 0 )); then status+=$'\u21d5'   # ⇕
    elif (( ahead > 0 )); then status+=$'\u21e1'               # ⇡
    elif (( behind > 0 )); then status+=$'\u21e3'              # ⇣
    fi

    # Escape \ so branch names and $ can't be treated as prompt escapes.
    branch=${branch//\\/\\\\}
    status=${status//\\/\\\\}
    _dl_git_branch=${branch//\$/\\\$}
    _dl_git_status=${status//\$/\\\$}
}

# Docker context: only in folders with Docker files, and never for the "default" context.
_dl_docker_context() {
    _dl_docker_ctx=
    local f found=0
    for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml Dockerfile; do
        [[ -e $f ]] && { found=1; break; }
    done
    (( found )) || return 1

    local ctx=${DOCKER_MACHINE_NAME:-${DOCKER_HOST:-$DOCKER_CONTEXT}}
    if [[ -z $ctx ]]; then
        local config="${DOCKER_CONFIG:-$HOME/.docker}/config.json"
        if [[ -r $config ]]; then
            local json
            json=$(<"$config")
            [[ $json =~ \"currentContext\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] && ctx=${BASH_REMATCH[1]}
        fi
    fi
    [[ -n $ctx && $ctx != default ]] && _dl_docker_ctx=$ctx
}

_dl_prompt() {
    local last_exit=$?
    local fg_light=${_dl_fg[textlight]} fg_dark=${_dl_fg[textdark]}
    local ps i bg count=${#_dl_segments[@]}

    _dl_git_root

    # Line 1: each segment sits on the next section color, joined by arrows
    ps="${_dl_fg[frame]}$_dl_top_left"
    for (( i = 0; i < count; i++ )); do
        bg=${_dl_bg[section$i]}
        if (( i == 0 )); then
            ps+="${_dl_fg[section0]}$_dl_left_cap"
            # The cap only sets the foreground, so start the first section's background (os sets its own)
            [[ ${_dl_segments[0]} != os ]] && ps+="$bg"
        else
            ps+="$bg${_dl_fg[section$((i - 1))]}$_dl_arrow"
        fi

        case ${_dl_segments[i]} in
            os)
                ps+="$_dl_bold$bg$_dl_white$_dl_os_symbol  $_dl_reset"
                if (( EUID == 0 )); then
                    ps+="$_dl_bold$bg$_dl_red\\u $_dl_reset"
                elif [[ -n $SSH_CONNECTION || -n $SSH_CLIENT || -n $SSH_TTY ]]; then
                    ps+="$fg_light$bg\\u $_dl_reset"
                fi ;;
            path)
                _dl_directory
                local dir=${_dl_dir//\\/\\\\}
                dir=${dir//\$/\\\$}
                ps+="$_dl_bold$fg_light $dir $_dl_reset" ;;
            git)
                if [[ -n $_dl_root ]] && _dl_git; then
                    ps+="$_dl_bold$fg_dark $_dl_branch $_dl_git_branch "
                    ps+="$_dl_red$_dl_git_status $_dl_reset"
                fi ;;
            docker)
                if _dl_docker_context; then
                    ps+="$_dl_bold$bg$fg_dark $_dl_docker $_dl_docker_ctx $_dl_reset"
                fi ;;
            time)
                local now
                printf -v now "%($_dl_time_format)T" -1
                # Formats this bash's strftime doesn't support (like %-I outside glibc) come out empty
                [[ -z $now ]] && printf -v now '%(%H:%M)T' -1
                ps+="$_dl_bold$fg_dark $_dl_clock $now $_dl_reset" ;;
            # gap is an empty section
        esac
    done
    ps+="${_dl_fg[section$((count - 1))]}$_dl_right_cap$_dl_reset"

    # Line 2: the chevron turns to the error color after a failed command
    local chevron=${_dl_fg[chevron]}
    (( last_exit != 0 )) && chevron=${_dl_fg[error]}
    ps+="\n${_dl_fg[frame]}$_dl_bot_left$_dl_bold$chevron$_dl_chevron $_dl_reset"

    PS1=$ps
    return $last_exit
}

if [[ $PROMPT_COMMAND != *_dl_prompt* ]]; then
    PROMPT_COMMAND="_dl_prompt${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
fi
