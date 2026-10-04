#!/system/bin/sh
# Генератор семейств для fonts.xml, font_fallback.xml и fonts_customization.xml.
# Подключается из customize.sh, action.sh и rebuild.sh:  . "$MODDIR/lib/genfont.sh"

# ======================= НАСТРОЙКИ (меняй тут) =======================
# Текущие значения лежат в config.conf рядом с модулем — их меняет WebUI
# (KernelSU Next → модуль → значок шестерёнки) и они переживают перезагрузку.
# Значения ниже — только значения по умолчанию.

# Все веса -> этот вес оси wght. У обычного Google Sans диапазон 400..700.
FIXED_WEIGHT=700

# Оптический размер. У GoogleSans-Regular.ttf ось opsz = 17..18.
OPSZ=18

# Перекрывать ли sans-serif-condensed
CONDENSED=1

# Основной шрифт. Именно в нём есть кириллица (220 символов),
# в отличие от GoogleSansFlex, где её нет вообще.
FONT_FILE="GoogleSans-Regular.ttf"
FONT_ITALIC="GoogleSans-Italic.ttf"

# ====================================================================

CONF="${CONF:-$MODDIR/config.conf}"
if [ -f "$CONF" ]; then
    _w=$(sed -n 's/^WEIGHT=//p' "$CONF" | tail -1)
    _o=$(sed -n 's/^OPSZ=//p' "$CONF" | tail -1)
    _c=$(sed -n 's/^CONDENSED=//p' "$CONF" | tail -1)
    case "$_w" in ''|*[!0-9]*) ;; *) FIXED_WEIGHT="$_w" ;; esac
    case "$_o" in ''|*[!0-9]*) ;; *) OPSZ="$_o" ;; esac
    case "$_c" in 0|1) CONDENSED="$_c" ;; esac
fi

# Список весов задан литералом: разбиение переменной по словам зависит
# от шелла, а zsh этого не делает.
ALL_WEIGHTS="100 200 300 400 500 600 700 800 900"


# Каталог product в модуле. На этапе установки он лежит в system/product,
# а KernelSU Next переносит его в корень модуля:
#   handle_partition() { mv -f $MODPATH/system/$1 $MODPATH/$1 ... }
product_dir() {
    if [ -d "$MODDIR/product" ]; then
        echo "$MODDIR/product"
    else
        echo "$MODDIR/system/product"
    fi
}

# Печатает семейство: все веса на FIXED_WEIGHT, курсив отдельным файлом.
gen_family() {
    local name="$1" w
    echo "    <family name=\"$name\">"
    for w in $ALL_WEIGHTS; do
        echo "        <font weight=\"$w\" style=\"normal\">$FONT_FILE"
        echo "          <axis tag=\"wght\" stylevalue=\"$FIXED_WEIGHT\" />"
        echo "          <axis tag=\"opsz\" stylevalue=\"$OPSZ\" />"
        echo "        </font>"
    done
    for w in $ALL_WEIGHTS; do
        echo "        <font weight=\"$w\" style=\"italic\">$FONT_ITALIC"
        echo "          <axis tag=\"wght\" stylevalue=\"$FIXED_WEIGHT\" />"
        echo "          <axis tag=\"opsz\" stylevalue=\"$OPSZ\" />"
        echo "        </font>"
    done
    echo '      </family>'
}

# Заменяет в XML семейство с заданным именем на содержимое файла-блока.
# Возвращает 0, если семейство найдено и заменено, иначе 3.
patch_family() {
    awk -v name="$3" -v block="$2" '
        function emit(  line) {
            while ((getline line < block) > 0) print line
            close(block)
        }
        {
            t = $0
            sub(/^[ \t]+/, "", t)
            if (!skip && index(t, "<family name=\"" name "\"") == 1) {
                emit()
                found = 1
                skip = 1
                next
            }
            if (skip) {
                if (index(t, "</family>") == 1) skip = 0
                next
            }
            print
        }
        END { exit(found ? 0 : 3) }
    ' "$1" > "$4"
}

# Перекрывает перечисленные семейства в XML: src -> out.
# Семейства, которых в файле нет, пропускаются.
build_xml() {
    local src="$1" out="$2" tmp changed=0 fam
    shift 2
    tmp="$out.tmp.$$"

    cp -f "$src" "$tmp.cur"
    for fam in "$@"; do
        gen_family "$fam" > "$tmp.blk"
        if patch_family "$tmp.cur" "$tmp.blk" "$fam" "$tmp.nxt"; then
            mv -f "$tmp.nxt" "$tmp.cur"
            changed=$((changed + 1))
        else
            rm -f "$tmp.nxt"
        fi
    done

    if [ "$changed" -eq 0 ]; then
        rm -f "$tmp".*
        return 1
    fi

    mv -f "$tmp.cur" "$out"
    rm -f "$tmp".*
    return 0
}

# ВАЖНО: на Android 15+ рабочим файлом шрифтовой конфигурации является
# /system/etc/font_fallback.xml, а fonts.xml числится legacy — его читает
# только прелоад в zygote (SystemFonts.FONTS_XML против LEGACY_FONTS_XML).
build_fonts_xml() {
    if [ "$CONDENSED" = 1 ]; then
        build_xml "$1" "$2" sans-serif sans-serif-condensed roboto-flex
    else
        build_xml "$1" "$2" sans-serif roboto-flex
    fi
}

build_fallback_xml() {
    if [ "$CONDENSED" = 1 ]; then
        build_xml "$1" "$2" sans-serif sans-serif-condensed roboto roboto-flex
    else
        build_xml "$1" "$2" sans-serif roboto roboto-flex
    fi
}

# /product/etc/fonts_customization.xml — OEM-семейства Pixel: google-sans,
# google-sans-text, google-sans-clock и все variable-*.
# Именно их просит системный UI через styles_device_defaults.xml:
#   fontFamily = @string/config_bodyFontFamily  -> google-sans-text
#   fontFamily = variable-body-medium, variable-title-small-emphasized, ...
# Поэтому все wght в этом файле переводятся на FIXED_WEIGHT.
build_product_xml() {
    awk -v w="$FIXED_WEIGHT" '
        /<axis/ && /tag="wght"/ {
            gsub(/stylevalue="[^"]*"/, "stylevalue=\"" w "\"")
            touched = 1
        }
        { print }
        END { exit(touched ? 0 : 1) }
    ' "$1" > "$2"
}

# Пересобирает все три файла из сохранённых при установке оригиналов.
# Используется и установщиком, и действием модуля, и WebUI.
rebuild_all() {
    local ok=0 pd

    if [ -f "$MODDIR/pristine-fonts.xml" ]; then
        build_fonts_xml "$MODDIR/pristine-fonts.xml" \
                        "$MODDIR/system/etc/fonts.xml" && ok=1
    fi

    if [ -f "$MODDIR/pristine-font_fallback.xml" ]; then
        build_fallback_xml "$MODDIR/pristine-font_fallback.xml" \
                           "$MODDIR/system/etc/font_fallback.xml" && ok=1
    fi

    if [ -f "$MODDIR/pristine-fonts_customization.xml" ]; then
        pd=$(product_dir)
        mkdir -p "$pd/etc" "$pd/fonts"
        if build_product_xml "$MODDIR/pristine-fonts_customization.xml" \
                            "$pd/etc/fonts_customization.xml"; then
            # парсер OEM-кастомизации берёт файлы из /product/fonts
            [ -f "$MODDIR/system/fonts/$FONT_FILE" ] && \
                cp -f "$MODDIR/system/fonts/$FONT_FILE" "$pd/fonts/$FONT_FILE"
            [ -f "$MODDIR/system/fonts/$FONT_ITALIC" ] && \
                cp -f "$MODDIR/system/fonts/$FONT_ITALIC" "$pd/fonts/$FONT_ITALIC"
            ok=1
        fi
    fi

    [ "$ok" = 1 ]
}