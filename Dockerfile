# Claude Code for the flake pipeline: Python + KLayout (with KlayoutKlaw) on a virtual screen.
# Build and run from this folder:  docker compose build  /  docker compose run --rm claude
FROM ubuntu:24.04

ARG KLAYOUT_VERSION=0.30.12
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl git jq less procps sudo nano \
        iptables ipset iproute2 dnsutils aggregate \
        python3 python3-pip python3-tk \
        nodejs \
        xvfb xauth \
    && rm -rf /var/lib/apt/lists/*

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

# git: the repo is a Windows checkout (CRLF working tree, other owner)
RUN git config --system safe.directory /workspace \
    && git config --system core.autocrlf true \
    && git config --system core.filemode false

# firewall: root-owned, dev may run only this script as root
COPY init-firewall.sh /usr/local/bin/init-firewall.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/init-firewall.sh /usr/local/bin/entrypoint.sh \
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
    DISPLAY=:99
RUN mkdir -p /home/dev/.claude

WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["claude"]
