#!/system/bin/sh
#
# Установщик модуля Google Sans Bold.
#   fonts.xml         — перекрывает sans-serif и roboto-flex
#   font_fallback.xml — перекрывает roboto и roboto-flex (оттуда берётся
#                       кириллица для символов, которых нет в основном шрифте)
# Настройки веса и файлов — в lib/genfont.sh

MODDIR="${0%/*}"
MODULE_ID="google_sans_bold"

. "$MODDIR/lib/genfont.sh"

ui_print "***********************************"
ui_print " Google Sans Bold (systemless)   "
ui_print "***********************************"
ui_print " Вес всех начертаний: wght $FIXED_WEIGHT"

# ---- шрифты: берём из прошивки, в архиве их нет ---------------------------
# Google Sans — проприетарные файлы Google, они не распространяются.
# В любой сборке с vendor/pixel/gsans они уже лежат в /product/fonts,
# поэтому модуль просто копирует их к себе в /system/fonts.
FONT_SEARCH="/product/fonts /system/fonts /system_ext/fonts /vendor/fonts /odm/fonts"

find_font() {
    local name="$1" d
    for d in /product/fonts /system/fonts /system_ext/fonts /vendor/fonts /odm/fonts; do
        [ -f "$d/$name" ] && { echo "$d/$name"; return 0; }
    done
    return 1
}

mkdir -p "$MODPATH/system/fonts"
for F in "$FONT_FILE" "$FONT_ITALIC"; do
    P=$(find_font "$F") || \
        abort "! Не нашёл $F в прошивке (искал в $FONT_SEARCH). Нужен Google Sans от Google — он есть в стоковых сборках с gsans."
    ui_print "- $F <- $P"
    cp -f "$P" "$MODPATH/system/fonts/$F" || abort "! Не удалось скопировать $F"
done

# ---- конфликты с другими модулями шрифтов ---------------------------------
for M in /data/adb/modules/*/; do
    [ -d "$M" ] || continue
    MNAME=$(basename "$M")
    [ "$MNAME" = "$MODULE_ID" ] && continue
    [ -f "$M/disable" ] && continue
    for F in fonts.xml fonts_base.xml font_fallback.xml; do
        [ -f "$M/system/etc/$F" ] && \
            abort "! Конфликт: модуль '$MNAME' тоже перекрывает $F. Отключи или удали его."
    done
done

# ---- исходные файлы -------------------------------------------------------
SRC_XML=/system/etc/fonts.xml
SRC_FB=/system/etc/font_fallback.xml

[ -f "$SRC_XML" ] || abort "! Не найден $SRC_XML"
grep -q '<family name="sans-serif">' "$SRC_XML" || \
    abort "! В fonts.xml нет семейства sans-serif — неподдерживаемая прошивка?"

mkdir -p "$MODPATH/system/etc"

# Копии оригиналов: нужны для перепатча после обновления системы (action.sh)
cp -f "$SRC_XML" "$MODPATH/pristine-fonts.xml"
build_fonts_xml "$MODPATH/pristine-fonts.xml" "$MODPATH/system/etc/fonts.xml" || \
    abort "! Не удалось перекрыть семейства в fonts.xml."

# ---- font_fallback.xml (A15+; на более старых его может не быть) ------------
if [ -f "$SRC_FB" ]; then
    cp -f "$SRC_FB" "$MODPATH/pristine-font_fallback.xml"
    if build_fallback_xml "$MODPATH/pristine-font_fallback.xml" \
                  "$MODPATH/system/etc/font_fallback.xml"; then
        ui_print "- font_fallback.xml: roboto, roboto-flex перекрыты"
    else
        rm -f "$MODPATH/system/etc/font_fallback.xml" \
              "$MODPATH/pristine-font_fallback.xml"
        ui_print "  (font_fallback.xml есть, но нужных семейств в нём нет)"
    fi
else
    ui_print "  (font_fallback.xml нет — кириллица берётся из sans-serif)"
fi

ui_print "- fonts.xml: sans-serif, roboto-flex перекрыты"
ui_print "  шрифт: $FONT_FILE, курсив: $FONT_ITALIC"
ui_print "  все веса -> wght $FIXED_WEIGHT"
ui_print ""
ui_print "После перезагрузки:"
ui_print "  тумблер \"Жирный\" в настройках держи ВЫКЛЮЧЕННЫМ,"
ui_print "  иначе получится двойной жир."
ui_print ""
ui_print "Обновление прошивки: запусти действие модуля и перезагрузись."