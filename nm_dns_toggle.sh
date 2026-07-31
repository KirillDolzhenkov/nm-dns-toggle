#!/usr/bin/env bash
set -euo pipefail

# Custom resolvers applied when mode=on (space-separated)
CUSTOM_DNS="111.88.96.50 111.88.96.51"

resolve_active_conn() {
  nmcli -t -f NAME,DEVICE connection show --active \
    | awk -F: '$2 != "lo" && $2 != "" { print $1; exit }'
}

ACTIVE_CONN="$(resolve_active_conn || true)"

if [[ -z "${ACTIVE_CONN}" ]]; then
  echo "nm-dns-toggle: no active NetworkManager profile found." >&2
  echo "Hint: nmcli connection show --active" >&2
  exit 1
fi

apply_custom_dns() {
  echo "nm-dns-toggle: enabling custom DNS (${CUSTOM_DNS}) on «${ACTIVE_CONN}»"
  nmcli connection modify "${ACTIVE_CONN}" ipv4.dns "${CUSTOM_DNS}"
  nmcli connection modify "${ACTIVE_CONN}" ipv4.ignore-auto-dns yes
  nmcli connection up "${ACTIVE_CONN}"
  notify-send "nm-dns-toggle" "Custom DNS active (${ACTIVE_CONN})" \
    -i network-transmit-receive-symbolic 2>/dev/null || true
}

restore_dhcp_dns() {
  echo "nm-dns-toggle: restoring DHCP DNS on «${ACTIVE_CONN}»"
  nmcli connection modify "${ACTIVE_CONN}" ipv4.dns ""
  nmcli connection modify "${ACTIVE_CONN}" ipv4.ignore-auto-dns no
  nmcli connection up "${ACTIVE_CONN}"
  notify-send "nm-dns-toggle" "DHCP DNS restored (${ACTIVE_CONN})" \
    -i network-wired-symbolic 2>/dev/null || true
}

case "${1:-}" in
  on)
    apply_custom_dns
    ;;
  off)
    restore_dhcp_dns
    ;;
  *)
    echo "Usage: $(basename "$0") {on|off}" >&2
    exit 1
    ;;
esac
