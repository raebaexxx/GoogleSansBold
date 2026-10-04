#!/system/bin/sh
#
# Действие модуля (KernelSU/Magisk -> Модуль -> Действие).
# Пересобирает fonts.xml и font_fallback.xml из сохранённых оригиналов.
# Нужно после обновления прошивки: система могла поменять эти файлы.

# MODPATH надёжнее ${0%/*}: см. комментарий в customize.sh
MODDIR=
for d in "$MODPATH" "${0%/*}" "$PWD"; do
    [ -n "$d" ] && [ -f "$d/lib/genfont.sh" ] && { MODDIR="$d"; break; }
done

. "$MODDIR/lib/genfont.sh"

PX="$MODDIR/pristine-fonts.xml"
PF="$MODDIR/pristine-font_fallback.xml"

if [ ! -f "$PX" ]; then
    echo "! Оригинал fonts.xml не найден, переустанови модуль."
    exit 1
fi

build_fonts_xml "$PX" "$MODDIR/system/etc/fonts.xml" || {
    echo "! Семейство sans-serif не найдено. Переустанови модуль."
    exit 1
}
echo "fonts.xml: все веса -> wght $FIXED_WEIGHT"

if [ -f "$PF" ]; then
    if build_fallback_xml "$PF" "$MODDIR/system/etc/font_fallback.xml"; then
        echo "font_fallback.xml: roboto, roboto-flex -> $FONT_FILE"
    else
        echo "font_fallback.xml: нужных семейств нет, пропущен"
    fi
fi

# product/etc/fonts_customization.xml лежит уже в product/, а не system/product/:
# KernelSU Next переносит каталог на этапе установки (handle_partition).
PC="$MODDIR/pristine-fonts_customization.xml"
if [ -f "$PC" ]; then
    PDIR=$(product_dir)
    mkdir -p "$PDIR/etc" "$PDIR/fonts"
    if build_product_xml "$PC" "$PDIR/etc/fonts_customization.xml"; then
        [ -f "$MODDIR/system/fonts/$FONT_FILE" ] && \
            cp -f "$MODDIR/system/fonts/$FONT_FILE" "$PDIR/fonts/$FONT_FILE"
        [ -f "$MODDIR/system/fonts/$FONT_ITALIC" ] && \
            cp -f "$MODDIR/system/fonts/$FONT_ITALIC" "$PDIR/fonts/$FONT_ITALIC"
        echo "fonts_customization.xml: все wght -> $FIXED_WEIGHT"
    else
        echo "fonts_customization.xml: осей wght нет, пропущен"
    fi
fi

echo "Теперь перезагрузи устройство."