#!/bin/bash
# llh-u.sh
# [ГЛАВНЫЙ СКРИПТ]: Универсальный скрипт администрирования
# [ВЕРСИЯ]: 0.0.3
# [АВТОР]: Yury aka remark
# [ДАТА СОЗДАНИЯ]: 26 июня 2025 г.
# [ОПИСАНИЕ]:
#   Основной скрипт системы администрирования для Debian-подобных ОС.
#   Выполняет инициализацию окружения, управляет зависимостями,
#   обеспечивает локализацию, логирование, механизм обновлений
#   и загрузку модулей для выполнения специфических задач.

# 1. Объявление ORIGINAL_ARGS: Сохранение аргументов командной строки
ORIGINAL_ARGS=("$@")

# Включаем строгий режим для немедленного выхода при ошибке
set -e
# Включаем режим выхода при использовании неопределенных переменных
set -u

# 2. Определение путей, глобальных переменных и констант
# Имя скрипта (используется для формирования путей)
SCRIPT_NAME="llh-u" 
# Рабочий каталог скрипта, где хранятся исполняемые файлы и settings.ini
WORK_DIR="/opt/userscript/${SCRIPT_NAME}/"
# Корневая директория для логов (отделена от WORK_DIR для персистентности)
LOGS_ROOT_DIR="/opt/userscript/${SCRIPT_NAME}_logs/"
# URL для проверки и загрузки обновлений скрипта
REMOTE_UPDATE_URL="https://raw.githubusercontent.com/remarkua/llh-u/main/llh-u.sh" # Актуальный URL репозитория
# Версия основного скрипта (для использования в логах, документации)
SCRIPT_VERSION="0.0.3" # Обновленная версия

# Маппинг уровней логирования в числовые значения (для сравнения)
declare -gA LOG_LEVEL_NUMERIC=(
  ["DEBUG"]=0
  ["INFO"]=1
  ["ACTION"]=2
  ["WARNING"]=3
  ["ERROR"]=4
)
# Глобальная переменная для текущего числового порога логирования. Инициализируется в init_logging.
LOG_THRESHOLD_NUMERIC=0 

# Глобальная переменная для текущего языка. Инициализируется в initialize_language.
LANG="en"

# Глобальный ассоциативный массив для регистрации модулей (для будущего использования)
declare -gA REGISTERED_MODULES

# --- ГАРАНТИЯ СУЩЕСТВОВАНИЯ ДИРЕКТОРИИ ЛОГОВ ДЛЯ РАННЕГО ЛОГИРОВАНИЯ ---
# Создаем директорию логов и устанавливаем права максимально рано,
# чтобы любые вызовы log_main/log_module не приводили к ошибке "No such file or directory".
mkdir -p "$LOGS_ROOT_DIR" 2>/dev/null || { echo "CRITICAL ERROR: Could not create log directory $LOGS_ROOT_DIR" >&2; exit 1; }
chmod 0750 "$LOGS_ROOT_DIR" 2>/dev/null || { echo "CRITICAL ERROR: Could not set permissions for log directory $LOGS_ROOT_DIR" >&2; exit 1; }


# --- 3. Объявление языковых массивов ---
# Эти массивы содержат строки интерфейса для разных языков.
# Ключи должны быть в строчных буквах латинского алфафита, без пробелов или спецсимволов.
declare -A TEXT_EN=(
  ["language_select"]="Select interface language"
  ["unsupported_lang_warning"]="Warning: Language is not fully supported. Falling back to English."
  ["missing_deps_message"]="Required dependencies not found:"
  ["install_deps_prompt"]="Install automatically?"
  ["dep_install_error"]="Error installing dependencies!"
  ["deps_not_installed_exit"]="Dependencies not installed. Exiting."
  ["user_uid_error"]="Script can only be run by user with UID=1000. Current UID: $(id -u)"
  ["sudo_group_error"]="User must be a member of the 'sudo' group."
  ["script_already_running"]="Script is already running!"
  ["error_occurred"]="Error occurred"
  ["error_occurred_whiptail"]="Error occurred. Check logs for details."
  ["select_log_level"]="Select logging level"
  ["log_level_debug"]="DEBUG (all messages)"
  ["log_level_info"]="INFO (informational messages and above)"
  ["log_level_action"]="ACTION (user actions and above)"
  ["log_level_warning"]="WARNING (warnings and above)"
  ["log_level_error"]="ERROR (critical errors only)"
  ["apt_update_error"]="Failed to update package lists (apt update)."
  ["check_network_or_repos"]="Please check your network connection or repository configuration."
  ["failed_to_run_apt_update"]="Failed to run apt update."
  ["error_installing_deps"]="Error installing dependencies."
  ["deps_not_installed_exit_log"]="Dependencies not installed. Exiting script."
  ["work_dir_access_error"]="Error accessing or creating working directory."
  ["copy_error"]="Error copying file."
  ["root_launch_attempt_log"]="Attempted to launch script as root. Access denied."
  ["remote_update_integrity_error"]="Remote update failed: integrity check failed. File may be corrupted or invalid."
  ["bootstrapping_restart"]="Initial setup complete. Restarting script from designated working directory..."
  ["checking_for_updates"]="Checking for script updates..."
  ["update_check_download_failed"]="Failed to download remote script for update check."
  ["no_updates_found"]="No updates available. Local script is up to date."
  ["updates_available_log"]="New version available in remote repository."
  ["updates_available_prompt"]="A new version of the script is available. Do you want to update?"
  ["user_accepted_update"]="User accepted script update."
  ["user_declined_update"]="User declined script update."
  ["downloading_remote_script"]="Downloading latest script version from remote repository..."
  ["replacing_local_script"]="Replacing local script with new version..."
  ["script_replace_error"]="Error replacing local script file."
  ["restarting_after_update"]="Update complete. Restarting script."
  ["module_load_error"]="Error loading module."
  ["main_menu_title"]="Main Menu"
  ["main_menu_packages"]="Manage Packages"
  ["main_menu_services"]="Manage Services"
  ["main_menu_network"]="Network Settings"
  ["main_menu_update"]="Check for Updates"
  ["main_menu_language"]="Change Language"
  ["main_menu_log_level"]="Change Log Level"
  ["main_menu_exit"]="Exit"
  ["main_menu_choose_option"]="Choose an option"
  ["current_language_name"]="English"
  ["script_version_info"]="Script Version: "
  ["language_changed_success"]="Language changed successfully!"
  ["module_not_loaded"]="Module not loaded or not registered: "
  ["not_implemented_yet"]="This feature is not yet implemented: " # Added space at the end
  ["bootstrapping_start_message"]="Starting initial setup. Copying script files..."
)

declare -A TEXT_RU=(
  ["language_select"]="Выберите язык интерфейса"
  ["unsupported_lang_warning"]="Внимание: Выбранный язык не полностью поддерживается. Используется английский."
  ["missing_deps_message"]="Не найдены необходимые зависимости:"
  ["install_deps_prompt"]="Установить автоматически?"
  ["dep_install_error"]="Ошибка при установке зависимостей!"
  ["deps_not_installed_exit"]="Зависимости не установлены. Выход."
  ["user_uid_error"]="Скрипт может быть запущен только пользователем с UID=1000. Текущий UID: $(id -u)"
  ["sudo_group_error"]="Пользователь должен быть членом группы 'sudo'."
  ["script_already_running"]="Скрипт уже запущен!"
  ["error_occurred"]="Произошла ошибка"
  ["error_occurred_whiptail"]="Произошла ошибка. Подробности в логах."
  ["select_log_level"]="Выберите уровень логирования"
  ["log_level_debug"]="DEBUG (все сообщения)"
  ["log_level_info"]="INFO (информационные сообщения и выше)"
  ["log_level_action"]="ACTION (действия пользователя и выше)"
  ["log_level_warning"]="WARNING (предупреждения и выше)"
  ["log_level_error"]="ERROR (только критические ошибки)"
  ["apt_update_error"]="Не удалось обновить списки пакетов (apt update)."
  ["check_network_or_repos"]="Пожалуйста, проверьте ваше сетевое соединение или конфигурацию репозиториев."
  ["failed_to_run_apt_update"]="Не удалось выполнить apt update."
  ["error_installing_deps"]="Ошибка при установке зависимостей."
  ["deps_not_installed_exit_log"]="Зависимости не установлены. Выход из скрипта."
  ["work_dir_access_error"]="Ошибка доступа или создания рабочей директории."
  ["copy_error"]="Ошибка копирования файла."
  ["root_launch_attempt_log"]="Попытка запустить скрипт от имени root. Доступ запрещен."
  ["remote_update_integrity_error"]="Удаленное обновление не удалось: проверка целостности не пройдена. Файл может быть поврежден или недействителен."
  ["bootstrapping_restart"]="Начальная настройка завершена. Перезапуск скрипта из назначенной рабочей директории..."
  ["checking_for_updates"]="Проверка обновлений скрипта..."
  ["update_check_download_failed"]="Не удалось загрузить удаленный скрипт для проверки обновлений."
  ["no_updates_found"]="Обновлений нет. Локальный скрипт актуален."
  ["updates_available_log"]="Доступна новая версия в удаленном репозитории."
  ["updates_available_prompt"]="Доступна новая версия скрипта. Хотите обновить?"
  ["user_accepted_update"]="Пользователь согласился на обновление скрипта."
  ["user_declined_update"]="Пользователь отказался от обновления скрипта."
  ["downloading_remote_script"]="Загрузка последней версии скрипта из удаленного репозитория..."
  ["replacing_local_script"]="Замена локального скрипта новой версией..."
  ["script_replace_error"]="Ошибка при замене файла локального скрипта."
  ["restarting_after_update"]="Обновление завершено. Перезапуск скрипта."
  ["module_load_error"]="Ошибка загрузки модуля."
  ["main_menu_title"]="Главное меню"
  ["main_menu_packages"]="Управление пакетами"
  ["main_menu_services"]="Управление службами"
  ["main_menu_network"]="Настройки сети"
  ["main_menu_update"]="Проверить обновления"
  ["main_menu_language"]="Сменить язык"
  ["main_menu_log_level"]="Изменить уровень логирования"
  ["main_menu_exit"]="Выход"
  ["main_menu_choose_option"]="Выберите опцию"
  ["current_language_name"]="Русский"
  ["script_version_info"]="Версия скрипта: "
  ["language_changed_success"]="Язык успешно изменен!"
  ["module_not_loaded"]="Модуль не загружен или не зарегистрирован: "
  ["not_implemented_yet"]="Эта функция еще не реализована: " # Added space at the end
  ["bootstrapping_start_message"]="Начальная настройка. Копирование файлов скрипта..."
)

# --- 4. Объявление вспомогательных функций ---

# get_setting <section> <key>
# Получает значение ключа из указанной секции settings.ini.
# Предполагает простой формат INI (KEY=VALUE, секции [SECTION]).
get_setting() {
  local section="$1"
  local key="$2"
  local ini_file="settings.ini"
  awk -F '=' -v section="[$section]" -v key="$key" '
    $0 == section { in_section=1; next }
    in_section && /^\[.*\]/ { in_section=0 } # Конец секции
    in_section && $1 == key { 
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); # Обрезка пробелов из значения
      print $2; 
      exit 
    }
  ' "$ini_file" 2>/dev/null
}

# set_setting <section> <key> <value>
# Устанавливает или обновляет значение ключа в указанной секции settings.ini.
# Если секция не существует, она будет добавлена.
# Если ключ существует в секции, его значение обновляется.
# Если ключ не существует в секции, он добавляется в конец секции.
# Примечание: Эта функция не гарантирует идеальное форматирование для сложных INI-файлов
# с комментариями или пустыми строками внутри секций. Она рассчитана на простой settings.ini.
set_setting() {
  local section="$1"
  local key="$2"
  local value="$3"
  local ini_file="settings.ini"
  local tmp_file="${ini_file}.tmp.$$"
  local section_header="[$section]"
  
  # Проверяем, существует ли секция. Если нет, добавляем ее в конец файла.
  if ! grep -q "^\[$section\]" "$ini_file" 2>/dev/null; then
    echo -e "\n$section_header" >> "$ini_file"
  fi

  awk -F '=' -v sect="$section_header" -v k="$key" -v val="$value" '
    BEGIN { found_key_in_section=0; in_target_section=0; }
    
    # Если это целевая секция
    $0 == sect { 
      in_target_section=1; 
      print; 
      next 
    }
    
    # Если мы были в целевой секции и нашли новую секцию
    in_target_section && /^\[.*\]/ { 
      if (!found_key_in_section) { # Если ключ не был найден в предыдущей секции, добавляем его
        print k "=" val;
      }
      in_target_section=0; 
      print; 
      next 
    }
    
    # Если мы в целевой секции и это наш ключ
    in_target_section && $1 == k { 
      print k "=" val; 
      found_key_in_section=1; 
      next 
    }
    
    # Печатаем все остальные строки как есть
    { print } 
    
    # Если мы дошли до конца файла и все еще в целевой секции, но ключ не был найден
    END {
      if (in_target_section && !found_key_in_section) { 
        print k "=" val;
      }
    }
  ' "$ini_file" > "$tmp_file" && mv "$tmp_file" "$ini_file" 2>/dev/null
}

# get_text <key> [module_prefix]
# Возвращает локализованную строку по ключу. Если module_prefix указан, ищет в массиве модуля.
# Если не найдено, использует TEXT_EN как запасной вариант.
get_text() {
  local key="$1"
  local module_prefix="$2"
  local lang_array_name

  if [[ -n "$module_prefix" ]]; then
    # Ищем в массиве модуля (например, PACKAGES_TEXT_RU)
    lang_array_name="${module_prefix^^}_TEXT_${LANG^^}"
  else
    # Ищем в основном массиве (TEXT_RU)
    lang_array_name="TEXT_${LANG^^}"
  fi
  
  # Используем косвенное расширение для доступа к массиву по имени переменной
  declare -n current_text_array="$lang_array_name"
  
  if [[ -v current_text_array["$key"] ]]; then
    echo "${current_text_array["$key"]}"
  elif [[ -v TEXT_EN["$key"] ]]; then # Fallback на английский из основного скрипта
    echo "${TEXT_EN["$key"]}"
  else
    echo "TEXT_NOT_FOUND: $key" # Если текст не найден даже на английском
  fi
}

# log <prefix> <level> <message>
# Основная функция логирования.
log() {
  local prefix="$1"     # 'main' для основного скрипта, имя модуля для модулей
  local level_str="$2"  # Уровень логирования как строка (DEBUG, INFO, etc.)
  local message="$3"
  
  # Проверяем, нужно ли логировать сообщение по текущему уровню
  if [[ ${LOG_LEVEL_NUMERIC["$level_str"]} -ge $LOG_THRESHOLD_NUMERIC ]]; then
    local log_file=$(get_log_filename "$prefix")
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level_str] $message" >> "$log_file"
    
    # Дублирование в консоль, если уровень DEBUG или ACTION
    if [[ "$level_str" == "DEBUG" ]] || [[ "$level_str" == "ACTION" ]]; then
        echo "[$prefix] [$level_str] $message" >&2
    fi
  fi
}

# log_main <level> <message>
# Специализированная функция для логирования основного скрипта.
log_main() {
  log "main" "$1" "$2"
}

# log_module <module_name> <level> <message>
# Специализированная функция для логирования модулей.
log_module() {
  local module_name="$1"
  log "$module_name" "$2" "$3"
}

# get_log_filename <prefix>
# Генерирует имя файла лога с меткой времени.
get_log_filename() {
  local prefix="$1"
  local timestamp=$(date +"%Y%m%d-%H%M%S")
  echo "${LOGS_ROOT_DIR}/${prefix}_${timestamp}.log"
}

# rotate_logs
# Выполняет ротацию логов, оставляя последние 10 файлов для каждого префикса.
rotate_logs() {
  log_main "DEBUG" "Performing log rotation."
  # Список префиксов нужно поддерживать актуальным, добавляя сюда имена всех используемых модулей.
  # Пока хардкодим, но в будущем можно использовать REGISTERED_MODULES для динамического получения.
  for prefix in "main" "packages" "services" "network"; do 
    # Используем 'head -n 10' для получения только последних 10 файлов
    # ls -t сортирует по времени изменения (новые сверху)
    ls -t "${LOGS_ROOT_DIR}/${prefix}"_*.log 2>/dev/null | tail -n +11 | xargs rm -f -- 2>/dev/null
  done
  log_main "DEBUG" "Log rotation complete."
}

# init_logging
# Инициализирует систему логирования, включая выбор уровня логирования.
init_logging() {
  # chown $USER:sudo "$LOGS_ROOT_DIR" # TODO: Consider if chown is needed here, or handled by system setup.
  # The permissions are set above.
  local configured_log_level=""

  # Чтение уровня логирования из settings.ini
  if [[ -f "settings.ini" ]]; then
    configured_log_level=$(get_setting "General" "LOG_LEVEL" || echo "")
  fi

  # Если LOG_LEVEL не установлен в settings.ini или файл отсутствует,
  # или установлен некорректно, предлагаем пользователю выбрать.
  if [[ -z "$configured_log_level" ]] || ! [[ -v LOG_LEVEL_NUMERIC["$configured_log_level"] ]]; then
    local default_log_level="DEBUG"
    # Создаем/обновляем settings.ini, если он отсутствует или не имеет значения LOG_LEVEL
    set_setting "General" "LOG_LEVEL" "$default_log_level" 

    # Предлагаем пользователю выбрать уровень логирования
    local selected_level=$(whiptail --menu "$(get_text "select_log_level")" 15 60 5 \
      "DEBUG" "$(get_text "log_level_debug")" \
      "INFO" "$(get_text "log_level_info")" \
      "ACTION" "$(get_text "log_level_action")" \
      "WARNING" "$(get_text "log_level_warning")" \
      "ERROR" "$(get_text "log_level_error")" 3>&1 1>&2 2>&3)
    
    # Если пользователь выбрал, обновляем settings.ini
    if [[ -n "$selected_level" ]]; then
      set_setting "General" "LOG_LEVEL" "$selected_level"
      configured_log_level="$selected_level"
    else
      configured_log_level="$default_log_level" # Если отменил, оставляем DEBUG
    fi
  fi

  # Устанавливаем числовой порог логирования на основе полученного уровня
  LOG_THRESHOLD_NUMERIC=${LOG_LEVEL_NUMERIC["$configured_log_level"]}

  # Ротация логов при старте
  rotate_logs
  log_main "INFO" "$(get_text "script_version_info")${SCRIPT_VERSION}. Logging initialized with level: ${configured_log_level}."
}

# handle_error <error_code> <message>
# Функция для обработки ошибок, выводит сообщение и логирует.
# Возвращает управление на уровень выше (возвращается из текущей функции).
handle_error() {
  local code="$1"
  local msg="$2"
  log_main "ERROR" "$(get_text "error_occurred"): $code: $msg"
  whiptail --msgbox "$(get_text "error_occurred_whiptail")\n$msg" 15 60
  # Возвращаем управление на уровень выше, предполагая, что вызывающая функция находится в цикле меню.
  return
}

# register_module <module_name> <main_function_name>
# Регистрирует модуль для использования основным скриптом.
register_module() {
  local name="$1"
  local func="$2"
  REGISTERED_MODULES["$name"]="$func"
  log_main "DEBUG" "Module registered: $name with main function $func"
}

# initialize_language
# Инициализирует язык интерфейса, предлагает выбор при первом запуске.
initialize_language() {
  log_main "DEBUG" "Initializing language."
  if [[ -f "settings.ini" ]]; then
    LANG=$(get_setting "General" "LANG" || echo "en")
    log_main "DEBUG" "Language read from settings.ini: $LANG"
  else
    log_main "INFO" "settings.ini not found or LANG not set. Prompting for language selection."
    LANG=$(whiptail --menu "$(get_text "language_select")" 15 40 4 \
      "en" "English" \
      "ru" "Русский" \
      "es" "Español" 3>&1 1>&2 2>&3)
    set_setting "General" "LANG" "${LANG:-en}"
    LANG="${LANG:-en}" # Устанавливаем LANG даже если пользователь отменил выбор
    log_main "INFO" "Language set to: $LANG (initial setup)."
  fi
  
  if [[ "$LANG" != "en" ]] && ! declare -p "TEXT_$LANG" &>/dev/null; then
    log_main "WARNING" "Unsupported language '$LANG' detected. Falling back to English."
    whiptail --msgbox "$(get_text "unsupported_lang_warning")" 10 60
    LANG="en"
    set_setting "General" "LANG" "en"
  fi
  # Добавляем строку для текущего языка в TEXT_EN и TEXT_RU
  if [[ "$LANG" == "en" ]]; then
    TEXT_EN["current_language_name"]="English"
  elif [[ "$LANG" == "ru" ]]; then
    TEXT_RU["current_language_name"]="Русский"
  elif [[ "$LANG" == "es" ]]; then
    TEXT_EN["current_language_name"]="Spanish" # TODO: Add Spanish TEXT_ES array
    TEXT_RU["current_language_name"]="Испанский"
  else
    TEXT_EN["current_language_name"]="Unknown"
    TEXT_RU["current_language_name"]="Неизвестный"
  fi

  log_main "INFO" "Current interface language set to: $(get_text "current_language_name" "")."
}

# check_dependencies
# Проверяет наличие всех необходимых системных зависимостей и предлагает установку.
check_dependencies() {
  log_main "INFO" "Checking system dependencies."
  local REQUIRED_PACKAGES=(
    "whiptail" "sudo" "curl" "grep" "sed" "awk" 
    "apt" "systemd" "iproute2" "net-tools"
  )
  local missing=()
  for dep in "${REQUIRED_PACKAGES[@]}"; do
    ! command -v "$dep" &>/dev/null && missing+=("$dep")
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    local message="$(get_text "missing_deps_message")\n$(printf "%s\n" "${missing[@]}")\n\n$(get_text "install_deps_prompt")"
    if whiptail --yesno "$message" 15 60; then
      log_main "INFO" "$(get_text "running_apt_update")"
      if ! sudo apt update; then
        whiptail --msgbox "$(get_text "apt_update_error")\n$(get_text "check_network_or_repos")" 10 60
        log_main "ERROR" "$(get_text "failed_to_run_apt_update")"
        exit 1
      fi
      if ! sudo apt install -y "${missing[@]}"; then
        whiptail --msgbox "$(get_text "dep_install_error")" 10 60
        log_main "ERROR" "$(get_text "error_installing_deps"): ${missing[*]}."
        exit 1
      fi
    else
      whiptail --msgbox "$(get_text "deps_not_installed_exit")" 10 60
      log_main "WARNING" "$(get_text "deps_not_installed_exit_log")"
      exit 1
    fi
  fi
  log_main "INFO" "All required system dependencies are met."
}

# remote_restart
# Загружает последнюю версию скрипта из репозитория, заменяет текущую и перезапускает.
remote_restart() {
  log_main "INFO" "$(get_text "downloading_remote_script")"
  curl -sL "$REMOTE_UPDATE_URL" > "${WORK_DIR}/tmp/llh-u_remote.tmp"
  
  if [[ ! -f "${WORK_DIR}/tmp/llh-u_remote.tmp" ]] || \
     [[ $(wc -c < "${WORK_DIR}/tmp/llh-u_remote.tmp") -lt 1000 ]] || \
     ! head -n 1 "${WORK_DIR}/tmp/llh-u_remote.tmp" | grep -q "^#!/bin/bash"; then
    handle_error "UPDATE_INTEGRITY_FAIL" "$(get_text "remote_update_integrity_error")"
    rm -f "${WORK_DIR}/tmp/llh-u_remote.tmp" 2>/dev/null
    exit 1 # Критическая ошибка, выйти
  fi
  
  log_main "INFO" "$(get_text "replacing_local_script")"
  if ! mv "${WORK_DIR}/tmp/llh-u_remote.tmp" "${WORK_DIR}${SCRIPT_NAME}.sh"; then
    handle_error "SCRIPT_REPLACE_FAIL" "$(get_text "script_replace_error")"
    exit 1 # Критическая ошибка, выйти
  fi
  
  log_main "INFO" "$(get_text "restarting_after_update")"
  # Запускаем обновленный скрипт с оригинальными аргументами
  exec "${WORK_DIR}${SCRIPT_NAME}.sh" "${ORIGINAL_ARGS[@]}"
}

# check_for_updates
# Проверяет наличие новой версии скрипта в удаленном репозитории и предлагает обновить.
check_for_updates() {
  log_main "INFO" "$(get_text "checking_for_updates")"
  local remote_temp_file="${WORK_DIR}/tmp/llh-u_remote_check.tmp"

  if ! curl -sL "$REMOTE_UPDATE_URL" > "$remote_temp_file"; then
    log_main "WARNING" "$(get_text "update_check_download_failed"): $REMOTE_UPDATE_URL"
    rm -f "$remote_temp_file" 2>/dev/null
    return # Не завершаем работу, просто пропускаем проверку обновления
  fi

  if cmp -s "${WORK_DIR}${SCRIPT_NAME}.sh" "$remote_temp_file"; then
    log_main "INFO" "$(get_text "no_updates_found")"
    rm -f "$remote_temp_file" # Удаляем временный файл
  else
    log_main "INFO" "$(get_text "updates_available_log")"
    rm -f "$remote_temp_file" # Удаляем временный файл

    if whiptail --yesno "$(get_text "updates_available_prompt")" 10 60; then
      log_main "ACTION" "$(get_text "user_accepted_update")"
      remote_restart # Вызываем функцию удаленного обновления
    else
      log_main "INFO" "$(get_text "user_declined_update")"
    fi
  fi
}

# Функция для изменения уровня логирования через GUI
change_log_level() {
  log_main "INFO" "Prompting user to change log level."
  local selected_level=$(whiptail --menu "$(get_text "select_log_level")" 15 60 5 \
    "DEBUG" "$(get_text "log_level_debug")" \
    "INFO" "$(get_text "log_level_info")" \
    "ACTION" "$(get_text "log_level_action")" \
    "WARNING" "$(get_text "log_level_warning")" \
    "ERROR" "$(get_text "log_level_error")" 3>&1 1>&2 2>&3)

  if [[ -n "$selected_level" ]]; then
    set_setting "General" "LOG_LEVEL" "$selected_level"
    LOG_THRESHOLD_NUMERIC=${LOG_LEVEL_NUMERIC["$selected_level"]}
    log_main "INFO" "Log level successfully changed to: $selected_level"
  else
    log_main "INFO" "Log level change cancelled by user."
  fi
}

# Функция для изменения языка через GUI
change_language() {
  log_main "INFO" "Prompting user to change language."
  local selected_lang=$(whiptail --menu "$(get_text "language_select")" 15 40 4 \
      "en" "English" \
      "ru" "Русский" \
      "es" "Español" 3>&1 1>&2 2>&3)

  if [[ -n "$selected_lang" ]]; then
    set_setting "General" "LANG" "$selected_lang"
    LANG="$selected_lang"
    log_main "INFO" "Language successfully changed to: $selected_lang"
    whiptail --msgbox "$(get_text "language_changed_success")" 10 60
  else
    log_main "INFO" "Language change cancelled by user."
  fi
}


# --- Главное меню скрипта ---
main_menu() {
  log_main "INFO" "Main menu entered."
  while true; do
    local choice
    choice=$(whiptail --menu "$(get_text "main_menu_title")" 20 70 10 \
      "1" "$(get_text "main_menu_packages")" \
      "2" "$(get_text "main_menu_services")" \
      "3" "$(get_text "main_menu_network")" \
      "4" "$(get_text "main_menu_update")" \
      "5" "$(get_text "main_menu_language")" \
      "6" "$(get_text "main_menu_log_level")" \
      "7" "$(get_text "main_menu_exit")" 3>&1 1>&2 2>&3)
    
    local exit_status=$?

    if [[ "$exit_status" -eq 1 ]]; then # Пользователь нажал Cancel или Esc
      log_main "INFO" "User cancelled main menu. Exiting."
      break # Выход из главного цикла
    fi

    case "$choice" in
      1) # Управление пакетами (Вызов функции модуля)
        # Проверяем, зарегистрирован ли модуль 'packages' и вызываем его основную функцию
        if [[ -v REGISTERED_MODULES["packages"] ]]; then
          log_main "ACTION" "User selected Package Management. Calling ${REGISTERED_MODULES["packages"]}."
          # Вызываем функцию модуля через косвенное расширение
          "${REGISTERED_MODULES["packages"]}"
        else
          handle_error "MODULE_NOT_LOADED" "$(get_text "module_not_loaded"): packages"
        fi
        ;;
      2) # Управление службами (Пример для будущих модулей)
        log_main "ACTION" "User selected Services Management. (Not implemented yet)"
        whiptail --msgbox "$(get_text "not_implemented_yet") Service management." 10 60
        ;;
      3) # Настройки сети (Пример для будущих модулей)
        log_main "ACTION" "User selected Network Settings. (Not implemented yet)"
        whiptail --msgbox "$(get_text "not_implemented_yet") Network settings." 10 60
        ;;
      4) # Проверить обновления
        log_main "ACTION" "User selected Check for Updates."
        check_for_updates
        ;;
      5) # Сменить язык
        log_main "ACTION" "User selected Change Language."
        change_language
        ;;
      6) # Изменить уровень логирования
        log_main "ACTION" "User selected Change Log Level."
        change_log_level
        ;;
      7) # Выход
        log_main "ACTION" "User selected Exit. Exiting script."
        break
        ;;
      *)
        log_main "WARNING" "Invalid main menu choice: $choice"
        whiptail --msgbox "$(get_text "main_menu_choose_option")" 10 60
        ;;
    esac
  done
}


# --- 5. Процесс бутреппинга и инициализации рабочих директорий ---
# Определяем, является ли текущий запуск "бутреппингом"
CURRENT_SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# ВАЖНО: "$0" здесь должен быть путем к ФАЙЛУ скрипта, а не "bash" или "sh".
# Это означает, что скрипт должен быть сначала загружен на диск, а затем запущен.
# Запуск через `bash -c "$(wget -qO- ...)"` не поддерживается для первого запуска/бутреппинга.
if [[ "$CURRENT_SCRIPT_DIR" != "$WORK_DIR" ]]; then
  log_main "INFO" "Script is running from outside WORK_DIR. Initiating bootstrapping process."
  whiptail --msgbox "$(get_text "bootstrapping_start_message")" 10 60

  if [[ ! -d "$WORK_DIR" ]]; then
    log_main "INFO" "Creating WORK_DIR: $WORK_DIR"
    mkdir -p "$WORK_DIR" || { log_main "ERROR" "$(get_text "work_dir_access_error"): Failed to create $WORK_DIR"; whiptail --msgbox "$(get_text "work_dir_access_error"): $WORK_DIR (create)"; exit 1; }
    chmod 0750 "$WORK_DIR" || { log_main "ERROR" "$(get_text "work_dir_access_error"): Failed to set permissions for $WORK_DIR"; whiptail --msgbox "$(get_text "work_dir_access_error"): $WORK_DIR (chmod)"; exit 1; }
  fi

  # Копирование основного скрипта
  # Убеждаемся, что $0 указывает на реальный файл, а не на интерпретатор
  if [[ ! -f "$0" ]]; then
    log_main "ERROR" "Cannot copy script: \$0 does not point to a file. Ensure script is downloaded locally first."
    whiptail --msgbox "Error: Initial script must be downloaded and run locally (e.g., ./llh-u.sh), not piped (e.g., bash -c \"\$(wget ...)\")." 15 70
    exit 1
  fi

  log_main "INFO" "Copying main script from '$0' to '${WORK_DIR}${SCRIPT_NAME}.sh'"
  if ! cp "$0" "${WORK_DIR}${SCRIPT_NAME}.sh"; then
    whiptail --msgbox "$(get_text "copy_error"): $0 -> ${WORK_DIR}${SCRIPT_NAME}.sh" 10 60
    log_main "ERROR" "$(get_text "copy_error"): $0 -> ${WORK_DIR}${SCRIPT_NAME}.sh"
    exit 1
  fi
  
  # Копирование всех файлов модулей (llh-u-*.sh) из исходной директории
  # Предполагается, что модули находятся в той же директории, откуда был запущен скрипт
  log_main "INFO" "Searching for and copying module files (llh-u-*.sh) from '$CURRENT_SCRIPT_DIR' to '$WORK_DIR'."
  find "$CURRENT_SCRIPT_DIR" -maxdepth 1 -name "llh-u-*.sh" -print0 | while IFS= read -r -d $'\0' file; do
    log_main "DEBUG" "Found module file: $file"
    if ! cp "$file" "${WORK_DIR}"; then
      whiptail --msgbox "$(get_text "copy_error"): $file -> ${WORK_DIR}" 10 60
      log_main "ERROR" "$(get_text "copy_error"): $file -> ${WORK_DIR}"
      exit 1
    fi
  done
  log_main "INFO" "Module copying complete."


  mkdir -p "${WORK_DIR}/tmp" || { log_main "ERROR" "$(get_text "work_dir_access_error"): Failed to create ${WORK_DIR}/tmp"; whiptail --msgbox "$(get_text "work_dir_access_error"): ${WORK_DIR}/tmp (create)"; exit 1; }
  chmod 0750 "${WORK_DIR}/tmp" || { log_main "ERROR" "$(get_text "work_dir_access_error"): Failed to set permissions for ${WORK_DIR}/tmp"; whiptail --msgbox "$(get_text "work_dir_access_error"): ${WORK_DIR}/tmp (chmod)"; exit 1; }


  log_main "INFO" "$(get_text "bootstrapping_restart")"
  exec "${WORK_DIR}${SCRIPT_NAME}.sh" "${ORIGINAL_ARGS[@]}"
fi

# Если скрипт уже запущен из WORK_DIR, просто переходим в нее (или остаемся в ней)
if ! cd "$WORK_DIR"; then
  whiptail --msgbox "$(get_text "work_dir_access_error"): $WORK_DIR (cd)" 10 60
  log_main "ERROR" "$(get_text "work_dir_access_error"): $WORK_DIR (cd)"
  exit 1
fi

# Убедимся, что права на WORK_DIR, LOGS_ROOT_DIR и tmp/ корректны при каждом запуске
chmod 0750 "$WORK_DIR" || log_main "WARNING" "Failed to set permissions for $WORK_DIR during regular run."
chmod 0750 "$LOGS_ROOT_DIR" || log_main "WARNING" "Failed to set permissions for $LOGS_ROOT_DIR during regular run."
chmod 0750 "${WORK_DIR}/tmp" || log_main "WARNING" "Failed to set permissions for ${WORK_DIR}/tmp during regular run."


# --- 6. Инициализация логирования (должна быть до initialize_language) ---
init_logging

# --- 7. Инициализация языка (первое интерактивное окно) ---
initialize_language

# --- 8. Проверка зависимостей ---
check_dependencies

# --- 9. Критические защиты (перенесены сюда) ---
# Проверка пользователя (UID=1000)
if [[ $EUID -ne 1000 ]]; then
  log_main "ERROR" "$(get_text "root_launch_attempt_log") ($(get_text "user_uid_error"))"
  whiptail --msgbox "$(get_text "user_uid_error")" 10 50
  exit 1
fi
log_main "INFO" "User UID check passed. Current UID: $(id -u)."

# Проверка группы sudo
if [[ " $(id -Gn) " != *" sudo "* ]]; then
  log_main "ERROR" "$(get_text "sudo_group_error")"
  whiptail --msgbox "$(get_text "sudo_group_error")" 10 50
  exit 1
fi
log_main "INFO" "User is in 'sudo' group."

# Блокировка параллельного выполнения
exec 9>".lock" # Используем дескриптор файла 9 для блокировки
if ! flock -n 9; then # Неблокирующая попытка получить эксклюзивную блокировку
  log_main "ERROR" "$(get_text "script_already_running")"
  whiptail --msgbox "$(get_text "script_already_running")" 10 50
  exit 1
fi
log_main "INFO" "Acquired script lock."
# Освобождение блокировки при выходе (даже при аварийном завершении)
trap 'flock -u 9; rm -f .lock; log_main "INFO" "Released script lock." 2>/dev/null' EXIT


# --- 10. Проверка и актуализация версии ---
check_for_updates

# --- 11. Загрузка модулей ---
log_main "INFO" "Loading modules..."

# Подключение модуля llh-u-packages.sh
# Сохраняем текущее состояние опций для восстановления
declare -g _SAVED_FLAGS="$-" # Глобальная переменная для сохранения флагов
set -e -u # Включаем строгие режимы для загрузки модуля

if ! source "llh-u-packages.sh"; then # Изменено название модуля
  handle_error "MODULE_LOAD_ERROR" "$(get_text "module_load_error"): llh-u-packages.sh"
  exit 1 
fi

# Восстанавливаем предыдущее состояние опций
[[ $_SAVED_FLAGS == *e* ]] || set +e
[[ $_SAVED_FLAGS == *u* ]] || set +u
log_main "INFO" "Module 'packages' loaded successfully."

# TODO: Добавить загрузку других модулей здесь по аналогии
# Сохраняем текущее состояние опций
# local saved_flags_services="$-"
# set -e -u
# if ! source "llh-u-services.sh"; then handle_error "MODULE_LOAD_ERROR" "$(get_text "module_load_error"): llh-u-services.sh"; fi
# [[ $saved_flags_services == *e* ]] || set +e
# [[ $saved_flags_services == *u* ]] || set +u
# log_main "INFO" "Module 'services' loaded successfully."

log_main "INFO" "All specified modules attempted to load."

# --- 12. Главное меню ---
main_menu
