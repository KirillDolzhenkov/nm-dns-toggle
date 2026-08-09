# nm-dns-toggle

**Lang:** [RU](#ru) · [EN](#en)

## RU

Утилита на Bash, которая меняет DNS у текущего сетевого профиля Linux через NetworkManager. Подходит, когда нужно быстро переключиться на свои резолверы и так же быстро откатить всё обратно. Поддерживает IPv4 и IPv6 и закрывает DNS-утечки по обоим стекам.

### Требования

- Linux с NetworkManager (`nmcli` в PATH)
- интерактивный Bash (`~/.bashrc`)
- по желанию: `notify-send` для всплывающих уведомлений

### Быстрый старт

```bash
git clone https://github.com/KirillDolzhenkov/nm-dns-toggle.git
cd nm-dns-toggle
chmod +x install.sh && ./install.sh
source ~/.bashrc
```

После установки бинарь лежит в `~/.local/bin/nm_dns_toggle.sh`, а в shell появляются короткие команды:

| Команда            | Действие                                         |
|--------------------|--------------------------------------------------|
| `dnson`            | применить DNS из конфига (IPv4 + IPv6)           |
| `dnsoff`           | вернуть DNS по DHCP / auto                       |
| `dnsst`            | статус: custom DNS ON или OFF                    |
| `dnsst -v`         | то же + технические детали                       |
| `dnsset <ip>…`     | записать IPv4/IPv6 в конфиг (без применения)     |
| `dnsset --apply …` | записать в конфиг и сразу применить              |

В меню приложений появятся пункты **NM DNS On** и **NM DNS Off**.

### Свои адреса DNS

Через команду (IPv4 обязателен, IPv6 опционален; адреса распознаются автоматически):

```bash
dnsset 8.8.8.8 8.8.4.4 2001:4860:4860::8888 2001:4860:4860::8844
dnson
# или сразу:
dnsset --apply 8.8.8.8 8.8.4.4 2001:4860:4860::8888 2001:4860:4860::8844
```

Пример Xbox DNS (IPv4 + IPv6):

```bash
dnsset --apply 111.88.96.50 111.88.96.51 2a00:ab00:1233:26::50 2a00:ab00:1233:26::51
```

Или вручную отредактируйте конфиг (создаётся при первом `./install.sh`):

```bash
nano ~/.config/nm-dns-toggle/config
```

```bash
CUSTOM_DNS_IPV4="8.8.8.8 8.8.4.4"
CUSTOM_DNS_IPV6="2001:4860:4860::8888 2001:4860:4860::8844"
```

Если `CUSTOM_DNS_IPV6` пустой, `dnson` **отключает IPv6** на профиле, чтобы запросы не утекали на DNS роутера по v6. IPv4 всегда ставится с `ignore-auto-dns`, чтобы не подмешивался DHCP.

Адреса хранятся в `~/.config/nm-dns-toggle/config`. Повторный `./install.sh` обновит утилиту, но этот файл не перезапишет.

Значения по умолчанию: Google Public DNS (IPv4 `8.8.8.8 8.8.4.4`, IPv6 `2001:4860:4860::8888 2001:4860:4860::8844`).

### Удаление

```bash
chmod +x uninstall.sh
./uninstall.sh          # убрать утилиту; конфиг оставить
./uninstall.sh --purge  # то же + удалить ~/.config/nm-dns-toggle
source ~/.bashrc
```

Сначала вызывается `off` (возврат DHCP), затем удаляются алиасы, бинарь и desktop-ярлыки.

### Дальше по теме

Подробности по работе, проверке и удалению — в [docs/wiki.md](docs/wiki.md#ru).

## EN

A Bash utility that changes DNS on the current Linux network profile via NetworkManager. Handy when you need to switch to your own resolvers quickly and roll everything back just as fast. Supports IPv4 and IPv6 and closes DNS leaks on both stacks.

### Requirements

- Linux with NetworkManager (`nmcli` in PATH)
- interactive Bash (`~/.bashrc`)
- optional: `notify-send` for desktop notifications

### Quick start

```bash
git clone https://github.com/KirillDolzhenkov/nm-dns-toggle.git
cd nm-dns-toggle
chmod +x install.sh && ./install.sh
source ~/.bashrc
```

After install the binary is at `~/.local/bin/nm_dns_toggle.sh`, and short shell commands become available:

| Command            | Action                                           |
|--------------------|--------------------------------------------------|
| `dnson`            | apply DNS from config (IPv4 + IPv6)              |
| `dnsoff`           | restore DNS via DHCP / auto                      |
| `dnsst`            | status: custom DNS ON or OFF                     |
| `dnsst -v`         | same + technical details                         |
| `dnsset <ip>…`     | write IPv4/IPv6 to config (without applying)     |
| `dnsset --apply …` | write to config and apply immediately            |

**NM DNS On** and **NM DNS Off** entries also appear in the application menu.

### Custom DNS addresses

Via command (IPv4 is required, IPv6 is optional; addresses are detected automatically):

```bash
dnsset 8.8.8.8 8.8.4.4 2001:4860:4860::8888 2001:4860:4860::8844
dnson
# or in one step:
dnsset --apply 8.8.8.8 8.8.4.4 2001:4860:4860::8888 2001:4860:4860::8844
```

Xbox DNS example (IPv4 + IPv6):

```bash
dnsset --apply 111.88.96.50 111.88.96.51 2a00:ab00:1233:26::50 2a00:ab00:1233:26::51
```

Or edit the config manually (created on the first `./install.sh`):

```bash
nano ~/.config/nm-dns-toggle/config
```

```bash
CUSTOM_DNS_IPV4="8.8.8.8 8.8.4.4"
CUSTOM_DNS_IPV6="2001:4860:4860::8888 2001:4860:4860::8844"
```

If `CUSTOM_DNS_IPV6` is empty, `dnson` **disables IPv6** on the profile so queries cannot leak to the router DNS over v6. IPv4 is always set with `ignore-auto-dns` so DHCP is not mixed in.

Addresses are stored in `~/.config/nm-dns-toggle/config`. Running `./install.sh` again updates the utility but does not overwrite this file.

Defaults: Google Public DNS (IPv4 `8.8.8.8 8.8.4.4`, IPv6 `2001:4860:4860::8888 2001:4860:4860::8844`).

### Uninstall

```bash
chmod +x uninstall.sh
./uninstall.sh          # remove the utility; keep config
./uninstall.sh --purge  # same + delete ~/.config/nm-dns-toggle
source ~/.bashrc
```

First it runs `off` (restore DHCP), then removes aliases, the binary, and desktop shortcuts.

### Further reading

Details on how it works, verification, and uninstall — in [docs/wiki.md](docs/wiki.md#en).
