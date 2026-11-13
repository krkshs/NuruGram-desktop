# NuruGram Desktop

Приватный Telegram Desktop для сервера **31.77.17.214:443**.

Готовый переносной клиент: `Telegram.exe` в локальной папке клиента; готовый exe опубликован в GitHub Releases. Его версия указана в `Telegram.exe.manifest.json`. Исходники Telegram Desktop находятся в `Telegram/`; готовый клиент сейчас основан на официальном 7.4.2, исходники ветки dev — на 7.4.3. Встроенные DC и RSA публичные ключи настроены для приватного сервера. Публичный ключ опубликован в `tools/private-client/server-public.pem`.

## Получение клиента

```powershell
git clone https://github.com/krkshs/NuruGram-desktop.git

```

Скачайте `Telegram.exe` из [последнего релиза](https://github.com/krkshs/NuruGram-desktop/releases/latest) в папку репозитория. Запускайте `Telegram.exe`. Личные данные хранятся только локально в `tdata`.

## Обновление готового клиента

Сохраните новую официальную Windows-сборку Telegram Desktop отдельно, затем из корня репозитория выполните:

```powershell
pwsh -NoProfile -File tools/private-client/Update-Client.ps1 -OriginalExe C:\Downloads\Telegram\Telegram.exe
```

Скрипт заменит DC/IP и публичные RSA ключи, проверит размеры бинарных полей, создаст manifest с SHA-256 и отправит исходники и manifest в ветку `dev`, а exe — в GitHub Releases. Предыдущий exe сохраняется в `.git/client-backups`. Если файл заблокирован, закройте только этот переносной клиент и повторите команду. Аккаунты не сбрасываются. Для запуска новой версии перезапустите клиент.

Штатное обновление с серверов Telegram отключено, чтобы сохранять приватные DC и ключи. Новые версии устанавливаются командой выше.

## Автоматическая отправка изменений в GitHub

```powershell
pwsh -NoProfile -File tools/private-client/Install-GitSync.ps1
```

Задача Windows `NuruGram Desktop Git Sync` запускается при входе пользователя и работает скрыто. После завершения записи файлов изменения уже отслеживаемых исходников, скриптов, exe и manifest автоматически коммитятся и отправляются в `origin/dev`; обычно это занимает до 90 секунд. Для новых файлов сначала используйте `git add`. Лог: `.git/nurugram-sync.log`.

Однократная отправка: `pwsh -NoProfile -File tools/private-client/Sync-Client.ps1`. Требуются Git, PowerShell 7 и доступ на запись в репозиторий; для подготовки exe требуется .NET 10 SDK. Скрипт использует установленный Git Credential Manager и не сохраняет токены в репозитории. При ошибке сети отправка повторяется. Чужие изменения в удалённой ветке и вручную подготовленный индекс требуют обычного завершения работы с Git; автоматическая отправка не переписывает историю.

Отключение: `Stop-ScheduledTask -TaskName 'NuruGram Desktop Git Sync'`, затем `Unregister-ScheduledTask -TaskName 'NuruGram Desktop Git Sync'`.

## Существующие настройки DC

Если старая переносная копия продолжает подключаться к прежнему адресу, в Settings наберите `endpoints` и импортируйте `NuruGram.tdesktop-endpoints`. Повторите для каждого сохранённого аккаунта. Пользовательские настройки и сессии не включены в Git.

Оригинальная документация Telegram Desktop: [README](README.md). Лицензия: [GPLv3](LICENSE).
