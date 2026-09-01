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
4. Wait for the Dev Container connection to complete, then work under
   `/workspace/classes`.

Select **University Web Development** instead to work in the Apache container.
VS Code then opens the web document root instead.

The lower-left remote indicator identifies a Dev Container window. Its
integrated terminal is an Ubuntu shell, and builds, tests, language services,
debuggers, and project-level Codex actions use the container's Linux tools.
Edits remain immediately visible on the Mac because the source is bind-mounted.

Starting a container with `docker compose` does not by itself move VS Code into
Linux; use **Reopen in Container** when the editor and its tools should operate
there.

### First Dev Container startup and terminal verification

The first connection is normally the slowest. VS Code may need to build the
image, create the container, install VS Code Server, and install Linux copies
of the requested extensions. Later connections reuse those components unless
the image or Dev Container configuration changes.

The setup view may continue to display diagnostic messages such as
`Extensions cache, remote removals: None`. That view is a Dev Containers log,
not an interactive Ubuntu command line. Close or ignore it and choose
**Terminal: Create New Terminal** when a shell is needed.

A terminal that was already open before **Reopen in Container** may still show
the prior macOS shell. Close that terminal and create a new one after the
lower-left indicator shows the Dev Container connection. Verify the new shell
with:

```bash
whoami
pwd
uname -s
```

Expected programming-container results are `student`, `/workspace/classes`,
and `Linux`. With the checked-in configuration, expected web-container results
are `root`, `/var/www/html`, and `Linux`.

### Switching containers and returning to macOS

While connected to one container, **Dev Containers: Reopen in Container** is
normally absent because the VS Code window is already remote. To move from
**University Programming** to **University Web Development**, or vice versa:

1. Try **Dev Containers: Switch Container** from the Command Palette.
2. If that command is unavailable, run **Dev Containers: Reopen Folder
   Locally**.
3. From the local window, run **Dev Containers: Reopen in Container** and
   select the other container.

Use **Dev Containers: Reopen Folder Locally** whenever VS Code extensions,
terminals, compilers, Python, and Codex should operate on macOS again.

### Container source-directory mappings

The directory shown by `pwd` is the container side of a Docker bind mount. Its
files remain on the Mac:

| Dev Container | macOS source setting | Default macOS source | Container setting or path | Default `pwd` |
|---|---|---|---|---|
| University Web Development | `HOST_WEB_ROOT` | `./personal/web` | `WEB_CONTAINER_WEB_ROOT` | `/var/www/html` |
| University Programming | `HOST_PROGRAMMING_ROOT` | `./classes` | fixed path | `/workspace/classes` |

Changing `HOST_WEB_ROOT` or `HOST_PROGRAMMING_ROOT` in `.env` changes the Mac
directory being mounted. It does not change the programming path inside
Ubuntu. The web path remains `/var/www/html` unless
`WEB_CONTAINER_WEB_ROOT` is also changed. The checked-in web Dev Container also
sets `workspaceFolder` to `/var/www/html`; if the container web root is changed,
update `.devcontainer/web/devcontainer.json` to the same path. See the
[Configuration](#configuration) variables for path requirements and defaults.

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

### Using VS Code in the programming container

Follow [Choose where VS Code runs](#choose-where-vs-code-runs) and select
**University Programming**. VS Code can start the service itself, so
`docker.sh` does not need to be run first. C and C++ then use GCC/G++, Python
uses the container interpreter, and CMake generates Linux build output while
the source remains on the Mac.

For a simple C++ file, the container's C/C++ extension may show its normal
first-run build-compiler picker because each user-owned source workspace has
its own build configuration. Select the entry for `/usr/bin/g++`; VS Code saves
that choice in the source workspace's `.vscode/tasks.json`. A CMake-based
assignment should normally be configured and built with CMake Tools instead.

Opening, switching, or closing a Dev Container does not move or delete the
bind-mounted source files.

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

## Adding an assignment-specific Dev Container (experimental)

> **Experimental:** The patterns in this section have not yet been tested as
> part of `uni_dev`. Professor-provided images, Dockerfiles, Compose files, and
> course requirements vary. Inspect and test each assignment environment before
> relying on it.

A professor-provided Docker environment should normally remain associated with
that assignment instead of being merged into the shared `programming` image.
This preserves the professor's expected tool versions and prevents one course
from changing another course's environment.

### Recommended: keep the Dev Container with the assignment

Store the assignment under the user-owned classes directory and add a
`.devcontainer/devcontainer.json` inside it:

```text
classes/cs301-assignment-1/
├── .devcontainer/
│   └── devcontainer.json
├── Dockerfile or compose.yaml
└── assignment source files
```

If the professor already supplies `devcontainer.json`, use it as provided after
reviewing it. Otherwise, create a small wrapper appropriate to the supplied
Docker format.

For a Dockerfile at the assignment root:

```json
{
  "name": "CS301 Assignment 1",
  "build": {
    "dockerfile": "../Dockerfile",
    "context": ".."
  },
  "workspaceFolder": "/workspaces/${localWorkspaceFolderBasename}",
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-vscode.cpptools-extension-pack",
        "ms-python.python",
        "openai.chatgpt"
      ]
    }
  }
}
```

For a published image:

```json
{
  "name": "CS301 Assignment 1",
  "image": "professor/course-environment:version",
  "workspaceFolder": "/workspaces/${localWorkspaceFolderBasename}"
}
```

Prefer a versioned tag or image digest supplied by the professor over
`latest`, so the environment does not change unexpectedly during the course.

For a Compose file at the assignment root:

```json
{
  "name": "CS301 Assignment 1",
  "dockerComposeFile": "../compose.yaml",
  "service": "assignment",
  "workspaceFolder": "/workspace"
}
```

For the Compose form, replace `assignment` and `/workspace` with the service
name and bind-mounted working directory defined by the professor's file. The
service must mount the assignment source at the selected `workspaceFolder`.

Open the assignment directory—not the `uni_dev` root—in VS Code, then run
**Dev Containers: Reopen in Container**. This approach works whether the
assignment uses its own Git repository, another version-control system, or no
version control. If the assignment is a Git repository and course policy
permits it, its Dev Container configuration can be committed with that
assignment.

### Optional: add the assignment to the `uni_dev` container chooser

If selecting every environment from the `uni_dev` root is important, a local
wrapper can be placed at:

```text
.devcontainer/local-cs301-assignment-1/devcontainer.json
```

For an assignment Dockerfile, an experimental wrapper would look like:

```json
{
  "name": "CS301 Assignment 1",
  "build": {
    "dockerfile": "../../classes/cs301-assignment-1/Dockerfile",
    "context": "../../classes/cs301-assignment-1"
  },
  "workspaceMount": "source=${localWorkspaceFolder}/classes/cs301-assignment-1,target=/workspace,type=bind",
  "workspaceFolder": "/workspace"
}
```

With `uni_dev` open locally, this should add **CS301 Assignment 1** to the list
shown by **Dev Containers: Reopen in Container**. This root-wrapper approach is
less portable and has not been validated in this project. Keep user-specific
wrappers out of the `uni_dev` repository; for example, add
`.devcontainer/local-*/` to the clone's `.git/info/exclude`. The
assignment-local approach above remains the recommendation.

### Review supplied environments before running them

Treat Docker configuration as executable code. Before opening a supplied
environment:

- Review its Dockerfile, Compose file, entrypoint, setup scripts, and image
  source.
- Mount only the assignment directory. Avoid mounting the entire home
  directory, credentials, SSH keys, or `/var/run/docker.sock` unless the course
  has a clear and trusted requirement.
- Do not place GitHub, OpenAI, or other secrets in the image or committed files.
- Check whether the image supports the Mac's CPU architecture. An
  `linux/amd64`-only image may require Docker Desktop emulation on an Apple
  Silicon Mac and will usually run more slowly.
- Preserve any professor-required ports, commands, users, and submission tools.

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

Under this repository-root workflow, there is no first-run compiler selection:
the bootstrap has already selected the Conda compiler and generated the default
build and debug configurations. If VS Code nevertheless displays a compiler
picker, first confirm that `uni_dev`—not an individual assignment directory—is
the folder open in that window, run `./scripts/verify.sh`, and reload the VS
Code window.

For a CMake project, select the generated `macOS Conda (university-dev)` kit if
CMake Tools asks for a kit the first time. CMake Tools stores the active kit in
its private workspace state and does not provide a supported setting that the
bootstrap can preselect. It remembers the one-time choice for the workspace.

VS Code applies `.vscode` configuration from the folder opened as the
workspace. If you open an assignment directory by itself instead of opening it
under the `uni_dev` workspace, it does not inherit the generated configuration.
Generate the same configuration there before the first local build with:

```bash
conda activate university-dev
python /path/to/uni_dev/scripts/configure-vscode.py \
  --workspace "$PWD" \
  --conda-exe "$CONDA_EXE"
```

After generation and a VS Code window reload, that standalone workspace also
uses Conda without a compiler-selection step. If generation is skipped, VS
Code asks for a compiler on its first active-file build; select the Conda
`clang++` entry that it detected. That one-time selection is stored only for
that assignment workspace.

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
