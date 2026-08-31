# University Development Environment

This repository provides two Ubuntu development images while keeping all source
code on the Mac:

- `web`: Ubuntu 24.04, Apache, Git, and Python
- `programming`: Ubuntu 24.04, GCC/G++, GDB, LLDB, CMake, Ninja, Git, and Python

The Mac also gets a Miniconda environment for native Python and C++ work. VS
Code and Codex can work locally or through the included Dev Container
configurations.

## How source storage works

The containers do not own the source code. Docker bind-mounts host directories:

```text
Mac                                         Container
personal/web/        <------------------->  web document root
classes/             <------------------->  /workspace/classes
```

A file saved on macOS is immediately visible in the container, and a file saved
in the container is immediately visible on macOS. This allows an assignment to
be edited and built either natively or in Ubuntu.

Keep platform-specific generated files separate. In particular:

- Use `build-macos/` for native CMake output.
- Use `build-linux/` for container CMake output.
- Use the native Conda environment on macOS.
- Put Linux Python virtual environments under `/home/student/.venvs` in the
  programming container, not inside a shared assignment directory.

Do not reuse compiled objects, executables, or Python virtual environments
between macOS and Linux.

External drives work as bind-mount sources too. Use an absolute path such as
`/Volumes/CourseWork/classes` and allow that location in Docker Desktop's file
sharing settings if macOS prompts for access.

## Initial setup on macOS

Run:

```bash
./scripts/bootstrap-macos.sh
```

The script is idempotent and checks or installs:

- Apple Command Line Tools
- Homebrew
- Docker Desktop and Docker Compose
- Visual Studio Code
- Miniconda
- GitHub CLI
- Codex CLI
- Recommended VS Code extensions
- Microsoft's C/C++ Extension Pack and CMake Tools
- The `university-dev` Conda environment
- Machine-local VS Code compiler, build-task, and CMake-kit configuration
- Both Docker images

Applications already present in `/Applications` are accepted even when they
were installed manually rather than through Homebrew. The script temporarily
adds the VS Code and Docker application CLI directories to `PATH` when needed.

Apple's Command Line Tools installer is interactive. If it opens, finish that
installation and run the bootstrap script again. Docker Desktop may also ask
for normal first-run permissions.

The script creates `.env` from `.env.example` but never fills in credentials.
It preserves an existing `.env` on later runs.

Verify the installation with:

```bash
./scripts/verify.sh
```

## Configuration

Edit the ignored `.env` file in this repository. Docker Compose automatically
loads it.

| Variable | Purpose | Default |
|---|---|---|
| `HOST_WEB_ROOT` | macOS directory containing web content | `./personal/web` |
| `HOST_PROGRAMMING_ROOT` | macOS directory containing assignments | `./classes` |
| `WEB_HOST_PORT` | Apache port on localhost | `8080` |
| `PROGRAMMING_HOST_PORT` | Optional programming service port on localhost | `8000` |
| `PROGRAMMING_CONTAINER_PORT` | Matching port inside the programming container | `8000` |
| `WEB_CONTAINER_WEB_ROOT` | Apache document root inside the web container | `/var/www/html` |
| `DEV_UID`, `DEV_GID` | Host identity used by the programming image | set by bootstrap |
| `DEV_GH_TOKEN` | Optional GitHub token injected as `GH_TOKEN` | empty |
| `DEV_OPENAI_API_KEY` | Optional OpenAI key injected as `OPENAI_API_KEY` | empty |

Paths may be relative to this repository or absolute. Do not use `~` in
`.env`; use a full path such as `/Users/alex/classes`.

### Credentials

The preferred GitHub setup is interactive authentication:

```bash
gh auth login
```

If automation requires a token, set it only in the untracked `.env`:

```dotenv
DEV_GH_TOKEN=github_token_value
```

The preferred Codex setup is also interactive:

```bash
codex
```

Choose **Sign in with ChatGPT** the first time. An OpenAI API key is not needed
for that login. Set `OPENAI_API_KEY` only when course or web application code
uses the OpenAI API. The explicit `DEV_` prefix prevents an unrelated token
exported in the macOS shell from being passed to containers accidentally:

```dotenv
DEV_OPENAI_API_KEY=openai_api_key_value
```

Compose makes these two optional variables available inside both containers.
Any process in a container can read its environment, so do not put credentials
in `compose.yaml`, a Dockerfile, an image, or a committed file. Rotate a token
immediately if it is accidentally committed.

Official Codex setup references:

- [Codex CLI](https://learn.chatgpt.com/docs/codex/cli)
- [Codex IDE extension](https://learn.chatgpt.com/docs/codex/ide)

## Web development

Start Apache:

```bash
docker compose up -d --build web
```

Open <http://localhost:8080>, or use the port selected by `WEB_HOST_PORT`.

Useful commands:

```bash
docker compose logs -f web
docker compose exec web bash
docker compose exec web python --version
docker compose stop web
```

Apache serves the host directory selected by `HOST_WEB_ROOT`. The container
document root is selected by `WEB_CONTAINER_WEB_ROOT`; Compose mounts the host
directory at that same location and generates the Apache virtual-host
configuration when the container starts.

For the simplest workflow, open `personal/web/` in a normal VS Code window and
leave Apache in Docker. Alternatively, run **Dev Containers: Open Folder in
Container** and select `.devcontainer/web/devcontainer.json`.

## Programming classes

Start the Ubuntu programming container:

```bash
docker compose up -d --build programming
docker compose exec programming bash
```

Example Linux C++ build:

```bash
cd /workspace/classes/example-assignment
cmake -S . -B build-linux
cmake --build build-linux
ctest --test-dir build-linux
```

Example container-only Python environment:

```bash
python -m venv /home/student/.venvs/example-assignment
source /home/student/.venvs/example-assignment/bin/activate
python -m pip install --upgrade pip
```

To run a local development server from the programming container, bind it to
`0.0.0.0` and use `PROGRAMMING_CONTAINER_PORT`. For example:

```bash
python -m http.server 8000 --bind 0.0.0.0
```

The browser then uses <http://localhost:8000>.

For a full remote toolchain, select
`.devcontainer/programming/devcontainer.json` from VS Code's Dev Containers
commands. Terminals, C++ language services, debugging, and Python then run in
Ubuntu while the files remain on the Mac.

## Native macOS programming

Restart the shell after bootstrap, then activate the environment:

```bash
conda activate university-dev
```

The environment is defined by `environment-macos.yml` and includes Python,
the Conda-forge native C++ compiler toolchain, CMake, Ninja, and pytest.

The bootstrap activates that environment non-interactively, discovers the
actual Conda C and C++ compiler paths, and generates these machine-local files:

- `.vscode/c_cpp_properties.json` for C/C++ IntelliSense
- `.vscode/settings.json` for the default C/C++ compiler and language standards
- `.vscode/tasks.json` for the default active-file build task (`Cmd+Shift+B`)
- `.vscode/cmake-kits.json` for a `macOS Conda (university-dev)` CMake kit
- `.vscode/activate-university-dev.sh` for CMake Tools environment activation

These files contain Mac-specific absolute paths, so Git ignores them. Open the
`uni_dev` repository root in VS Code and restart or reload the window after
bootstrap. The Microsoft C/C++ extension then uses the Conda compiler without
asking you to paste its path. For a CMake project, select the generated
`macOS Conda (university-dev)` kit if CMake Tools asks for a kit the first time.
It remembers that choice for the workspace.

VS Code applies `.vscode` configuration from the folder opened as the
workspace. If you open an assignment directory by itself instead of opening it
under the `uni_dev` workspace, generate the same configuration there with:

```bash
conda activate university-dev
python /path/to/uni_dev/scripts/configure-vscode.py \
  --workspace "$PWD" \
  --conda-exe "$CONDA_EXE"
```

Rerun `./scripts/bootstrap-macos.sh` after moving or updating Miniconda so the
repository-level paths are regenerated.

Example native build:

```bash
cd classes/example-assignment
cmake -S . -B build-macos -G Ninja
cmake --build build-macos
ctest --test-dir build-macos
```

Update the environment after changing `environment-macos.yml`:

```bash
conda env update --name university-dev --file environment-macos.yml --prune
```

## Codex and VS Code

The bootstrap installs both the Codex VS Code extension and the host Codex CLI.
The extension is also requested by both Dev Container configurations.

Recommended usage:

- From a local VS Code window, Codex edits the host files and can invoke
  `docker compose` commands.
- From a Dev Container window, use the Codex sidebar alongside the remote
  Ubuntu toolchain.
- From a terminal, change to either `personal/web/`, `classes/`, or a specific
  project repository and run `codex`.

Keeping the CLI on the Mac avoids embedding Codex credentials in images. The
repository's `AGENTS.md` gives Codex the standard build and test commands.

## Sharing

Commit this repository's Dockerfiles, Compose file, Dev Container definitions,
Conda file, scripts, and `.env.example`. Never commit `.env`.

Docker Hub is not required: collaborators can clone the repository and run the
bootstrap or `docker compose build`. Publishing images to Docker Hub or GitHub
Container Registry can be added later if builds become expensive or a deployment
pipeline needs immutable images.

On a fresh clone, create the expected source roots if they do not exist:

```bash
mkdir -p classes personal/web
```

Then run the bootstrap script.
