#!/bin/bash
# Firewall, virtual screen, KLayout with the KlayoutKlaw server (127.0.0.1:8765, inside this
# container only), then the command (default: claude).
set -euo pipefail

sudo /usr/local/bin/init-firewall.sh

Xvfb :99 -screen 0 1920x1080x24 -nolisten tcp >/tmp/xvfb.log 2>&1 &
for _ in $(seq 50); do [ -e /tmp/.X11-unix/X99 ] && break; sleep 0.1; done

klayout -e >/tmp/klayout.log 2>&1 &
ok=""
for _ in $(seq 120); do
    if (echo >/dev/tcp/127.0.0.1/8765) 2>/dev/null; then ok=1; break; fi
    sleep 0.5
done
[ -n "$ok" ] && echo "KlayoutKlaw ready on 127.0.0.1:8765" \
    || echo "WARNING: KlayoutKlaw did not start in 60 s (see /tmp/klayout.log and ~/.klayout/klayoutclaw.log)"

exec "$@"
