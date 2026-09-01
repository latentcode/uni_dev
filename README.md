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

These default source directories are user-owned storage, not part of the
`uni_dev` repository. Git ignores `/classes/` and `/personal/`, and bootstrap
creates them when they are absent. Their contents may be plain local files,
independent Git repositories hosted anywhere, projects using another
version-control system, or projects with no version control at all.

An independent Git repository nested under either ignored directory works
normally when Git commands are run from that project. Its own `.gitignore`
should exclude its generated files, such as `*.dSYM/` and build directories.

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

## Choose where VS Code runs

The environment supports two distinct VS Code workflows. Linux development is
not limited to command-line editing.

| Workflow | Editor and tools | Source storage | Best for |
|---|---|---|---|
| Local VS Code | VS Code, extensions, Conda, and terminals run on macOS; Docker commands run Linux tools when requested | Mac | Native work or occasional Linux checks |
| VS Code Dev Container | The VS Code interface stays on the Mac, while extensions, terminals, compilers, Python, debuggers, and Codex operate in Ubuntu | Mac through a bind mount | Full Linux-compatible development |

To open the full Linux programming environment:

1. Open the `uni_dev` repository root in VS Code.
2. Press `Cmd+Shift+P` and run **Dev Containers: Reopen in Container**.
3. Select **University Programming**.
4. Work in `/workspace/classes`, which is the Mac directory selected by
   `HOST_PROGRAMMING_ROOT`.

Select **University Web Development** instead to work in the Apache container.
VS Code then opens `/var/www/html`, backed by the Mac directory selected by
`HOST_WEB_ROOT`.

The lower-left remote indicator identifies a Dev Container window. Its
integrated terminal is an Ubuntu shell, and builds, tests, language services,
debuggers, and project-level Codex actions use the container's Linux tools.
Edits remain immediately visible on the Mac because the source is bind-mounted.

To leave a container, press `Cmd+Shift+P` and run **Dev Containers: Reopen
Folder Locally**. Starting a container with `docker compose` does not by itself
move VS Code into Linux; use **Reopen in Container** when the editor and its
tools should operate there.

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
- The default ignored `classes/` and `personal/web/` source directories
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
`.env`; use a full path such as `/Users/alex/classes`. Absolute paths are useful
when source should live entirely outside the `uni_dev` directory. The bootstrap
creates only the two default relative directories; create a custom external
directory before starting its container.

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

## Docker

The provided wrapper script supplies consistent commands for starting and
stopping the web and programming services. The examples using
`./scripts/docker.sh` assume the current directory is the `uni_dev` root.

### Underlying Compose commands

The wrapper uses Docker Compose. In the commands below, `<service>` is either
`web` or `programming`; it is a Compose service name, not the generated
container name.

Build and start a service:

```bash
docker compose up -d --build <service>
```

For example:

```bash
docker compose up -d --build web
```

Stop a service:

```bash
docker compose stop <service>
```

Other useful Compose commands:

```bash
docker compose logs -f <service>
docker compose exec <service> bash
docker compose exec <service> python --version
```

Type `exit` or press `Control-D` to leave a container's Bash shell and return
to the macOS shell. Leaving the shell does not stop the container.

## Web development

### Starting and stopping Apache

Commands shown must be run from the uni_dev root directory.

Start Apache:

```bash
./scripts/docker.sh --web --start
```

Open <http://localhost:8080>, or use the port selected by `WEB_HOST_PORT`.

Stop Apache:

```bash
./scripts/docker.sh --web --stop
```

Apache serves the host directory selected by `HOST_WEB_ROOT`. The container
document root is selected by `WEB_CONTAINER_WEB_ROOT`; Compose mounts the host
directory at that same location and generates the Apache virtual-host
configuration when the container starts.

For the simplest workflow, open `personal/web/` in a normal VS Code window and
leave Apache in Docker. For a complete VS Code session inside Ubuntu, follow
[Choose where VS Code runs](#choose-where-vs-code-runs) and select
**University Web Development**.

## Programming classes

### Starting and stopping the programming container

Commands shown must be run from the uni_dev root directory.

Start the Ubuntu programming container:

```bash
./scripts/docker.sh --code --start
```

After starting the service, the script opens its Ubuntu Bash shell. Type `exit`
or press `Control-D` to return to the macOS shell. The programming container
continues running until it is stopped explicitly.

Stop the Ubuntu programming container:

```bash
./scripts/docker.sh --code --stop
```

### Examples

These examples run from the programming container's Ubuntu shell.

#### C++ build:

```bash
cd /workspace/classes/example-assignment
cmake -S . -B build-linux
cmake --build build-linux
ctest --test-dir build-linux
```

#### Container-only Python environment:

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

For a complete VS Code session using this Ubuntu toolchain, follow [Choose
where VS Code runs](#choose-where-vs-code-runs) and select **University
Programming**. The command-line workflow above remains available when a full
Dev Container window is not needed.

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
- `.vscode/launch.json` for active-file Run and Debug commands
- `.vscode/cmake-kits.json` for a `macOS Conda (university-dev)` CMake kit
- `.vscode/activate-university-dev.sh` for CMake Tools environment activation

These files contain Mac-specific absolute paths, so Git ignores them. Open the
`uni_dev` repository root in VS Code and restart or reload the window after
bootstrap. The Microsoft C/C++ extension then uses the Conda compiler without
asking you to paste its path. Its Run/Debug button and `Cmd+Shift+B` use the
generated Conda task when `uni_dev` is the open workspace.

For a CMake project, select the generated `macOS Conda (university-dev)` kit if
CMake Tools asks for a kit the first time. CMake Tools stores the active kit in
its private workspace state and does not provide a supported setting that the
bootstrap can preselect. It remembers the one-time choice for the workspace.

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
Conda file, scripts, and `.env.example`. Never commit `.env`, `classes/`, or
`personal/` to the `uni_dev` repository. Those source roots are ignored and
belong entirely to the user.

Projects inside those roots may each be separate repositories. They do not
need to use Git or GitHub; Docker bind mounts and the development tools operate
on ordinary directories.

Docker Hub is not required: collaborators can clone the repository and run the
bootstrap or `docker compose build`. Publishing images to Docker Hub or GitHub
Container Registry can be added later if builds become expensive or a deployment
pipeline needs immutable images.

On a fresh clone, run the bootstrap script. It creates the default ignored
source roots automatically. If `.env` points to external source directories,
create those directories separately before starting the containers.
