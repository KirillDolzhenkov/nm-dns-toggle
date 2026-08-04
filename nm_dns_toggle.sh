#!/usr/bin/env bash
set -euo pipefail

# Defaults; override via ~/.config/nm-dns-toggle/config
CUSTOM_DNS_IPV4="8.8.8.8 8.8.4.4"
CUSTOM_DNS_IPV6="2001:4860:4860::8888 2001:4860:4860::8844"

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/nm-dns-toggle/config"
if [[ -f "${CONFIG_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${CONFIG_FILE}"
fi

normalize_dns() {
  local s="${1:-}"
  [[ -z "${s// }" ]] && { echo ""; return 0; }
  echo "$s" | tr ',;' '  ' | xargs
}

# Back-compat: legacy CUSTOM_DNS → CUSTOM_DNS_IPV4
if [[ -z "${CUSTOM_DNS_IPV4:-}" && -n "${CUSTOM_DNS:-}" ]]; then
  CUSTOM_DNS_IPV4="${CUSTOM_DNS}"
fi
CUSTOM_DNS_IPV4="$(normalize_dns "${CUSTOM_DNS_IPV4:-}")"
CUSTOM_DNS_IPV6="$(normalize_dns "${CUSTOM_DNS_IPV6:-}")"

resolve_active_conn() {
  nmcli -t -f NAME,DEVICE connection show --active \
    | awk -F: '$2 != "lo" && $2 != "" { print $1; exit }'
}

require_ipv4_dns() {
  if [[ -z "${CUSTOM_DNS_IPV4// }" ]]; then
    echo "nm-dns-toggle: CUSTOM_DNS_IPV4 is empty (check ${CONFIG_FILE})" >&2
    echo "Hint: dnsset 8.8.8.8 8.8.4.4   # IPv4 required; IPv6 optional" >&2
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

is_ipv6() {
  local ip="$1"
  # Dotted quads are IPv4; IPv6 must contain ':' and only hex/colon
  [[ "${ip}" == *.* ]] && return 1
  [[ "${ip}" == *:* ]] || return 1
  [[ "${ip}" =~ ^[0-9A-Fa-f:]+$ ]]
}

apply_custom_dns() {
  echo "nm-dns-toggle: enabling custom IPv4 DNS (${CUSTOM_DNS_IPV4}) on «${ACTIVE_CONN}»"
  nmcli connection modify "${ACTIVE_CONN}" ipv4.dns "${CUSTOM_DNS_IPV4}"
  nmcli connection modify "${ACTIVE_CONN}" ipv4.ignore-auto-dns yes

  if [[ -n "${CUSTOM_DNS_IPV6// }" ]]; then
    echo "nm-dns-toggle: enabling custom IPv6 DNS (${CUSTOM_DNS_IPV6})"
    nmcli connection modify "${ACTIVE_CONN}" ipv6.method auto
    nmcli connection modify "${ACTIVE_CONN}" ipv6.dns "${CUSTOM_DNS_IPV6}"
    nmcli connection modify "${ACTIVE_CONN}" ipv6.ignore-auto-dns yes
  else
    echo "nm-dns-toggle: CUSTOM_DNS_IPV6 empty — disabling IPv6 to prevent DNS leak"
    nmcli connection modify "${ACTIVE_CONN}" ipv6.dns ""
    nmcli connection modify "${ACTIVE_CONN}" ipv6.ignore-auto-dns yes
    nmcli connection modify "${ACTIVE_CONN}" ipv6.method disabled
  fi

  nmcli connection up "${ACTIVE_CONN}"
  notify-send "nm-dns-toggle" "Custom DNS active (${ACTIVE_CONN})" \
    -i network-transmit-receive-symbolic 2>/dev/null || true
}

restore_dhcp_dns() {
  echo "nm-dns-toggle: restoring DHCP DNS on «${ACTIVE_CONN}»"
  nmcli connection modify "${ACTIVE_CONN}" ipv4.dns ""
  nmcli connection modify "${ACTIVE_CONN}" ipv4.ignore-auto-dns no
  nmcli connection modify "${ACTIVE_CONN}" ipv6.dns ""
  nmcli connection modify "${ACTIVE_CONN}" ipv6.ignore-auto-dns no
  nmcli connection modify "${ACTIVE_CONN}" ipv6.method auto
  nmcli connection up "${ACTIVE_CONN}"
  notify-send "nm-dns-toggle" "DHCP DNS restored (${ACTIVE_CONN})" \
    -i network-wired-symbolic 2>/dev/null || true
}

write_config() {
  local v4="$1"
  local v6="$2"
  mkdir -p "$(dirname "${CONFIG_FILE}")"
  cat > "${CONFIG_FILE}" <<EOF
# Managed by nm-dns-toggle (dnsset).
# IPv4 required. IPv6 optional — if empty, dnson disables IPv6 to avoid DNS leaks.
CUSTOM_DNS_IPV4="${v4}"
CUSTOM_DNS_IPV6="${v6}"
EOF
}

set_custom_dns() {
  local apply=0
  local -a v4s=() v6s=()
  local arg

  for arg in "$@"; do
    case "${arg}" in
      --apply)
        apply=1
        ;;
      -*)
        echo "Usage: $(basename "$0") set [--apply] <ipv4…> [ipv6…]" >&2
        exit 1
        ;;
      *)
        if is_ipv4 "${arg}"; then
          v4s+=("${arg}")
        elif is_ipv6 "${arg}"; then
          v6s+=("${arg}")
        else
          echo "nm-dns-toggle: not a valid IPv4/IPv6 address: ${arg}" >&2
          exit 1
        fi
        ;;
    esac
  done

  if (( ${#v4s[@]} == 0 )); then
    echo "nm-dns-toggle: at least one IPv4 address is required" >&2
    echo "Usage: $(basename "$0") set [--apply] <ipv4…> [ipv6…]" >&2
    exit 1
  fi

  CUSTOM_DNS_IPV4="${v4s[*]}"
  CUSTOM_DNS_IPV6="${v6s[*]}"
  write_config "${CUSTOM_DNS_IPV4}" "${CUSTOM_DNS_IPV6}"

  echo "nm-dns-toggle: saved to ${CONFIG_FILE}"
  echo "  CUSTOM_DNS_IPV4=\"${CUSTOM_DNS_IPV4}\""
  echo "  CUSTOM_DNS_IPV6=\"${CUSTOM_DNS_IPV6:-}\""

  if (( apply )); then
    require_active_conn
    apply_custom_dns
  else
    echo "Tip: run  dnson  to apply these resolvers (or: dnsset --apply …)"
  fi
}

show_status() {
  local verbose="${1:-}"
  local v4_dns v4_ignore v6_dns v6_ignore v6_method
  local device eff4 eff6
  local expected4 expected6
  local v4_ok=0 v6_ok=0 custom_active
  local state_label tip
  local -a fields

  case "${verbose}" in
    "" ) ;;
    -v|--verbose) verbose=1 ;;
    *)
      echo "Usage: $(basename "$0") status [-v|--verbose]" >&2
      exit 1
      ;;
  esac

  mapfile -t fields < <(nmcli -g ipv4.dns,ipv4.ignore-auto-dns,ipv6.dns,ipv6.ignore-auto-dns,ipv6.method connection show "${ACTIVE_CONN}")
  v4_dns="$(normalize_dns "${fields[0]:-}")"
  v4_ignore="${fields[1]:-}"
  v6_dns="$(normalize_dns "${fields[2]:-}")"
  v6_ignore="${fields[3]:-}"
  v6_method="${fields[4]:-}"

  device="$(nmcli -g connection.interface-name connection show "${ACTIVE_CONN}" 2>/dev/null || true)"
  if [[ -n "${device}" ]]; then
    eff4="$(
      nmcli -t -f IP4.DNS device show "${device}" 2>/dev/null \
        | sed 's/^[^:]*://' | tr '\n' ' ' | xargs || true
    )"
    eff6="$(
      nmcli -t -f IP6.DNS device show "${device}" 2>/dev/null \
        | sed 's/^[^:]*://' | tr '\n' ' ' | xargs || true
    )"
  else
    eff4=""
    eff6=""
  fi

  expected4="$(normalize_dns "${CUSTOM_DNS_IPV4}")"
  expected6="$(normalize_dns "${CUSTOM_DNS_IPV6}")"

  if [[ "${v4_ignore}" == "yes" && "${v4_dns}" == "${expected4}" ]]; then
    v4_ok=1
  fi

  if [[ -n "${CUSTOM_DNS_IPV6// }" ]]; then
    if [[ "${v6_ignore}" == "yes" && "${v6_dns}" == "${expected6}" && "${v6_method}" != "disabled" ]]; then
      v6_ok=1
    fi
  else
    if [[ "${v6_method}" == "disabled" ]]; then
      v6_ok=1
    fi
  fi

  if (( v4_ok && v6_ok )); then
    custom_active="true"
    state_label="ON"
    tip="Tip: run  dnsoff  to restore router DNS"
  else
    custom_active="false"
    state_label="OFF"
    tip="Tip: run  dnson  to enable your custom DNS"
  fi

  echo "Custom DNS: ${state_label}"
  echo "Network: ${ACTIVE_CONN}"
  echo "IPv4 DNS: ${eff4:-${v4_dns:-(none)}}"
  if [[ -n "${CUSTOM_DNS_IPV6// }" ]]; then
    echo "IPv6 DNS: ${eff6:-${v6_dns:-(none)}}"
  else
    echo "IPv6: disabled (no CUSTOM_DNS_IPV6)"
  fi
  echo ""
  echo "${tip}"

  if [[ -n "${verbose}" ]]; then
    echo ""
    echo "---"
    echo "custom: ${custom_active}"
    echo "connection: ${ACTIVE_CONN}"
    echo "ipv4.configured: ${v4_dns:-(none)}"
    echo "ipv4.ignore-auto-dns: ${v4_ignore:-(unknown)}"
    echo "ipv4.effective: ${eff4:-(none)}"
    echo "ipv6.configured: ${v6_dns:-(none)}"
    echo "ipv6.ignore-auto-dns: ${v6_ignore:-(unknown)}"
    echo "ipv6.method: ${v6_method:-(unknown)}"
    echo "ipv6.effective: ${eff6:-(none)}"
    echo "config.ipv4: ${expected4:-(none)}"
    echo "config.ipv6: ${expected6:-(none)}"
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
    require_ipv4_dns
    require_active_conn
    apply_custom_dns
    ;;
  off)
    require_active_conn
    restore_dhcp_dns
    ;;
  status)
    require_ipv4_dns
    require_active_conn
    show_status "${2:-}"
    ;;
  *)
    echo "Usage: $(basename "$0") {on|off|status [-v]|set [--apply] <ipv4…> [ipv6…]}" >&2
    exit 1
    ;;
esac
