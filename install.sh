#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
APP_DIR="${HOME}/.local/share/applications"
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nm-dns-toggle"
CFG_FILE="${CFG_DIR}/config"
SCRIPT_DST="${BIN_DIR}/nm_dns_toggle.sh"
BASHRC="${HOME}/.bashrc"
ZSHRC="${HOME}/.zshrc"

SHELL_TARGET="both"

usage() {
  echo "Usage: $(basename "$0") [--shell bash|zsh|both]"
  echo "  --shell both  (default) write aliases to ~/.bashrc and ~/.zshrc if they exist"
  echo "  --shell bash  only ~/.bashrc"
  echo "  --shell zsh   only ~/.zshrc"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --shell)
      if [[ $# -lt 2 ]]; then
        echo "nm-dns-toggle: --shell requires bash|zsh|both" >&2
        usage >&2
        exit 1
      fi
      case "$2" in
        bash|zsh|both) SHELL_TARGET="$2" ;;
        *)
          echo "nm-dns-toggle: invalid --shell value: $2" >&2
          usage >&2
          exit 1
          ;;
      esac
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "nm-dns-toggle: unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

# Returns 0 if aliases are present in the rc file after ensure.
ensure_aliases() {
  local rcfile="$1"
  if [[ ! -f "${rcfile}" ]]; then
    return 1
  fi
  if ! grep -q "alias dnson=" "${rcfile}" 2>/dev/null; then
    {
      echo ""
      echo "# nm-dns-toggle"
      echo "alias dnson='${SCRIPT_DST} on'"
      echo "alias dnsoff='${SCRIPT_DST} off'"
      echo "alias dnsst='${SCRIPT_DST} status'"
      echo "alias dnsset='${SCRIPT_DST} set'"
    } >> "${rcfile}"
    echo "nm-dns-toggle: aliases added to ${rcfile}"
  else
    if ! grep -q "alias dnsst=" "${rcfile}" 2>/dev/null; then
      echo "alias dnsst='${SCRIPT_DST} status'" >> "${rcfile}"
    fi
    if ! grep -q "alias dnsset=" "${rcfile}" 2>/dev/null; then
      echo "alias dnsset='${SCRIPT_DST} set'" >> "${rcfile}"
    fi
    echo "nm-dns-toggle: aliases already present in ${rcfile}"
  fi
  return 0
}

echo "nm-dns-toggle: installing..."

mkdir -p "${BIN_DIR}" "${APP_DIR}" "${CFG_DIR}"
install -m 755 "${ROOT}/nm_dns_toggle.sh" "${SCRIPT_DST}"

if [[ ! -f "${CFG_FILE}" ]]; then
  install -m 644 "${ROOT}/config.example" "${CFG_FILE}"
  echo "nm-dns-toggle: created ${CFG_FILE}"
  echo "  Edit CUSTOM_DNS_IPV4 / CUSTOM_DNS_IPV6, or run: dnsset 8.8.8.8 8.8.4.4 …"
else
  echo "nm-dns-toggle: keeping existing ${CFG_FILE}"
fi

sed "s|__HOME__|${HOME}|g" "${ROOT}/nm-dns-on.desktop" \
  > "${APP_DIR}/nm-dns-on.desktop"
sed "s|__HOME__|${HOME}|g" "${ROOT}/nm-dns-off.desktop" \
  > "${APP_DIR}/nm-dns-off.desktop"
update-desktop-database "${APP_DIR}" 2>/dev/null || true

SOURCED_HINTS=()
case "${SHELL_TARGET}" in
  bash)
    if ensure_aliases "${BASHRC}"; then
      SOURCED_HINTS+=("source ${BASHRC}")
    else
      echo "nm-dns-toggle: skipped ${BASHRC} (file not found)"
    fi
    ;;
  zsh)
    if ensure_aliases "${ZSHRC}"; then
      SOURCED_HINTS+=("source ${ZSHRC}")
    else
      echo "nm-dns-toggle: skipped ${ZSHRC} (file not found)"
    fi
    ;;
  both)
    if ensure_aliases "${BASHRC}"; then
      SOURCED_HINTS+=("source ${BASHRC}")
    else
      echo "nm-dns-toggle: skipped ${BASHRC} (file not found)"
    fi
    if ensure_aliases "${ZSHRC}"; then
      SOURCED_HINTS+=("source ${ZSHRC}")
    else
      echo "nm-dns-toggle: skipped ${ZSHRC} (file not found)"
    fi
    ;;
esac

if (( ${#SOURCED_HINTS[@]} == 0 )); then
  echo "nm-dns-toggle: warning: no shell rc updated — add aliases manually or create ~/.bashrc / ~/.zshrc" >&2
fi

echo "nm-dns-toggle: done."
echo "Config: ${CFG_FILE}"
if (( ${#SOURCED_HINTS[@]} > 0 )); then
  echo "Run: ${SOURCED_HINTS[*]}"
fi
echo "Then: dnson  |  dnsoff  |  dnsst  |  dnsset"
