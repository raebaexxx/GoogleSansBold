#!/system/bin/sh
# Генератор семейств для fonts.xml и font_fallback.xml.
# Подключается из customize.sh и action.sh:  . "$MODDIR/lib/genfont.sh"

# ======================= НАСТРОЙКИ (меняй тут) =======================

# Все веса -> этот вес оси wght. У обычного Google Sans диапазон 400..700,
# поэтому 700 — максимум, который доступен.
FIXED_WEIGHT=700

# Оптический размер. У GoogleSans-Regular.ttf ось opsz = 17..18, дефолт 18.
OPSZ=18

# Основной шрифт. Именно в нём есть кириллица (220 символов),
# в отличие от GoogleSansFlex, где её нет вообще.
FONT_FILE="GoogleSans-Regular.ttf"
FONT_ITALIC="GoogleSans-Italic.ttf"

# Что перекрываем:
#   fonts.xml         -> sans-serif (основное семейство) и roboto-flex
#   font_fallback.xml -> roboto и roboto-flex; оттуда берётся кириллица
#                        для символов, которых нет в основном шрифте.
# Списки семейств заданы литералами в функциях ниже, а не переменными:
# разбиение строки по словам зависит от шелла, а zsh этого не делает.

# ====================================================================


# Печатает семейство: все веса на FIXED_WEIGHT, курсив отдельным файлом.
gen_family() {
    local name="$1" w
    echo "    <family name=\"$name\">"
    for w in 100 200 300 400 500 600 700 800 900; do
        echo "        <font weight=\"$w\" style=\"normal\">$FONT_FILE"
        echo "          <axis tag=\"wght\" stylevalue=\"$FIXED_WEIGHT\" />"
        echo "          <axis tag=\"opsz\" stylevalue=\"$OPSZ\" />"
        echo "        </font>"
    done
    for w in 100 200 300 400 500 600 700 800 900; do
        echo "        <font weight=\"$w\" style=\"italic\">$FONT_ITALIC"
        echo "          <axis tag=\"wght\" stylevalue=\"$FIXED_WEIGHT\" />"
        echo "          <axis tag=\"opsz\" stylevalue=\"$OPSZ\" />"
        echo "        </font>"
    done
    echo '      </family>'
}

# Заменяет в XML семейство с заданным именем на содержимое файла-блока.
# Возвращает 0, если семейство найдено и заменено, иначе 3.
# patch_family <src.xml> <block.xml> <family name> <out.xml>
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
# Если не перекрыто ни одного - возврат 1 (значит файл не тот).
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

# Обёртки под конкретные файлы.
build_fonts_xml() {
    build_xml "$1" "$2" sans-serif roboto-flex
}

build_fallback_xml() {
    build_xml "$1" "$2" roboto roboto-flex
}