# Development environment instructions

- Treat `classes/` and `personal/web/` as user-owned source directories.
- Do not delete or overwrite projects within either mounted directory.
- Validate configuration with `docker compose config --quiet`.
- Build the web image with `docker compose build web`.
- Build the programming image with `docker compose build programming`.
- Run Linux CMake builds under `build-linux/`.
- Run native macOS CMake builds under `build-macos/`.
- Store Linux Python virtual environments under `/home/student/.venvs`, not in
  bind-mounted source trees.
- Never commit `.env`, `DEV_GH_TOKEN`, `DEV_OPENAI_API_KEY`, or Codex
  authentication material.
