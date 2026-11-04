# Claude Code for the flake pipeline: Python + KLayout (with KlayoutKlaw) on a virtual screen,
# plus the flake_catalog toolchain (gh, gh-axi, chrome-devtools-axi, no-mistakes, gnhf).
# Build and start from this folder:  docker compose build  /  docker compose up -d
FROM node:22-bookworm AS node

FROM ubuntu:24.04

ARG KLAYOUT_VERSION=0.30.12
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl git jq less procps sudo nano \
        iptables ipset iproute2 dnsutils aggregate \
        python3 python3-pip python3-tk \
        xvfb xauth \
    && rm -rf /var/lib/apt/lists/*

# Node 22 (Ubuntu's nodejs is 18, too old for the npm tools below)
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

# GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# Chrome for chrome-devtools-axi (Ubuntu's chromium is a snap, which doesn't run in Docker)
RUN curl -fsSL -o /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get update && apt-get install -y --no-install-recommends /tmp/chrome.deb \
    && rm /tmp/chrome.deb && rm -rf /var/lib/apt/lists/*

RUN npm install -g gnhf gh-axi chrome-devtools-axi lavish-axi && npm cache clean --force

# no-mistakes (push gate), installed system-wide so the ~/.no-mistakes state volume can't hide it
RUN curl -fsSL https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.sh \
        | NO_MISTAKES_INSTALL_DIR=/usr/local/bin sh || test -x /usr/local/bin/no-mistakes

# KLayout application (its embedded Python is the system python3, so it sees the packages below)
RUN curl -fsSL -o /tmp/klayout.deb \
        "https://www.klayout.org/downloads/Ubuntu-24/klayout_${KLAYOUT_VERSION}-1_amd64.deb" \
    && apt-get update && apt-get install -y --no-install-recommends /tmp/klayout.deb \
    && rm /tmp/klayout.deb && rm -rf /var/lib/apt/lists/*

# pipeline packages (repo requirements.txt), shared by the scripts and KLayout's Python
COPY --from=repo requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir --break-system-packages -r /tmp/requirements.txt && rm /tmp/requirements.txt

# user dev (uid 1000; ubuntu:24.04 ships a user "ubuntu" with that uid)
RUN userdel -r ubuntu 2>/dev/null || true; useradd -m -u 1000 -s /bin/bash dev

# git: the repo is a Windows checkout (CRLF working tree, other owner); GitHub logins come from gh,
# set here rather than in ~/.gitconfig so they survive rebuilds
RUN git config --system safe.directory /workspace \
    && git config --system core.autocrlf true \
    && git config --system core.filemode false \
    && git config --system credential.https://github.com.helper "" \
    && git config --system --add credential.https://github.com.helper "!/usr/bin/gh auth git-credential"

# firewall: root-owned, dev may run only this script as root
COPY init-firewall.sh /usr/local/bin/init-firewall.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY push-guard.sh /usr/local/bin/push-guard.sh
RUN chmod 755 /usr/local/bin/init-firewall.sh /usr/local/bin/entrypoint.sh /usr/local/bin/push-guard.sh \
    && echo "dev ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/dev-firewall \
    && chmod 0440 /etc/sudoers.d/dev-firewall

# locked Claude Code settings and MCP servers (root-owned: Claude cannot edit them)
COPY managed-settings.json managed-mcp.json /etc/claude-code/
RUN chmod 644 /etc/claude-code/*.json

# KlayoutKlaw, installed with its own installer into /home/dev/.klayout/pymacros
COPY --from=klayoutclaw install.py /opt/klayoutclaw/install.py
COPY --from=klayoutclaw plugin /opt/klayoutclaw/plugin
COPY --from=klayoutclaw tools /opt/klayoutclaw/tools

USER dev
WORKDIR /home/dev
RUN python3 /opt/klayoutclaw/install.py
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH=/home/dev/.local/bin:$PATH \
    CLAUDE_CONFIG_DIR=/home/dev/.claude \
    DISABLE_AUTOUPDATER=1 \
    DISPLAY=:99 \
    CHROME_PATH=/usr/bin/google-chrome

# first contents of the state volumes (a volume copies these only when it is created)
RUN mkdir -p /home/dev/.claude /home/dev/.config/gh /home/dev/.no-mistakes /home/dev/.gnhf
COPY --chown=dev:dev config/settings.json /home/dev/.claude/settings.json
COPY --chown=dev:dev config/skills/ /home/dev/.claude/skills/
COPY --chown=dev:dev config/no-mistakes.yaml /home/dev/.no-mistakes/config.yaml
COPY --chown=dev:dev config/gnhf.yml /home/dev/.gnhf/config.yml

WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# long-running: start with "docker compose up -d", work with "docker exec -it flake-claude claude"
CMD ["sleep", "infinity"]
