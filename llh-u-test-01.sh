#!/bin/bash

# llh-u-test-01.sh
# [МОДУЛЬ]: Тестовый сценарий Whiptail
# [ВЕРСИЯ]: 0.0.3
# [ОПИСАНИЕ]:
#   - Демонстрирует окно Whiptail с сообщением, чекбоксами и кнопками.
#   - Имитирует возвращение в главное меню модуля.

# --- Глобальные переменные и функции-заглушки для тестирования ---
# Эти functions нужны, чтобы скрипт мог работать автономно для тестирования UI
# В реальной системе они будут предоставлены основным скриптом llh-u.sh

# Заглушка для LOGS_ROOT_DIR (для автономной работы)
LOGS_ROOT_DIR="/tmp/llh-u_test_logs"
mkdir -p "$LOGS_ROOT_DIR"

# Заглушка для log_main
log_main() {
  local level="$1"
  local message="$2"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[$timestamp] [TEST_LOG] [$level] $message" >> "${LOGS_ROOT_DIR}/llh-u-test-01_debug.log"
  if [[ "$level" == "ERROR" || "$level" == "WARNING" || "$level" == "ACTION" ]]; then
    echo "[$level] $message" >&2 # Выводим в stderr для заметности
  fi
}

# --- Локализация для тестового скрипта ---
# Используется переменная LANG для выбора языка.
# Для тестирования можно изменить LANG="ru" или LANG="en"

LANG="${LANG:-en}" # По умолчанию английский

declare -A TEST_TEXT_EN=(
  ["main_dialog_title"]="Test Dialog"
  ["main_dialog_message"]="Not continue?"
  ["checkbox_yes"]="Yes"
  ["checkbox_no"]="No"
  ["selected_yes_message"]="You selected: Yes - Not continue!"
  ["selected_no_message"]="You selected: No - Not continue!"
  ["return_to_menu"]="Returning to module menu."
  ["exit_test"]="Exiting test script."
  ["user_canceled"]="User canceled the dialog."
  ["choose_options"]="Choose options below"
)

declare -A TEST_TEXT_RU=(
  ["main_dialog_title"]="Тестовое окно"
  ["main_dialog_message"]="Не продолжать?"
  ["checkbox_yes"]="Да"
  ["checkbox_no"]="Нет"
  ["selected_yes_message"]="Вы выбрали: Да - Не продолжать!"
  ["selected_no_message"]="Вы выбрали: Нет - Не продолжать!"
  ["return_to_menu"]="Возвращение в меню модуля."
  ["exit_test"]="Выход из тестового скрипта."
  ["user_canceled"]="Пользователь отменил диалог."
  ["choose_options"]="Выберите опции ниже"
)

# Функция get_text для тестового скрипта
# Имитирует поведение get_text из основного ТЗ
get_text() {
  local key="$1"
  local module_prefix="$2" # В этом тестовом скрипте prefix не используется, но оставлен для совместимости
  
  local lang_array_name="TEST_TEXT_${LANG^^}" # Используем TEST_TEXT_RU/EN
  declare -n current_text_array="$lang_array_name" # Динамическая ссылка на массив
  
  if ! declare -p "$lang_array_name" &>/dev/null; then
      if [[ -n "$module_prefix" ]] && declare -p "${module_prefix^^}_TEXT_EN" &>/dev/null; then
          lang_array_name="${module_prefix^^}_TEXT_EN"
      elif [[ -z "$module_prefix" ]] && declare -p "TEST_TEXT_EN" &>/dev/null; then # Changed to TEST_TEXT_EN
          lang_array_name="TEST_TEXT_EN"
      else
          echo "TEXT_NOT_FOUND: $key"
          return
      fi
  fi

  declare -n current_text_array="$lang_array_name"
  
  if [[ -v current_text_array["$key"] ]]; then
    echo "${current_text_array["$key"]}"
  elif [[ -v TEST_TEXT_EN["$key"] ]]; then # Fallback на английский
    echo "${TEST_TEXT_EN["$key"]}"
  else
    echo "TEXT_NOT_FOUND: $key"
  fi
}

# --- Основная функция тестового сценария ---
llh_u_test_main() {
  while true; do
    log_main "INFO" "Test dialog started."

    # whiptail --checklist <text> <height> <width> <listheight> [ <tag> <item> <status> ] ...
    local result
    result=$(whiptail --checklist "$(get_text "main_dialog_message")" 15 60 2 \
      "yes_option" "$(get_text "checkbox_yes")" OFF \
      "no_option" "$(get_text "checkbox_no")" OFF 3>&1 1>&2 2>&3)
    
    local exit_status=$? # Получаем код выхода whiptail

    if [[ "$exit_status" -eq 0 ]]; then # Пользователь нажал OK
      log_main "INFO" "User clicked OK. Selected: $result"
      if [[ "$result" == *"yes_option"* ]]; then
        whiptail --msgbox "$(get_text "selected_yes_message")" 10 60
        log_main "ACTION" "$(get_text "selected_yes_message")"
      elif [[ "$result" == *"no_option"* ]]; then
        whiptail --msgbox "$(get_text "selected_no_message")" 10 60
        log_main "ACTION" "$(get_text "selected_no_message")"
      else
        whiptail --msgbox "$(get_text "choose_options")" 10 60 # Если ничего не выбрано, но нажали OK
        log_main "INFO" "User clicked OK without selecting any option."
      fi
      
      whiptail --msgbox "$(get_text "return_to_menu")" 10 60
      log_main "INFO" "$(get_text "return_to_menu")"
      # В реальном сценарии здесь был бы 'return' для выхода из функции модуля
      # и возврата в main_menu основного скрипта.
      # Для этого тестового скрипта, мы просто показываем сообщение и повторяем цикл
      # если пользователь не нажал 'Cancel' в главном whiptail диалоге.
    elif [[ "$exit_status" -eq 1 ]]; then # Пользователь нажал Cancel (или Esc)
      whiptail --msgbox "$(get_text "exit_test")" 10 60
      log_main "INFO" "$(get_text "user_canceled")"
      break # Выход из цикла, завершение тестового скрипта
    fi
  done
}

# --- Запуск тестового сценария ---
# Эта строка была удалена: llh_u_test_main
# Функция llh_u_test_main теперь должна вызываться только из основного скрипта llh-u.sh
