#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env"

log() {
    printf '\n==> %s\n' "$*"
}

warn() {
    printf 'WARNING: %s\n' "$*" >&2
}

if [[ "$(uname -s)" != "Darwin" ]]; then
    printf 'This bootstrap script supports macOS only.\n' >&2
    exit 1
fi

log "Checking Apple Command Line Tools"
if ! xcode-select -p >/dev/null 2>&1; then
    xcode-select --install
    printf 'Complete the Apple installer, then run this script again.\n'
    exit 2
fi

log "Checking Homebrew"
if ! command -v brew >/dev/null 2>&1; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    else
        printf 'Homebrew installed, but brew was not found on PATH.\n' >&2
        exit 1
    fi
fi

install_cask() {
    local cask="$1"
    local existing_path="${2:-}"
    if brew list --cask "${cask}" >/dev/null 2>&1; then
        printf 'Already installed: %s\n' "${cask}"
    elif [[ -n "${existing_path}" && -e "${existing_path}" ]]; then
        printf 'Already installed outside Homebrew: %s\n' "${existing_path}"
    else
        brew install --cask "${cask}"
    fi
}

install_formula() {
    local formula="$1"
    if brew list --formula "${formula}" >/dev/null 2>&1; then
        printf 'Already installed: %s\n' "${formula}"
    else
        brew install "${formula}"
    fi
}

log "Installing host applications"
install_cask docker "/Applications/Docker.app"
install_cask visual-studio-code "/Applications/Visual Studio Code.app"

if command -v conda >/dev/null 2>&1 \
    || [[ -x /opt/homebrew/Caskroom/miniconda/base/bin/conda ]] \
    || [[ -x /usr/local/Caskroom/miniconda/base/bin/conda ]] \
    || [[ -x "${HOME}/miniconda3/bin/conda" ]]; then
    printf 'Already installed: Miniconda\n'
else
    install_cask miniconda
fi

install_formula gh

# Manually installed applications may not have placed their CLIs on PATH yet.
if ! command -v code >/dev/null 2>&1 \
    && [[ -x "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]]; then
    export PATH="/Applications/Visual Studio Code.app/Contents/Resources/app/bin:${PATH}"
fi

if ! command -v docker >/dev/null 2>&1 \
    && [[ -d "/Applications/Docker.app/Contents/Resources/bin" ]]; then
    export PATH="/Applications/Docker.app/Contents/Resources/bin:${PATH}"
fi

log "Creating the local environment file"
if [[ ! -f "${ENV_FILE}" ]]; then
    cp "${PROJECT_ROOT}/.env.example" "${ENV_FILE}"
    printf 'Created %s from .env.example.\n' "${ENV_FILE}"
else
    printf 'Preserving existing %s, including any credentials.\n' "${ENV_FILE}"
fi

set_env_value() {
    local key="$1"
    local value="$2"
    local temporary="${ENV_FILE}.bootstrap"

    awk -v key="${key}" -v value="${value}" '
        BEGIN { found = 0 }
        $0 ~ "^" key "=" { print key "=" value; found = 1; next }
        { print }
        END { if (!found) print key "=" value }
    ' "${ENV_FILE}" > "${temporary}"
    mv "${temporary}" "${ENV_FILE}"
}

set_env_value DEV_UID "$(id -u)"
set_env_value DEV_GID "$(id -g)"

find_conda() {
    if command -v conda >/dev/null 2>&1; then
        command -v conda
        return
    fi

    local brew_prefix
    brew_prefix="$(brew --prefix)"
    local candidate
    for candidate in \
        "${brew_prefix}/Caskroom/miniconda/base/bin/conda" \
        "${HOME}/miniconda3/bin/conda"; do
        if [[ -x "${candidate}" ]]; then
            printf '%s\n' "${candidate}"
            return
        fi
    done

    return 1
}

log "Creating or updating the native macOS Conda environment"
if ! CONDA_BIN="$(find_conda)"; then
    printf 'Miniconda is installed, but the conda executable was not found.\n' >&2
    exit 1
fi

if "${CONDA_BIN}" env list | awk '{print $1}' | grep -Fxq university-dev; then
    "${CONDA_BIN}" env update --name university-dev \
        --file "${PROJECT_ROOT}/environment-macos.yml" --prune
else
    "${CONDA_BIN}" env create --file "${PROJECT_ROOT}/environment-macos.yml"
fi

"${CONDA_BIN}" init "$(basename "${SHELL:-/bin/zsh}")" >/dev/null

log "Configuring VS Code to use the Conda C and C++ compilers"
"${CONDA_BIN}" run --no-capture-output --name university-dev \
    python "${PROJECT_ROOT}/scripts/configure-vscode.py" \
    --workspace "${PROJECT_ROOT}" \
    --conda-exe "${CONDA_BIN}"

log "Installing the Codex CLI"
if command -v codex >/dev/null 2>&1; then
    printf 'Already installed: codex\n'
else
    curl -fsSL https://chatgpt.com/codex/install.sh | sh
    export PATH="${HOME}/.local/bin:${PATH}"
fi

log "Installing recommended VS Code extensions"
if command -v code >/dev/null 2>&1; then
    extensions=(
        ms-python.python
        ms-vscode.cpptools-extension-pack
        ms-vscode.cmake-tools
        ms-vscode-remote.remote-containers
        ms-azuretools.vscode-containers
        openai.chatgpt
    )
    for extension in "${extensions[@]}"; do
        if ! code --install-extension "${extension}" --force; then
            warn "Could not install VS Code extension ${extension}; install it from VS Code."
        fi
    done
else
    warn "The 'code' command is not on PATH; install the recommended extensions from VS Code."
fi

log "Starting Docker Desktop"
if ! docker info >/dev/null 2>&1; then
    open -a Docker
    for _ in {1..60}; do
        if docker info >/dev/null 2>&1; then
            break
        fi
        sleep 2
    done
fi

if ! docker info >/dev/null 2>&1; then
    printf 'Docker Desktop did not become ready. Start it and rerun this script.\n' >&2
    exit 1
fi

log "Validating and building both development images"
docker compose --project-directory "${PROJECT_ROOT}" config --quiet
docker compose --project-directory "${PROJECT_ROOT}" build

log "Bootstrap complete"
printf '%s\n' \
    "1. Review ${ENV_FILE} and set paths, ports, or optional tokens." \
    "2. Restart VS Code so it reloads the generated Conda compiler configuration." \
    "3. Restart your shell, then run: conda activate university-dev" \
    "4. Sign in interactively with: gh auth login" \
    "5. Sign in to Codex with: codex" \
    "6. Start Apache with: docker compose --project-directory ${PROJECT_ROOT} up -d web"
