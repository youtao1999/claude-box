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

A firewall lets it reach only Anthropic, PyPI and GitHub. `git push` is blocked.
KLayout with KlayoutKlaw runs inside the container on a virtual screen.

## Setting up a new PC

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) (with WSL 2) and start it.
2. Clone the three repos side by side:
   ```
   git clone https://github.com/youtao1999/flake_catalog.git
   git clone https://github.com/caidish/KlayoutClaw.git
   git clone https://github.com/youtao1999/claude-box.git
   ```
   You can skip flake_catalog if the PC already has a checkout.
3. In `claude-box`, copy `.env.example` to `.env` and set this PC's folders.
   Create the scratch and klayout folders if they don't exist.
4. Build the image (10–15 minutes the first time):
   ```
   cd claude-box
   docker compose build
   ```
5. Start Claude and log in when it asks:
   ```
   docker compose run --rm claude
   ```
6. Install the plugins once (type these in Claude), then exit and start Claude again:
   ```
   /plugin marketplace add DietrichGebert/ponytail
   /plugin install ponytail@ponytail
   /plugin marketplace add JuliusBrussee/caveman
   /plugin install caveman@caveman
   ```
   The login and the plugins are kept in the Docker volume `claude_cfg`. Rebuilding doesn't remove them.

## Daily use

```
docker compose run --rm claude           # Claude
docker compose run --rm claude bash      # a shell with the same setup
```
After changing the Dockerfile or the scripts, run `docker compose build` again.

Claude and the capture app both write `flakes.xlsx`. Don't run them at the same time.
