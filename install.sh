#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
APP_DIR="${HOME}/.local/share/applications"
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nm-dns-toggle"
CFG_FILE="${CFG_DIR}/config"
SCRIPT_DST="${BIN_DIR}/nm_dns_toggle.sh"

echo "nm-dns-toggle: installing..."

mkdir -p "${BIN_DIR}" "${APP_DIR}" "${CFG_DIR}"
install -m 755 "${ROOT}/nm_dns_toggle.sh" "${SCRIPT_DST}"

if [[ ! -f "${CFG_FILE}" ]]; then
  install -m 644 "${ROOT}/config.example" "${CFG_FILE}"
  echo "nm-dns-toggle: created ${CFG_FILE}"
  echo "  Edit CUSTOM_DNS there, or run: dnsset 1.1.1.1 9.9.9.9"
else
  echo "nm-dns-toggle: keeping existing ${CFG_FILE}"
fi

sed "s|__HOME__|${HOME}|g" "${ROOT}/nm-dns-on.desktop" \
  > "${APP_DIR}/nm-dns-on.desktop"
sed "s|__HOME__|${HOME}|g" "${ROOT}/nm-dns-off.desktop" \
  > "${APP_DIR}/nm-dns-off.desktop"
update-desktop-database "${APP_DIR}" 2>/dev/null || true

BASHRC="${HOME}/.bashrc"
if [[ -f "${BASHRC}" ]]; then
  if ! grep -q "alias dnson=" "${BASHRC}" 2>/dev/null; then
    {
      echo ""
      echo "# nm-dns-toggle"
      echo "alias dnson='${SCRIPT_DST} on'"
      echo "alias dnsoff='${SCRIPT_DST} off'"
      echo "alias dnsst='${SCRIPT_DST} status'"
      echo "alias dnsset='${SCRIPT_DST} set'"
    } >> "${BASHRC}"
  else
    if ! grep -q "alias dnsst=" "${BASHRC}" 2>/dev/null; then
      echo "alias dnsst='${SCRIPT_DST} status'" >> "${BASHRC}"
    fi
    if ! grep -q "alias dnsset=" "${BASHRC}" 2>/dev/null; then
      echo "alias dnsset='${SCRIPT_DST} set'" >> "${BASHRC}"
    fi
  fi
fi

echo "nm-dns-toggle: done."
echo "Config: ${CFG_FILE}"
echo "Run: source ~/.bashrc"
echo "Then: dnson  |  dnsoff  |  dnsst  |  dnsset"
