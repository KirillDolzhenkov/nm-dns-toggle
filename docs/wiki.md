# Wiki: nm-dns-toggle

Справка по внутреннему устройству и повседневной эксплуатации.

## Архитектура

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

## Режимы

```bash
~/.local/bin/nm_dns_toggle.sh on
~/.local/bin/nm_dns_toggle.sh off
~/.local/bin/nm_dns_toggle.sh status
~/.local/bin/nm_dns_toggle.sh status -v
~/.local/bin/nm_dns_toggle.sh set 8.8.8.8 8.8.4.4 2001:4860:4860::8888 2001:4860:4860::8844
~/.local/bin/nm_dns_toggle.sh set --apply 8.8.8.8 8.8.4.4
```

Эквивалент через алиасы после `install.sh`:

```bash
dnson
dnsoff
dnsst
dnsst -v
dnsset 8.8.8.8 8.8.4.4 2001:4860:4860::8888 2001:4860:4860::8844
dnsset --apply …
```

`dnsset` пишет оба ключа в конфиг (адреса сам раскладывает на IPv4/IPv6). Без IPv6 в аргументах `CUSTOM_DNS_IPV6` будет пустым — при `dnson` IPv6 на профиле отключится.

## Как убедиться, что DNS сменился

```bash
dnsst
dnsst -v
resolvectl dns
```

После `dnson` в `resolvectl dns` не должно быть DNS роутера (`192.168.x.x` / `fe80::…`), если заданы оба стека. Exit code `dnsst` — `0`, если custom DNS активен по политике IPv4+IPv6.

## Частые проблемы

**«no active NetworkManager profile»**  
Нет поднятого Wi‑Fi/Ethernet под NM. Проверьте:

```bash
nmcli connection show --active
```

**Алиасы не находятся**  
Новый терминал или `source ~/.bashrc`. Убедитесь, что в файле есть блок `# nm-dns-toggle`.

**Старые desktop-ярлыки**  
Переустановите: `./install.sh`. Файлы лежат в `~/.local/share/applications/nm-dns-*.desktop`.

**Утечка IPv6 (сервис то работает, то нет)**  
Задайте IPv6 DNS в конфиге или оставьте `CUSTOM_DNS_IPV6` пустым — тогда `dnson` отключит IPv6 на профиле.

**Нужен другой профиль, не «первый активный»**  
Сейчас берётся первый non-loopback active connection. Если одновременно активны VPN и Wi‑Fi, убедитесь, что нужный профиль идёт первым в `nmcli connection show --active`, либо временно отключите лишний.

## Удаление

```bash
./uninstall.sh          # убрать утилиту; конфиг оставить
./uninstall.sh --purge  # убрать всё, включая ~/.config/nm-dns-toggle
source ~/.bashrc
```

Скрипт сам вызывает `off` (вернуть DHCP / auto DNS), затем удаляет алиасы из `~/.bashrc`, бинарь и desktop-файлы. Каталог проекта (git-клон) не трогается.
