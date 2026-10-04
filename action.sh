#!/system/bin/sh
#
# Действие модуля (KernelSU/Magisk -> Модуль -> Действие).
# Пересобирает все три файла из сохранённых при установке оригиналов
# по текущим настройкам из config.conf. То же самое делает WebUI.

MODDIR="${0%/*}"
[ -f "$MODDIR/rebuild.sh" ] || {
    echo "! Модуль повреждён: нет rebuild.sh"
    exit 1
}

exec sh "$MODDIR/rebuild.sh"