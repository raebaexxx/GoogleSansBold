#!/system/bin/sh
#
# Установщик модуля Google Sans Bold.
#
# Перекрывает три файла шрифтовой конфигурации:
#   /system/etc/font_fallback.xml   — рабочий на Android 15+
#   /system/etc/fonts.xml           — legacy, используется для прелоада
#   /product/etc/fonts_customization.xml — семейства Pixel, которые
#                                        просит системный UI
#
# Настройки веса живут в config.conf, их меняет WebUI модуля.

MODDIR=
for d in "$MODPATH" "${0%/*}" "$PWD"; do
    [ -n "$d" ] && [ -f "$d/lib/genfont.sh" ] && { MODDIR="$d"; break; }
done
[ -n "$MODDIR" ] || \
    abort "! Не найден lib/genfont.sh (MODPATH=$MODPATH, \$0=$0, PWD=$PWD). Похоже, повреждённый архив."

MODULE_ID="google_sans_bold"

. "$MODDIR/lib/genfont.sh"

ui_print "***********************************"
ui_print " Google Sans Bold (systemless)   "
ui_print "***********************************"

# Настройки по умолчанию; WebUI потом их перезаписывает
[ -f "$MODDIR/config.conf" ] || \
    printf 'WEIGHT=%s\nOPSZ=%s\nCONDENSED=%s\n' \
        "$FIXED_WEIGHT" "$OPSZ" "$CONDENSED" > "$MODDIR/config.conf"
. "$MODDIR/lib/genfont.sh"   # перечитать на случай существующего файла

ui_print " Начертания: wght $FIXED_WEIGHT, opsz $OPSZ"

# ---- шрифты ----------------------------------------------------------------
# Каталог system/ обязан существовать в архиве: иначе менеджер не выставит
# на него права и SELinux-контекст, и монтирование не взлетит.
# Google Sans распространяется под SIL OFL 1.1, см. LICENSE-OFL.txt.
mkdir -p "$MODDIR/system/fonts" "$MODDIR/system/etc" \
         "$MODDIR/system/product/etc" "$MODDIR/system/product/fonts"

for F in "$FONT_FILE" "$FONT_ITALIC"; do
    [ -f "$MODDIR/system/fonts/$F" ] && continue
    for d in /product/fonts /system/fonts /system_ext/fonts /vendor/fonts /odm/fonts; do
        if [ -f "$d/$F" ]; then
            ui_print "- $F <- $d/$F"
            cp -f "$d/$F" "$MODDIR/system/fonts/$F" && break
        fi
    done
    [ -f "$MODDIR/system/fonts/$F" ] || \
        abort "! Нет шрифта $F: нет в архиве и не нашёлся в прошивке."
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
    for F in "$M/system/product/etc/fonts_customization.xml" \
             "$M/product/etc/fonts_customization.xml"; do
        [ -f "$F" ] && \
            abort "! Конфликт: модуль '$MNAME' тоже перекрывает fonts_customization.xml."
    done
done

# ---- исходные файлы: копии для перепатча ----------------------------------
# Обновляемый пользователем конфиг не считаем исходником.
for pair in "/system/etc/fonts.xml:pristine-fonts.xml" \
            "/system/etc/font_fallback.xml:pristine-font_fallback.xml" \
            "/product/etc/fonts_customization.xml:pristine-fonts_customization.xml"; do
    SRC=${pair%%:*}
    DST="$MODDIR/${pair##*:}"
    [ -f "$MODDIR/${DST##*/}" ] && [ -f "$SRC" ] && \
        grep -q 'Google Sans Bold v' "$SRC" 2>/dev/null && continue
    [ -f "$SRC" ] || continue
    cp -f "$SRC" "$DST"
    chmod 644 "$DST"
done

# ---- сборка ----------------------------------------------------------------
if ! rebuild_all; then
    abort "! Не удалось перекрыть семейства. Проверь, что в системе есть fonts.xml."
fi

ui_print "- fonts.xml, font_fallback.xml: sans-serif и roboto перекрыты"
ui_print "- fonts_customization.xml: все wght -> $FIXED_WEIGHT"
ui_print "  (google-sans, google-sans-text, variable-* — то, что просит системный UI)"
ui_print "  шрифт: $FONT_FILE, курсив: $FONT_ITALIC"
ui_print ""
ui_print "После перезагрузки:"
ui_print "  тумблер \"Жирный\" в настройках держи ВЫКЛЮЧЕННЫМ."
ui_print ""
ui_print "Менять вес потом можно без терминала:"
ui_print "  KernelSU → модуль Google Sans Bold → шестерёнка (WebUI)."
ui_print "Обновление прошивки: запусти действие модуля и перезагрузись."