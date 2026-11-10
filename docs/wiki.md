# Wiki: nm-dns-toggle

**Lang:** [RU](#ru) · [EN](#en)

## RU

Справка по внутреннему устройству и повседневной эксплуатации.

### Архитектура

Скрипт не поднимает свой сервис. Он один раз за запуск:

1. Читает `CUSTOM_DNS_IPV4` / `CUSTOM_DNS_IPV6` из `~/.config/nm-dns-toggle/config` (если файла нет — встроенные дефолты Google).
2. Находит активный connection profile в NetworkManager (интерфейс `lo` пропускается).
3. В режиме `on`:
   - IPv4: `ipv4.dns` + `ipv4.ignore-auto-dns yes` (без подмешивания DHCP).
   - IPv6 задан: `ipv6.dns` + `ipv6.ignore-auto-dns yes`.
   - IPv6 пуст: `ipv6.method disabled` (закрытие утечки на DNS роутера по v6).
4. В режиме `off`: очищает DNS обоих стеков, `ignore-auto-dns no`, `ipv6.method auto`.
5. Вызывает `nmcli connection up`, чтобы настройки применились сразу.
6. При наличии `notify-send` показывает короткое уведомление о результате.

IPv4 обязателен. IPv6 опционален.

### Режимы

```bash
~/.local/bin/nm_dns_toggle.sh on
~/.local/bin/nm_dns_toggle.sh off
~/.local/bin/nm_dns_toggle.sh status
~/.local/bin/nm_dns_toggle.sh status -v
~/.local/bin/nm_dns_toggle.sh set 8.8.8.8 8.8.4.4 2001:4860:4860::8888 2001:4860:4860::8844
~/.local/bin/nm_dns_toggle.sh set --apply 8.8.8.8 8.8.4.4
```

Эквивалент через алиасы после `install.sh` (по умолчанию в `~/.bashrc` и `~/.zshrc`, если файлы есть; иначе `./install.sh --shell bash|zsh`):

```bash
dnson
dnsoff
dnsst
dnsst -v
dnsset 8.8.8.8 8.8.4.4 2001:4860:4860::8888 2001:4860:4860::8844
dnsset --apply …
```

`dnsset` пишет оба ключа в конфиг (адреса сам раскладывает на IPv4/IPv6). Без IPv6 в аргументах `CUSTOM_DNS_IPV6` будет пустым — при `dnson` IPv6 на профиле отключится.

### Как убедиться, что DNS сменился

```bash
dnsst
dnsst -v
resolvectl dns
```

После `dnson` в `resolvectl dns` не должно быть DNS роутера (`192.168.x.x` / `fe80::…`), если заданы оба стека. Exit code `dnsst` — `0`, если custom DNS активен по политике IPv4+IPv6.

### Частые проблемы

**«no active NetworkManager profile»**  
Нет поднятого Wi‑Fi/Ethernet под NM. Проверьте:

```bash
nmcli connection show --active
```

**Алиасы не находятся**  
Новый терминал или `source ~/.bashrc` / `source ~/.zshrc`. Убедитесь, что в rc вашего shell есть блок `# nm-dns-toggle`.

**Старые desktop-ярлыки**  
Переустановите: `./install.sh`. Файлы лежат в `~/.local/share/applications/nm-dns-*.desktop`.

**Утечка IPv6 (сервис то работает, то нет)**  
Задайте IPv6 DNS в конфиге или оставьте `CUSTOM_DNS_IPV6` пустым — тогда `dnson` отключит IPv6 на профиле.

**Нужен другой профиль, не «первый активный»**  
Сейчас берётся первый non-loopback active connection. Если одновременно активны VPN и Wi‑Fi, убедитесь, что нужный профиль идёт первым в `nmcli connection show --active`, либо временно отключите лишний.

### Удаление

```bash
./uninstall.sh          # убрать утилиту; конфиг оставить
./uninstall.sh --purge  # убрать всё, включая ~/.config/nm-dns-toggle
source ~/.bashrc   # или: source ~/.zshrc
```

Скрипт сам вызывает `off` (вернуть DHCP / auto DNS), затем удаляет алиасы из `~/.bashrc` и `~/.zshrc`, бинарь и desktop-файлы. Каталог проекта (git-клон) не трогается.

## EN

Reference for internals and day-to-day use.

### Architecture

The script does not run its own service. On each invocation it:

1. Reads `CUSTOM_DNS_IPV4` / `CUSTOM_DNS_IPV6` from `~/.config/nm-dns-toggle/config` (if the file is missing — built-in Google defaults).
2. Finds the active NetworkManager connection profile (skips the `lo` interface).
3. In `on` mode:
   - IPv4: `ipv4.dns` + `ipv4.ignore-auto-dns yes` (no DHCP mixing).
   - IPv6 set: `ipv6.dns` + `ipv6.ignore-auto-dns yes`.
   - IPv6 empty: `ipv6.method disabled` (closes the leak to the router DNS over v6).
4. In `off` mode: clears DNS on both stacks, `ignore-auto-dns no`, `ipv6.method auto`.
5. Calls `nmcli connection up` so settings apply immediately.
6. If `notify-send` is available, shows a short result notification.

IPv4 is required. IPv6 is optional.

### Modes

```bash
~/.local/bin/nm_dns_toggle.sh on
~/.local/bin/nm_dns_toggle.sh off
~/.local/bin/nm_dns_toggle.sh status
~/.local/bin/nm_dns_toggle.sh status -v
~/.local/bin/nm_dns_toggle.sh set 8.8.8.8 8.8.4.4 2001:4860:4860::8888 2001:4860:4860::8844
~/.local/bin/nm_dns_toggle.sh set --apply 8.8.8.8 8.8.4.4
```

Equivalent aliases after `install.sh` (by default into `~/.bashrc` and `~/.zshrc` if present; otherwise `./install.sh --shell bash|zsh`):

```bash
dnson
dnsoff
dnsst
dnsst -v
dnsset 8.8.8.8 8.8.4.4 2001:4860:4860::8888 2001:4860:4860::8844
dnsset --apply …
```

`dnsset` writes both keys to the config (it splits addresses into IPv4/IPv6 itself). With no IPv6 in the arguments, `CUSTOM_DNS_IPV6` is empty — on `dnson`, IPv6 on the profile will be disabled.

### How to verify DNS changed

```bash
dnsst
dnsst -v
resolvectl dns
```

After `dnson`, `resolvectl dns` should not show the router DNS (`192.168.x.x` / `fe80::…`) if both stacks are configured. Exit code of `dnsst` is `0` when custom DNS is active per the IPv4+IPv6 policy.

### Common issues

**«no active NetworkManager profile»**  
No Wi‑Fi/Ethernet connection is up under NM. Check:

```bash
nmcli connection show --active
```

**Aliases not found**  
Open a new terminal or run `source ~/.bashrc` / `source ~/.zshrc`. Make sure your shell rc contains the `# nm-dns-toggle` block.

**Stale desktop shortcuts**  
Reinstall: `./install.sh`. Files live in `~/.local/share/applications/nm-dns-*.desktop`.

**IPv6 leak (service works intermittently)**  
Set IPv6 DNS in the config, or leave `CUSTOM_DNS_IPV6` empty — then `dnson` disables IPv6 on the profile.

**Need a different profile, not the «first active» one**  
Currently the first non-loopback active connection is used. If VPN and Wi‑Fi are active at the same time, ensure the desired profile is first in `nmcli connection show --active`, or temporarily disconnect the extra one.

### Uninstall

```bash
./uninstall.sh          # remove the utility; keep config
./uninstall.sh --purge  # remove everything, including ~/.config/nm-dns-toggle
source ~/.bashrc   # or: source ~/.zshrc
```

The script itself runs `off` (restore DHCP / auto DNS), then removes aliases from `~/.bashrc` and `~/.zshrc`, the binary, and desktop files. The project directory (git clone) is left untouched.
