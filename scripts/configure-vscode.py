#!/usr/bin/env python3
"""Generate machine-local VS Code configuration for the active Conda compiler."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import platform
import shlex
import shutil
import stat
import sys
from typing import Any


CONFIGURATION_NAME = "macOS Conda (university-dev)"
BUILD_TASK_LABEL = "C/C++: Conda compiler build active file"
DEBUG_CONFIGURATION_NAME = "C/C++: Conda build and debug active file"


def executable_path(value: str) -> str | None:
    executable = shutil.which(value)
    if executable is not None:
        return str(Path(executable).absolute())

    candidate = Path(value).expanduser()
    if candidate.is_file() and os.access(candidate, os.X_OK):
        return str(candidate.absolute())
    return None


def compiler_path(
    variable: str, conda_prefix: Path, fallback_patterns: tuple[str, ...]
) -> tuple[str, list[str]]:
    raw_value = os.environ.get(variable, "").strip()
    if raw_value:
        parts = shlex.split(raw_value)
        executable = executable_path(parts[0])
        if executable is None:
            raise RuntimeError(f"The {variable} compiler is not executable: {parts[0]}")
        return executable, parts[1:]

    # Some `conda run` versions do not expose compiler activation variables even
    # though the compiler wrappers are installed. Prefer the target-prefixed
    # Conda wrapper, which carries the correct macOS target and sysroot behavior.
    bin_directory = conda_prefix / "bin"
    for pattern in fallback_patterns:
        for candidate in sorted(bin_directory.glob(pattern)):
            if candidate.is_file() and os.access(candidate, os.X_OK):
                return str(candidate.absolute()), []

    patterns = ", ".join(fallback_patterns)
    raise RuntimeError(
        f"Conda did not set {variable}, and no compiler matching {patterns} was "
        f"found under {bin_directory}. Run `conda list -n university-dev "
        "cxx-compiler` to confirm the package is installed."
    )


def read_json(path: Path, default: Any) -> Any:
    if not path.exists():
        return default
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError) as error:
        raise RuntimeError(f"Cannot update invalid JSON file {path}: {error}") from error


def write_json(path: Path, value: Any) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def replace_named(items: list[dict[str, Any]], name: str, value: dict[str, Any]) -> None:
    items[:] = [item for item in items if item.get("name") != name]
    items.append(value)


def compiler_environment() -> dict[str, str]:
    names = (
        "AR",
        "CC",
        "CFLAGS",
        "CONDA_BUILD_SYSROOT",
        "CONDA_DEFAULT_ENV",
        "CONDA_PREFIX",
        "CPPFLAGS",
        "CXX",
        "CXXFLAGS",
        "LD",
        "LDFLAGS",
        "MACOSX_DEPLOYMENT_TARGET",
        "NM",
        "PATH",
        "RANLIB",
        "SDKROOT",
        "STRIP",
    )
    return {name: os.environ[name] for name in names if os.environ.get(name)}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--workspace", required=True, type=Path)
    parser.add_argument("--conda-exe", required=True, type=Path)
    args = parser.parse_args()

    workspace = args.workspace.expanduser().resolve()
    vscode_directory = workspace / ".vscode"
    vscode_directory.mkdir(parents=True, exist_ok=True)

    conda_prefix = Path(os.environ.get("CONDA_PREFIX", sys.prefix)).resolve()
    cc_path, cc_inline_args = compiler_path(
        "CC",
        conda_prefix,
        ("*-apple-darwin*-clang", "*-conda-darwin*-clang", "clang"),
    )
    cxx_path, cxx_inline_args = compiler_path(
        "CXX",
        conda_prefix,
        ("*-apple-darwin*-clang++", "*-conda-darwin*-clang++", "clang++"),
    )
    cxx_flags = cxx_inline_args + shlex.split(os.environ.get("CXXFLAGS", ""))
    architecture = "arm64" if platform.machine() in {"arm64", "aarch64"} else "x64"
    environment = compiler_environment()
    environment["CC"] = cc_path
    environment["CXX"] = cxx_path

    activation_path = vscode_directory / "activate-university-dev.sh"
    activation_path.write_text(
        "#!/usr/bin/env bash\n"
        "set -e\n"
        f'eval "$("{args.conda_exe.resolve()}" shell.bash hook)"\n'
        "conda activate university-dev\n",
        encoding="utf-8",
    )
    activation_path.chmod(activation_path.stat().st_mode | stat.S_IXUSR)

    properties_path = vscode_directory / "c_cpp_properties.json"
    properties = read_json(properties_path, {"configurations": [], "version": 4})
    configurations = properties.setdefault("configurations", [])
    replace_named(
        configurations,
        CONFIGURATION_NAME,
        {
            "name": CONFIGURATION_NAME,
            "compilerPath": cxx_path,
            "compilerArgs": cxx_flags,
            "cStandard": "c17",
            "cppStandard": "c++20",
            "intelliSenseMode": f"macos-clang-{architecture}",
        },
    )
    properties["version"] = 4
    write_json(properties_path, properties)

    kits_path = vscode_directory / "cmake-kits.json"
    kits = read_json(kits_path, [])
    replace_named(
        kits,
        CONFIGURATION_NAME,
        {
            "name": CONFIGURATION_NAME,
            "keep": True,
            "preferredGenerator": "Ninja",
            "environmentSetupScript": "${workspaceFolder}/.vscode/activate-university-dev.sh",
            "environmentVariables": environment,
            "compilers": {"C": cc_path, "CXX": cxx_path},
        },
    )
    write_json(kits_path, kits)

    settings_path = vscode_directory / "settings.json"
    settings = read_json(settings_path, {})
    settings.update(
        {
            "C_Cpp.default.compilerPath": cxx_path,
            "C_Cpp.default.compilerArgs": cxx_flags,
            "C_Cpp.default.cStandard": "c17",
            "C_Cpp.default.cppStandard": "c++20",
            "cmake.generator": "Ninja",
        }
    )
    write_json(settings_path, settings)

    tasks_path = vscode_directory / "tasks.json"
    tasks = read_json(tasks_path, {"version": "2.0.0", "tasks": []})
    task_items = tasks.setdefault("tasks", [])
    task_items[:] = [task for task in task_items if task.get("label") != BUILD_TASK_LABEL]
    task_items.append(
        {
            "type": "cppbuild",
            "label": BUILD_TASK_LABEL,
            "command": cxx_path,
            "args": cxx_flags
            + [
                "-std=c++20",
                "-g",
                "${file}",
                "-o",
                "${fileDirname}/${fileBasenameNoExtension}",
            ],
            "options": {"cwd": "${fileDirname}", "env": environment},
            "problemMatcher": ["$gcc"],
            "group": {"kind": "build", "isDefault": True},
            "detail": "Generated from the university-dev Conda environment.",
        }
    )
    tasks["version"] = "2.0.0"
    write_json(tasks_path, tasks)

    launch_path = vscode_directory / "launch.json"
    launch = read_json(launch_path, {"version": "0.2.0", "configurations": []})
    debug_configurations = launch.setdefault("configurations", [])
    replace_named(
        debug_configurations,
        DEBUG_CONFIGURATION_NAME,
        {
            "name": DEBUG_CONFIGURATION_NAME,
            "type": "cppdbg",
            "request": "launch",
            "program": "${fileDirname}/${fileBasenameNoExtension}",
            "args": [],
            "stopAtEntry": False,
            "cwd": "${fileDirname}",
            "environment": [],
            "externalConsole": False,
            "MIMode": "lldb",
            "preLaunchTask": BUILD_TASK_LABEL,
        },
    )
    launch["version"] = "0.2.0"
    write_json(launch_path, launch)

    print(f"Configured VS Code C compiler:   {cc_path}")
    print(f"Configured VS Code C++ compiler: {cxx_path}")
    print(f"Generated configuration under:   {vscode_directory}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(1) from error
