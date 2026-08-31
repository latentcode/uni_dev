#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failed=0

check_command() {
    local command_name="$1"
    if command -v "${command_name}" >/dev/null 2>&1; then
        printf 'PASS  %-12s %s\n' "${command_name}" "$(command -v "${command_name}")"
    else
        printf 'FAIL  %-12s not found\n' "${command_name}"
        failed=1
    fi
}

for command_name in git docker code conda codex; do
    check_command "${command_name}"
done

if [[ -f "${PROJECT_ROOT}/.env" ]]; then
    printf 'PASS  .env         present and ignored by Git\n'
else
    printf 'FAIL  .env         missing; run scripts/bootstrap-macos.sh\n'
    failed=1
fi

if docker info >/dev/null 2>&1; then
    printf 'PASS  Docker       daemon is ready\n'
    if docker compose --project-directory "${PROJECT_ROOT}" config --quiet; then
        printf 'PASS  Compose      configuration is valid\n'
    else
        printf 'FAIL  Compose      configuration is invalid\n'
        failed=1
    fi
else
    printf 'FAIL  Docker       daemon is not ready\n'
    failed=1
fi

if conda env list 2>/dev/null | awk '{print $1}' | grep -Fxq university-dev; then
    printf 'PASS  Conda        university-dev environment exists\n'
else
    printf 'FAIL  Conda        university-dev environment is missing\n'
    failed=1
fi

for vscode_file in \
    .vscode/activate-university-dev.sh \
    .vscode/c_cpp_properties.json \
    .vscode/cmake-kits.json \
    .vscode/settings.json \
    .vscode/tasks.json; do
    if [[ -f "${PROJECT_ROOT}/${vscode_file}" ]]; then
        printf 'PASS  VS Code      %s exists\n' "${vscode_file}"
    else
        printf 'FAIL  VS Code      %s is missing\n' "${vscode_file}"
        failed=1
    fi
done

exit "${failed}"
