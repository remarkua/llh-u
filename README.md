# little linux help unit (llh-u)

# На данном этапе происходит тестирование и скрипт не несет никакой практической ценности!

`llh-u` — это Bash-скрипт для администрирования Debian-подобных операционных систем, разработанный предназначен для упрощения некоторых рутинных задач системного администрирования на Debian-подобных операционных системах. Он предлагает модульную структуру, централизованное логирование, поддержку многоязычного интерфейса и механизм автоматического обновления.

## Основные Возможности

* **Модульная Архитектура:** Разделение функционала на независимые модули (управление пакетами, службами, сетью и т.д.), обеспечивающее легкое расширение и поддержку.

* **Локализация:** Поддержка различных языков интерфейса с возможностью переключения.

* **Централизованное Логирование:** Детальные логи с настраиваемым уровнем детализации и автоматической ротацией.

* **Автоматическое Обновление:** Скрипт может проверять наличие новых версий и обновляться самостоятельно.

* **Интерактивный Интерфейс:** Удобное текстовое меню на базе `whiptail` для интуитивного взаимодействия.

* **Автоматическое Управление Зависимостями:** Проверка и установка необходимых системных пакетов.

* **Безопасный Запуск:** Защита от запуска с правами `root` и проверка членства пользователя в группе `sudo`.

## Установка и Первый Запуск

Скрипт `llh-u` предназначен для автоматического развертывания в системную директорию при первом запуске.

1.  **Скачайте основной скрипт и все модули локально:**

    Для удобства, вы можете скачать все необходимые файлы напрямую из репозитория в вашу текущую директорию:

    ```bash
    wget https://raw.githubusercontent.com/remarkua/llh-u/main/llh-u.sh \
    https://raw.githubusercontent.com/remarkua/llh-u/main/llh-u-packages.sh \
    https://raw.githubusercontent.com/remarkua/llh-u/main/llh-u-test-01.sh
    ```

    ```bash
    chmod +x llh-u.sh
    ```

    **Важное примечание**
    Для первого запуска/инициализации скрипта не используйте команду вида `bash -c "$(wget -qO- ...)"`.
    Скрипт должен быть скачан на диск и запущен как локальный файл (например, `./llh-u.sh`), чтобы его механизм бутреппинга сработал корректно.

2.  **Запустите скрипт:**

    При первом запуске скрипт автоматически скопирует себя и все необходимые файлы в `/opt/userscript/llh-u/` и перезапустится из этой директории.

    ```bash
    ./llh-u.sh
    ```

    При первом запуске вам будет предложено выбрать язык интерфейса и уровень логирования.
    Скрипт проверит и предложит установить необходимые системные зависимости (например, `whiptail`, `curl`, `sudo`).

## Использование

После успешного первого запуска и инициализации, вы можете запускать скрипт из любой директории, он всегда будет перенаправлять выполнение в `/opt/userscript/llh-u/llh-u.sh`

или, если `/opt/userscript/llh-u/` в вашем PATH:

```bash
llh-u.sh
```

## Документация

* **Техническая документация:** [`llh-u-technical.md`](https://gemini.google.com/app/llh-u-technical.md)

* **Репозиторий проекта:** [remarkua/llh-u](https://github.com/remarkua/llh-u)

## Лицензия

Этот проект распространяется под лицензией MIT.

**Автор:** Yury aka remark (Инициатор, Креативный менеджер)

**Кодер:** Искусственный Интеллект
