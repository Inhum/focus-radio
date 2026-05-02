#!/bin/bash

# Порог свободного места в процентах
THRESHOLD=20

# Получаем список всех смонтированных файловых систем (кроме tmpfs и служебных)
df -h --output=source,pcent,target | tail -n +2 | grep -v tmpfs | while read -r source pcent target; do
    # Извлекаем числовое значение процента использования (убираем знак %)
    used=${pcent%%%}

    # Вычисляем свободное место в процентах
    free=$((100 - used))

    if [ "$free" -lt "$THRESHOLD" ]; then
        echo "WARN: $target ($source) — свободно ${free}% (занято ${used}%)"
    else
        echo "OK:   $target ($source) — свободно ${free}% (занято ${used}%)"
    fi
done
