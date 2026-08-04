#!/usr/bin/env bash
set -euo pipefail

# Custom resolvers applied when mode=on (space-separated)
CUSTOM_DNS="111.88.96.50 111.88.96.51"

resolve_active_conn() {
  nmcli -t -f NAME,DEVICE connection show --active \
    | awk -F: '$2 != "lo" && $2 != "" { print $1; exit }'
}

normalize_dns() {
  # Collapse commas/whitespace to a single space-separated list
  echo "$1" | tr ',;' '  ' | xargs
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

show_status() {
  local verbose="${1:-}"
  local configured ignore_auto device effective custom_active expected
  local dns_in_use state_label source_label tip
  local -a fields

  case "${verbose}" in
    "" ) ;;
    -v|--verbose) verbose=1 ;;
    *)
      echo "Usage: $(basename "$0") status [-v|--verbose]" >&2
      exit 1
      ;;
  esac

  mapfile -t fields < <(nmcli -g ipv4.dns,ipv4.ignore-auto-dns connection show "${ACTIVE_CONN}")
  configured="$(normalize_dns "${fields[0]:-}")"
  ignore_auto="${fields[1]:-}"

  device="$(nmcli -g connection.interface-name connection show "${ACTIVE_CONN}" 2>/dev/null || true)"
  if [[ -n "${device}" ]]; then
    effective="$(
      nmcli -t -f IP4.DNS device show "${device}" 2>/dev/null \
        | awk -F: '{ print $2 }' \
        | tr '\n' ' ' \
        | xargs
    )"
  else
    effective=""
  fi

  expected="$(normalize_dns "${CUSTOM_DNS}")"
  if [[ "${ignore_auto}" == "yes" && "${configured}" == "${expected}" ]]; then
    custom_active="true"
    state_label="ON"
    source_label="your custom list"
    tip="Tip: run  dnsoff  to restore router DNS"
  else
    custom_active="false"
    state_label="OFF"
    source_label="router / DHCP"
    tip="Tip: run  dnson  to enable your custom DNS"
  fi

  if [[ -n "${effective}" ]]; then
    dns_in_use="${effective}"
  elif [[ -n "${configured}" ]]; then
    dns_in_use="${configured}"
  else
    dns_in_use="(unknown)"
  fi

  echo "Custom DNS: ${state_label}"
  echo "Network: ${ACTIVE_CONN}"
  echo "DNS in use: ${dns_in_use} (${source_label})"
  echo ""
  echo "${tip}"

  if [[ -n "${verbose}" ]]; then
    echo ""
    echo "---"
    echo "custom: ${custom_active}"
    echo "connection: ${ACTIVE_CONN}"
    echo "configured: ${configured:-"(none)"}"
    echo "ignore-auto-dns: ${ignore_auto:-"(unknown)"}"
    echo "effective: ${effective:-"(none)"}"
  fi

  if [[ "${custom_active}" == "true" ]]; then
    return 0
  fi
  return 1
}

case "${1:-}" in
  on)
    apply_custom_dns
    ;;
  off)
    restore_dhcp_dns
    ;;
  status)
    show_status "${2:-}"
    ;;
  *)
    echo "Usage: $(basename "$0") {on|off|status [-v]}" >&2
    exit 1
    ;;
esac
