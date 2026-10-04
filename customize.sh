#!/system/bin/sh
#
# Установщик модуля Google Sans Bold.
#   fonts.xml         — перекрывает sans-serif и roboto-flex
#   font_fallback.xml — перекрывает roboto и roboto-flex (оттуда берётся
#                       кириллица для символов, которых нет в основном шрифте)
# Настройки веса и файлов — в lib/genfont.sh

# Каталог модуля. MODPATH гарантированно есть у Magisk и KernelSU,
# а ${0%/*} — нет: KernelSU Next запускает установщик с $0="sh",
# и в строке без слеша параметр не удаляется, давая MODDIR="sh".
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
ui_print " Вес всех начертаний: wght $FIXED_WEIGHT"

# ---- шрифты ----------------------------------------------------------------
# Каталог system/ обязан существовать в архиве: иначе менеджер не выставит
# на него права и SELinux-контекст (KernelSU Next делает это сразу после
# распаковки, до запуска установщика), и монтирование не взлетит.
# Google Sans распространяется под SIL OFL 1.1, см. LICENSE-OFL.txt.
mkdir -p "$MODDIR/system/fonts" "$MODDIR/system/etc" "$MODDIR/system/product/etc" "$MODDIR/system/product/fonts"

for F in "$FONT_FILE" "$FONT_ITALIC"; do
    [ -f "$MODDIR/system/fonts/$F" ] && continue
    # страховка: если файла в архиве нет, ищем в прошивке
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
    for F in "$M/system/product/etc/fonts_customization.xml" "$M/product/etc/fonts_customization.xml"; do
        [ -f "$F" ] && \
            abort "! Конфликт: модуль '$MNAME' тоже перекрывает fonts_customization.xml. Отключи или удали его."
    done
done

# ---- исходные файлы -------------------------------------------------------
SRC_XML=/system/etc/fonts.xml
SRC_FB=/system/etc/font_fallback.xml

[ -f "$SRC_XML" ] || abort "! Не найден $SRC_XML"
grep -q '<family name="sans-serif">' "$SRC_XML" || \
    abort "! В fonts.xml нет семейства sans-serif — неподдерживаемая прошивка?"

# Копии оригиналов: нужны для перепатча после обновления системы (action.sh)
cp -f "$SRC_XML" "$MODDIR/pristine-fonts.xml"
build_fonts_xml "$MODDIR/pristine-fonts.xml" "$MODDIR/system/etc/fonts.xml" || \
    abort "! Не удалось перекрыть семейства в fonts.xml."

# ---- font_fallback.xml (A15+; на более старых его может не быть) ------------
if [ -f "$SRC_FB" ]; then
    cp -f "$SRC_FB" "$MODDIR/pristine-font_fallback.xml"
    if build_fallback_xml "$MODDIR/pristine-font_fallback.xml" \
                  "$MODDIR/system/etc/font_fallback.xml"; then
        ui_print "- font_fallback.xml: roboto, roboto-flex перекрыты"
    else
        rm -f "$MODDIR/system/etc/font_fallback.xml" \
              "$MODDIR/pristine-font_fallback.xml"
        ui_print "  (font_fallback.xml есть, но нужных семейств в нём нет)"
    fi
else
    ui_print "  (font_fallback.xml нет — кириллица берётся из sans-serif)"
fi

# ---- product/etc/fonts_customization.xml -----------------------------------
# Системный UI (styles_device_defaults.xml) просит google-sans-text и
# variable-*, которые объявлены именно здесь. Без этого остаётся стоковый.
SRC_PRD=/product/etc/fonts_customization.xml
if [ -f "$SRC_PRD" ]; then
    cp -f "$SRC_PRD" "$MODDIR/pristine-fonts_customization.xml"
    if build_product_xml "$MODDIR/pristine-fonts_customization.xml" \
                        "$MODDIR/system/product/etc/fonts_customization.xml"; then
        # шрифты для OEM-семейств: парсер берёт их из /product/fonts
        cp -f "$MODDIR/system/fonts/$FONT_FILE" \
              "$MODDIR/system/product/fonts/$FONT_FILE" 2>/dev/null
        cp -f "$MODDIR/system/fonts/$FONT_ITALIC" \
              "$MODDIR/system/product/fonts/$FONT_ITALIC" 2>/dev/null
        ui_print "- fonts_customization.xml: все wght -> $FIXED_WEIGHT"
        ui_print "  (google-sans, google-sans-text, variable-* — то, что просит системный UI)"
    else
        rm -f "$MODDIR/system/product/etc/fonts_customization.xml" \
              "$MODDIR/pristine-fonts_customization.xml"
        ui_print "  (fonts_customization.xml без осей wght — пропущен)"
    fi
else
    ui_print "  (fonts_customization.xml нет — Pixel-семейства не тронуты)"
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