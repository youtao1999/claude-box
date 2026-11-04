# claude-box

Claude Code in a Docker container for the flake pipeline ([flake_catalog](https://github.com/youtao1999/flake_catalog)).
The container sees only these folders:

| Inside the container | On the PC (set in `.env`) | Access |
|---|---|---|
| `/workspace` | `REPO_DIR`, the flake_catalog checkout | read/write |
| `/data/raw` | `RAW_DIR`, the pictures | **read-only** |
| `/data/derived` | `DERIVED_DIR`, the results | read/write |
| `/data/scratch` | `SCRATCH_DIR` | read/write |
| `/data/klayout` | `KLAYOUT_WORK_DIR` | read/write |

- A firewall lets it reach only Anthropic, PyPI and GitHub. To allow another site, add it to
  `DOMAINS` in `init-firewall.sh`, rebuild, and restart the container.
- The only push allowed is `git push no-mistakes <branch>` (through the [no-mistakes](https://github.com/kunchenguid/no-mistakes)
  gate). A root-owned hook (`push-guard.sh`) blocks any other `git push` from Claude.
- KLayout with KlayoutKlaw runs inside the container on a virtual screen (MCP server `klayoutclaw`).
- Tools from flake_catalog's CLAUDE.md are installed: `gh`, `gh-axi`, `chrome-devtools-axi`
  (with Chrome), `no-mistakes`, `gnhf`. The `caveman` and `ponytail` skills come preinstalled.

The container keeps running in the background (`docker compose up -d`), so the no-mistakes
daemon can keep watching PRs and CI between sessions. You open Claude in it with `docker exec`.

## Setting up a new PC

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) (with WSL 2) and start it.
   No Windows admin? See [Docker inside WSL](#docker-inside-wsl-no-docker-desktop) below.
2. Clone the three repos side by side:
   ```
   git clone https://github.com/youtao1999/flake_catalog.git
   git clone https://github.com/caidish/KlayoutClaw.git
   git clone https://github.com/youtao1999/claude-box.git
   ```
   You can skip flake_catalog if the PC already has a checkout.
3. In `claude-box`, copy `.env.example` to `.env` and set this PC's folders.
   Create the scratch and klayout folders if they don't exist.
4. Build the image (10–15 minutes the first time) and start the container:
   ```
   cd claude-box
   docker compose build
   docker compose up -d
   ```
5. Log in, once (all three logins are kept in Docker volumes and survive rebuilds):
   ```
   docker exec -it flake-claude gh auth login              # GitHub
   docker exec -it flake-claude sh -c "cd /workspace && no-mistakes init"
   docker exec -it flake-claude claude                     # Claude: log in when it asks
   ```

## Daily use

```
docker exec -it flake-claude claude      # Claude, in /workspace
docker exec -it flake-claude bash        # a shell
```

If the container isn't running (after a reboot it restarts with Docker), `docker compose up -d`
in this folder starts it. After changing the Dockerfile or the scripts:
`docker compose build && docker compose up -d` (this replaces the container; the volumes stay).

Claude and the capture app both write `flakes.xlsx`. Don't run them at the same time.

## Workbook links

`flakes.xlsx` links to pictures and results with the **PC's** paths (`D:\flake_raw\...`), so
the operator can click them in Excel. compose sets `FLAKE_LINK_MAP` from `.env` for that. Inside
the container, `build_catalog.container_path(link)` turns such a link back into `/data/...`.

## Docker inside WSL (no Docker Desktop)

Docker Desktop needs a Windows admin. Without one, Docker Engine can be installed inside a WSL
distro (here `Ubuntu-24.04`, used as root). Then `docker` exists only inside WSL, and cmd says:

```
'docker' is not recognized as an internal or external command
```

Differences from the steps above:

- **Run every docker command through WSL.** For `compose`, also run it from this folder as WSL sees it:
  ```
  wsl -d Ubuntu-24.04 -u root --cd /mnt/c/Users/<you>/claude-box -- docker compose build
  wsl -d Ubuntu-24.04 -u root --cd /mnt/c/Users/<you>/claude-box -- docker compose up -d
  wsl -d Ubuntu-24.04 -u root -- docker exec -it flake-claude claude
  ```
  From Git Bash, set `MSYS_NO_PATHCONV=1` first, or it rewrites the `/mnt/c/...` argument.
- **`.env` paths are WSL paths** (`C:/...` → `/mnt/c/...`, `D:/...` → `/mnt/d/...`), because the
  Docker engine runs in Linux. Also set `REPO_LINK`, `RAW_LINK` and `DERIVED_LINK` to the
  Windows paths (see `.env.example`), or workbook links come out as `/mnt/d/...` and don't open in Excel.
- **Keep WSL running.** WSL stops the distro, and the container with it, shortly after the last
  `wsl.exe` window closes. To stop that, put this in `%UserProfile%\.wslconfig`, then run `wsl --shutdown` once:
  ```
  [general]
  instanceIdleTimeout=-1
  ```
  The distro then runs until the PC restarts. After a restart, any `wsl` command starts it again,
  and the container comes back with it.
- **From PowerShell**, `$VAR` inside `wsl ... sh -c '...'` is expanded on the way in. To
  run a script in the container, pipe a file instead of quoting it inline.
