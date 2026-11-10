#!/usr/bin/env bash
set -euo pipefail

BIN_DIR="${HOME}/.local/bin"
APP_DIR="${HOME}/.local/share/applications"
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nm-dns-toggle"
SCRIPT_DST="${BIN_DIR}/nm_dns_toggle.sh"
BASHRC="${HOME}/.bashrc"
ZSHRC="${HOME}/.zshrc"

PURGE=0
for arg in "$@"; do
  case "${arg}" in
    --purge) PURGE=1 ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--purge]"
      echo "  (default)  remove tool; keep ${CFG_DIR}"
      echo "  --purge    also delete ${CFG_DIR}"
      exit 0
      ;;
    *)
      echo "Usage: $(basename "$0") [--purge]" >&2
      exit 1
      ;;
  esac
done

remove_aliases() {
  local rcfile="$1"
  if [[ ! -f "${rcfile}" ]]; then
    return 1
  fi
  local tmp
  tmp="$(mktemp)"
  awk '
    /^# nm-dns-toggle$/ { next }
    /^alias dnson=/ { next }
    /^alias dnsoff=/ { next }
    /^alias dnsst=/ { next }
    /^alias dnsset=/ { next }
    { print }
  ' "${rcfile}" > "${tmp}"
  mv "${tmp}" "${rcfile}"
  echo "nm-dns-toggle: removed aliases from ${rcfile}"
  return 0
}

echo "nm-dns-toggle: uninstalling..."

if [[ -x "${SCRIPT_DST}" ]]; then
  echo "nm-dns-toggle: restoring DHCP DNS (off)..."
  if ! "${SCRIPT_DST}" off; then
    echo "nm-dns-toggle: warning: could not run off — DNS profile may still be custom" >&2
  fi
else
  echo "nm-dns-toggle: installed script not found — skipping off"
fi

SOURCED_HINTS=()
if remove_aliases "${BASHRC}"; then
  SOURCED_HINTS+=("source ${BASHRC}")
fi
if remove_aliases "${ZSHRC}"; then
  SOURCED_HINTS+=("source ${ZSHRC}")
fi

rm -f "${SCRIPT_DST}"
rm -f "${APP_DIR}/nm-dns-on.desktop" "${APP_DIR}/nm-dns-off.desktop"
update-desktop-database "${APP_DIR}" 2>/dev/null || true
echo "nm-dns-toggle: removed binary and desktop entries"

if (( PURGE )); then
  rm -rf "${CFG_DIR}"
  echo "nm-dns-toggle: removed config ${CFG_DIR}"
else
  echo "nm-dns-toggle: config kept at ${CFG_DIR}"
  echo "  Remove manually: rm -rf ${CFG_DIR}"
  echo "  Or re-run: ./uninstall.sh --purge"
fi

echo "nm-dns-toggle: done."
if (( ${#SOURCED_HINTS[@]} > 0 )); then
  echo "Run: ${SOURCED_HINTS[*]}   (or open a new terminal)"
else
  echo "Open a new terminal (or source your shell rc)"
fi
