#!/system/bin/sh
# Пересборка шрифтов по настройкам из config.conf.
#   rebuild.sh                 — пересобрать с текущими настройками
#   rebuild.sh 600             — wght=600 и пересобрать
#   rebuild.sh 600 1           — wght=600, condensed=1 и пересобрать
#   rebuild.sh 600 1 no-reboot — то же, но без перезагрузки
# Вызывается из WebUI и из действия модуля.

MODDIR="${0%/*}"
[ -f "$MODDIR/lib/genfont.sh" ] || { echo "! Модуль не установлен"; exit 1; }

. "$MODDIR/lib/genfont.sh"

# Аргументы перекрывают config.conf. Проверка строго POSIX: в busybox ash
# нет конструкций вида ${1//[0-9]/}.
case "$1" in
    ''|*[!0-9]*) ;;
    *)
        W="$1"
        # Google Sans покрывает 400..700; за пределами Minikon всё равно
        # зажмёт значение, поэтому границы фиксируем.
        [ "$W" -lt 400 ] && W=400
        [ "$W" -gt 700 ] && W=700
        FIXED_WEIGHT="$W"
        ;;
esac
case "$2" in
    0|1) CONDENSED="$2" ;;
esac

printf 'WEIGHT=%s\nOPSZ=%s\nCONDENSED=%s\n' \
    "$FIXED_WEIGHT" "$OPSZ" "$CONDENSED" > "$MODDIR/config.conf"

if rebuild_all; then
    echo "Готово: все начертания -> wght $FIXED_WEIGHT"
    echo "                opsz $OPSZ, condensed=$CONDENSED"
    case "$3" in
        no-reboot) : ;;
        *) echo "Перезагрузи устройство, чтобы применилось." ;;
    esac
    exit 0
fi

echo "! Не удалось пересобрать: оригиналы fonts.xml не найдены. Переустанови модуль."
exit 1