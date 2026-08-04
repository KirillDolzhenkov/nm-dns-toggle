#!/usr/bin/env bash
set -euo pipefail

# Defaults; override via ~/.config/nm-dns-toggle/config
CUSTOM_DNS="8.8.8.8 8.8.4.4"

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/nm-dns-toggle/config"
if [[ -f "${CONFIG_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${CONFIG_FILE}"
fi

resolve_active_conn() {
  nmcli -t -f NAME,DEVICE connection show --active \
    | awk -F: '$2 != "lo" && $2 != "" { print $1; exit }'
}

normalize_dns() {
  # Collapse commas/whitespace to a single space-separated list
  echo "$1" | tr ',;' '  ' | xargs
}

require_custom_dns() {
  if [[ -z "${CUSTOM_DNS// }" ]]; then
    echo "nm-dns-toggle: CUSTOM_DNS is empty (check ${CONFIG_FILE})" >&2
    exit 1
  fi
}

require_active_conn() {
  ACTIVE_CONN="$(resolve_active_conn || true)"
  if [[ -z "${ACTIVE_CONN}" ]]; then
    echo "nm-dns-toggle: no active NetworkManager profile found." >&2
    echo "Hint: nmcli connection show --active" >&2
    exit 1
  fi
}

is_ipv4() {
  local ip="$1"
  local o1 o2 o3 o4
  [[ "${ip}" =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]] || return 1
  o1="${BASH_REMATCH[1]}"
  o2="${BASH_REMATCH[2]}"
  o3="${BASH_REMATCH[3]}"
  o4="${BASH_REMATCH[4]}"
  (( o1 <= 255 && o2 <= 255 && o3 <= 255 && o4 <= 255 ))
}

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

set_custom_dns() {
  local apply=0
  local -a ips=()
  local arg ip joined

  for arg in "$@"; do
    case "${arg}" in
      --apply)
        apply=1
        ;;
      -*)
        echo "Usage: $(basename "$0") set [--apply] <ipv4> [ipv4…]" >&2
        exit 1
        ;;
      *)
        if ! is_ipv4 "${arg}"; then
          echo "nm-dns-toggle: not a valid IPv4 address: ${arg}" >&2
          exit 1
        fi
        ips+=("${arg}")
        ;;
    esac
  done

  if (( ${#ips[@]} == 0 )); then
    echo "Usage: $(basename "$0") set [--apply] <ipv4> [ipv4…]" >&2
    exit 1
  fi

  joined="${ips[*]}"
  mkdir -p "$(dirname "${CONFIG_FILE}")"
  cat > "${CONFIG_FILE}" <<EOF
# Managed by nm-dns-toggle (dnsset). Space-separated IPv4 resolvers.
CUSTOM_DNS="${joined}"
EOF

  CUSTOM_DNS="${joined}"
  echo "nm-dns-toggle: saved CUSTOM_DNS=\"${CUSTOM_DNS}\" to ${CONFIG_FILE}"

  if (( apply )); then
    require_active_conn
    apply_custom_dns
  else
    echo "Tip: run  dnson  to apply these resolvers (or: dnsset --apply …)"
  fi
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
  set)
    shift
    set_custom_dns "$@"
    ;;
  on)
    require_custom_dns
    require_active_conn
    apply_custom_dns
    ;;
  off)
    require_custom_dns
    require_active_conn
    restore_dhcp_dns
    ;;
  status)
    require_custom_dns
    require_active_conn
    show_status "${2:-}"
    ;;
  *)
    echo "Usage: $(basename "$0") {on|off|status [-v]|set [--apply] <ip>…}" >&2
    exit 1
    ;;
esac
