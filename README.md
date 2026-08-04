# nm-dns-toggle

Утилита на Bash, которая меняет DNS у текущего сетевого профиля Linux через NetworkManager. Подходит, когда нужно быстро переключиться на свои резолверы и так же быстро откатить всё обратно.

## Требования

- Linux с NetworkManager (`nmcli` в PATH)
- интерактивный Bash (`~/.bashrc`)
- по желанию: `notify-send` для всплывающих уведомлений

## Быстрый старт

```bash
git clone https://github.com/KirillDolzhenkov/nm-dns-toggle.git
cd nm-dns-toggle
chmod +x install.sh && ./install.sh
source ~/.bashrc
```

После установки бинарь лежит в `~/.local/bin/nm_dns_toggle.sh`, а в shell появляются короткие команды:

| Команда           | Действие                                      |
|-------------------|-----------------------------------------------|
| `dnson`           | применить адреса из `CUSTOM_DNS`              |
| `dnsoff`          | вернуть DNS, выданный по DHCP                 |
| `dnsst`           | понятный статус: custom DNS ON или OFF        |
| `dnsst -v`        | то же + технические детали (профиль, nmcli)   |
| `dnsset <ip>…`    | записать адреса в конфиг (без применения)     |
| `dnsset --apply …`| записать в конфиг и сразу применить           |

В меню приложений появятся пункты **NM DNS On** и **NM DNS Off**.

## Свои адреса DNS

Через команду:

```bash
dnsset 1.1.1.1 9.9.9.9
dnson
# или сразу:
dnsset --apply 1.1.1.1 9.9.9.9
```

Или вручную отредактируйте конфиг (создаётся при первом `./install.sh`):

```bash
nano ~/.config/nm-dns-toggle/config
```

```bash
CUSTOM_DNS="1.1.1.1 9.9.9.9"
```

Адреса хранятся в `~/.config/nm-dns-toggle/config`. Повторный `./install.sh` обновит утилиту, но этот файл не перезапишет.

Значения по умолчанию: `8.8.8.8 8.8.4.4` (Google Public DNS).

## Дальше по теме

Подробности по работе, проверке и снятию установки — в [docs/wiki.md](docs/wiki.md).
