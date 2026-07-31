# Wiki: nm-dns-toggle

Справка по внутреннему устройству и повседневной эксплуатации.

## Архитектура

Скрипт не поднимает свой сервис. Он один раз за запуск:

1. Находит активный connection profile в NetworkManager (интерфейс `lo` пропускается).
2. В режиме `on` записывает список IP в `ipv4.dns` и запрещает подмешивание DNS от DHCP (`ipv4.ignore-auto-dns yes`).
3. В режиме `off` очищает `ipv4.dns` и снова разрешает auto-dns.
4. Вызывает `nmcli connection up`, чтобы настройки применились сразу.
5. При наличии `notify-send` показывает короткое уведомление о результате.

Имя профиля хранится во внутренней переменной `ACTIVE_CONN`, список резолверов — в `CUSTOM_DNS`.

## Режимы

```bash
~/.local/bin/nm_dns_toggle.sh on
~/.local/bin/nm_dns_toggle.sh off
```

Эквивалент через алиасы после `install.sh`:

```bash
dnson
dnsoff
```

## Как убедиться, что DNS сменился

```bash
nmcli -f GENERAL.CONNECTION,IP4.DNS device show
```

Альтернатива на системах с systemd-resolved:

```bash
resolvectl dns
resolvectl status
```

В выводе после `dnson` должны быть адреса из `CUSTOM_DNS`. После `dnsoff` обычно снова видны адреса роутера/провайдера.

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

**Нужен другой профиль, не «первый активный»**  
Сейчас берётся первый non-loopback active connection. Если одновременно активны VPN и Wi‑Fi, убедитесь, что нужный профиль идёт первым в `nmcli connection show --active`, либо временно отключите лишний.

## Снятие установки

1. Удалите из `~/.bashrc` строки с `# nm-dns-toggle`, `dnson` и `dnsoff`.
2. Удалите `~/.local/bin/nm_dns_toggle.sh`.
3. Удалите `~/.local/share/applications/nm-dns-on.desktop` и `nm-dns-off.desktop`.
4. При необходимости верните DHCP: `dnsoff` (до удаления скрипта) или руками через `nmcli`.
