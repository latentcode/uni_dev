#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
    cat <<'EOF'
Usage: ./scripts/docker.sh (--web | --code) (--start | --stop)

Targets:
  --web    Apache web-development service
  --code   Ubuntu programming service

Actions:
  --start  Build and start the selected service. For --code, also open Bash.
  --stop   Stop the selected service without deleting it.

Examples:
  ./scripts/docker.sh --web --start
  ./scripts/docker.sh --web --stop
  ./scripts/docker.sh --code --start
  ./scripts/docker.sh --code --stop
EOF
}

fail() {
    printf 'ERROR: %s\n\n' "$1" >&2
    usage >&2
    exit 2
}

service=""
action=""

for argument in "$@"; do
    case "${argument}" in
        --web)
            [[ -z "${service}" || "${service}" == "web" ]] \
                || fail "Choose only one target: --web or --code."
            service="web"
            ;;
        --code)
            [[ -z "${service}" || "${service}" == "programming" ]] \
                || fail "Choose only one target: --web or --code."
            service="programming"
            ;;
        --start)
            [[ -z "${action}" || "${action}" == "start" ]] \
                || fail "Choose only one action: --start or --stop."
            action="start"
            ;;
        --stop)
            [[ -z "${action}" || "${action}" == "stop" ]] \
                || fail "Choose only one action: --start or --stop."
            action="stop"
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            fail "Unknown option: ${argument}"
            ;;
    esac
done

[[ -n "${service}" ]] || fail "Choose a target: --web or --code."
[[ -n "${action}" ]] || fail "Choose an action: --start or --stop."

command -v docker >/dev/null 2>&1 \
    || fail "Docker is not installed or is not on PATH."

if ! docker info >/dev/null 2>&1; then
    printf 'ERROR: Docker Desktop is not running or is not ready.\n' >&2
    exit 1
fi

compose=(docker compose --project-directory "${PROJECT_ROOT}")

case "${action}" in
    start)
        "${compose[@]}" up -d --build "${service}"
        if [[ "${service}" == "programming" ]]; then
            printf '\nOpening Ubuntu Bash. Type exit or press Control-D to return to macOS.\n\n'
            "${compose[@]}" exec programming bash
        fi
        ;;
    stop)
        "${compose[@]}" stop "${service}"
        ;;
esac
