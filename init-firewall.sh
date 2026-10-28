#!/bin/bash
# Outbound allowlist for the Claude container (adapted from Anthropic's reference devcontainer).
# Everything else is rejected. To allow a new site: add it to DOMAINS, then restart the container.
set -euo pipefail
IFS=$'\n\t'

DOMAINS=(
    # Claude Code: API, login, telemetry / error reports
    api.anthropic.com
    claude.ai
    platform.claude.com
    console.anthropic.com
    statsig.com
    sentry.io
    # Python packages
    pypi.org
    files.pythonhosted.org
)

# keep Docker's internal DNS (127.0.0.11) rules across the flush
DOCKER_DNS_RULES=$(iptables-save -t nat | grep "127\.0\.0\.11" || true)

iptables -F; iptables -X
iptables -t nat -F; iptables -t nat -X
iptables -t mangle -F; iptables -t mangle -X
ipset destroy allowed-domains 2>/dev/null || true

if [ -n "$DOCKER_DNS_RULES" ]; then
    iptables -t nat -N DOCKER_OUTPUT 2>/dev/null || true
    iptables -t nat -N DOCKER_POSTROUTING 2>/dev/null || true
    echo "$DOCKER_DNS_RULES" | xargs -L 1 iptables -t nat
fi

# DNS, loopback (KlayoutKlaw on 127.0.0.1:8765), replies to allowed connections
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --sport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
iptables -A INPUT -p tcp --sport 53 -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

ipset create allowed-domains hash:net

echo "firewall: GitHub address ranges"
gh_ranges=$(curl -fsS --max-time 20 https://api.github.com/meta)
echo "$gh_ranges" | jq -e '.web and .api and .git' >/dev/null
while read -r cidr; do
    ipset add allowed-domains "$cidr" -exist
done < <(echo "$gh_ranges" | jq -r '(.web + .api + .git)[]' | grep -v ':' | aggregate -q)

for domain in "${DOMAINS[@]}"; do
    ips=$(dig +short A "$domain" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || true)
    if [ -z "$ips" ]; then
        echo "firewall: WARNING: no address for $domain"
        continue
    fi
    while read -r ip; do
        ipset add allowed-domains "$ip" -exist
    done <<< "$ips"
done

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited

if curl -fsS --max-time 5 https://example.com >/dev/null 2>&1; then
    echo "firewall: FAILED - example.com is reachable"; exit 1
fi
if ! curl -fsS --max-time 10 https://api.github.com/zen >/dev/null 2>&1; then
    echo "firewall: FAILED - api.github.com is not reachable"; exit 1
fi
echo "firewall: on (example.com blocked, GitHub reachable)"
