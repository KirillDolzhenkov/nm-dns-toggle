#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
APP_DIR="${HOME}/.local/share/applications"
SCRIPT_DST="${BIN_DIR}/nm_dns_toggle.sh"

echo "nm-dns-toggle: installing..."

mkdir -p "${BIN_DIR}" "${APP_DIR}"
install -m 755 "${ROOT}/nm_dns_toggle.sh" "${SCRIPT_DST}"

sed "s|__HOME__|${HOME}|g" "${ROOT}/nm-dns-on.desktop" \
  > "${APP_DIR}/nm-dns-on.desktop"
sed "s|__HOME__|${HOME}|g" "${ROOT}/nm-dns-off.desktop" \
  > "${APP_DIR}/nm-dns-off.desktop"
update-desktop-database "${APP_DIR}" 2>/dev/null || true

BASHRC="${HOME}/.bashrc"
if [[ -f "${BASHRC}" ]] && ! grep -q "alias dnson=" "${BASHRC}" 2>/dev/null; then
  {
    echo ""
    echo "# nm-dns-toggle"
    echo "alias dnson='${SCRIPT_DST} on'"
    echo "alias dnsoff='${SCRIPT_DST} off'"
  } >> "${BASHRC}"
fi

echo "nm-dns-toggle: done."
echo "Run: source ~/.bashrc"
echo "Then: dnson  |  dnsoff"
