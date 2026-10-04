# Google Sans Bold (systemless)

Magisk/KernelSU-модуль для Android. Переводит **все начертания системного шрифта на `wght 700`** и ставит шрифтом по умолчанию Google Sans — так текст выглядит полужирным везде, включая приложения, которые рисуют текст сами (Telegram, Canvas, Compose, Jetpack Compose).

Работает за счёт подмены самого `Typeface`, который система отдаёт приложению, а не системной настройки `font_weight_adjustment`. Эта настройка, кстати, работает **только в `TextView`** — в `frameworks/base` её читает единственный класс, `android.widget.TextView`. Поэтому тумблер «Жирный» в настройках одних и тех же приложений даёт разный результат.

## Что перекрывается

| Файл | Семейства |
|---|---|
| Файл | Что делается |
|---|---|
| `/system/etc/font_fallback.xml` | семейства `sans-serif`, `sans-serif-condensed`, `roboto`, `roboto-flex` заменяются |
| `/system/etc/fonts.xml` | то же (legacy-путь) |
| `/product/etc/fonts_customization.xml` | **все** оси `wght` переводятся на `FIXED_WEIGHT` |

Третий файл нужен потому, что системный UI идёт мимо `sans-serif`. В `frameworks/base/core/res/res/values/styles_device_defaults.xml` Material-стили текста прямо ссылаются на:

```xml
<item name="android:fontFamily">@string/config_bodyFontFamily</item>
<item name="android:fontFamily">variable-body-medium</item>
<item name="android:fontFamily">variable-title-small-emphasized</item>
```

`config_bodyFontFamily` на Pixel-прошивках равен `google-sans-text`, а сами `google-sans*` и `variable-*` объявлены в `/product/etc/fonts_customization.xml` со своими весами 400/500/600/700. Без перекрытия этого файла приложения получают жирный Google Sans, а системный UI остаётся стоковым.

Модуль кладёт файлы в `system/product/...` — KernelSU Next переносит такой каталог в корень модуля:

```sh
handle_partition() {
    # if /system/vendor is a symlink, we need to move it out of $MODPATH/system
    mv -f $MODPATH/system/$1 $MODPATH/$1 && ln -sf ../$1 $MODPATH/system/$1
}
handle_partition product
```

**Почему оба файла.** На Android 15+ рабочей шрифтовой конфигурацией стал `font_fallback.xml`, а `fonts.xml` числится legacy — его читает только прелоад в zygote:

```java
// SystemFonts.java
private static final String FONTS_XML = getFontsXmlDir() + "font_fallback.xml";
public static final String LEGACY_FONTS_XML = getFontsXmlDir() + "fonts.xml";

// Typeface.init() — только прелоад, с TODO на переход на новый файл
FontConfig config = SystemFonts.getSystemPreinstalledFontConfigFromLegacyXml();
```

А карту шрифтов, по которой реально рисуют приложения, отдаёт `FontManagerService.getSystemFontConfig()` → `getSystemPreinstalledFontConfig()`, и она парсит именно `font_fallback.xml`. Правка одного только `fonts.xml` не даёт ничего.

Все → `GoogleSans-Regular.ttf` / `GoogleSans-Italic.ttf`, все веса → `wght 700`.

Алиасы `sans-serif-thin`, `sans-serif-light`, `sans-serif-medium`, `sans-serif-black`, `arial`, `helvetica`, `tahoma`, `verdana` идут через `sans-serif`, поэтому жирными становятся автоматически.

### Почему именно так

Кириллица закрывается дважды, и это принципиально:

1. **Основное семейство.** Используется `GoogleSans-Regular.ttf`, а **не** `GoogleSansFlex-Regular.ttf`. В Google Sans Flex **нет кириллицы вообще** — 508 глифов, только латиница. В обычном Google Sans её 220 символов, включая `ї`, `і`, `є`.
2. **Fallback.** В `font_fallback.xml` семейства `roboto`, `roboto-flex` и `source-sans-pro` — единственные, кто покрывает кириллицу в стоковой AOSP. Если их убрать, кириллица уходит в `serif` → Noto Serif, то есть выглядит как Times New Roman.

Отдельно стоит сказать, почему `fontWeightAdjustment` не решает задачу: он добавляет вес только вариативным шрифтам и только в `TextView`. Приложения с собственной вёрсткой (Telegram рисует всё сам) его не видят вообще.

## Установка

1. Скачай `GoogleSansBold-v3.0.zip` из релизов
2. KernelSU / KernelSU Next / Magisk → Модули → Установить из хранилища
3. Ребут

Требования: Android 13+ (на старше нет `font_fallback.xml` — модуль это переживёт, но перекроет только `fonts.xml`) и Google Sans в прошивке.

### Google Sans не входит в модуль

Файлы Google Sans проприетарные, поэтому их нет в архиве и в этом репозитории. Модуль копирует их при установке из `/product/fonts` (или `/system/fonts`, `/system_ext/fonts`, `/vendor/fonts`, `/odm/fonts`). В сборках с `vendor/pixel/gsans` они уже есть — это проверяется на этапе установки, и если файла нет, модуль откажется ставиться с понятным сообщением.

## После установки

**Выключи тумблер «Жирный»** в настройках дисплея. Он добавит +500 поверх, будет двойной жир. Модуль уже переводит все начертания на 700.

**Конфликты.** Установщик откажется работать, если другой модуль уже перекрывает `fonts.xml`, `fonts_base.xml` или `font_fallback.xml`. Взаимоисключающе с GoogleSansMax, MFGA, Google Sans Prime и любыми OMF-модулями на базе Oh My Font.

**Конфликт с GSP, кстати, не случаен.** Google Sans Prime на Android 15+ патчит оба XML и в `fontspoof` удаляет семейства `source-sans-pro`, `roboto-flex` и `roboto` — но проверка `SPOOF` в коде идёт **после** этих удалений, так что `SPOOF = false` их не отменяет. Флаги, которые отменяют: `RBT = true` и `RBTF = true`.

## После обновления прошивки

Система могла поменять `fonts.xml`. Открой модуль в менеджереroot → **Действие** → он пересоберёт оба файла из сохранённых оригиналов → ребут.

## Настройка

Всё в `lib/genfont.sh`:

```sh
FIXED_WEIGHT=700    # вес для всех начертаний; у Google Sans диапазон 400..700
OPSZ=18             # оптический размер, у GoogleSans-Regular ось opsz = 17..18
FONT_FILE="GoogleSans-Regular.ttf"
FONT_ITALIC="GoogleSans-Italic.ttf"
```

Если хочется не максимум, а иерархию — `FIXED_WEIGHT=500`, тогда обычный текст будет Medium, а `Black` упрётся в 700.

## Что НЕ перекрывается

- моноширинный — `GoogleSansCode.ttf` тоже без кириллицы, оставлен системный, иначе русский в терминалах уедет в fallback
- `serif`, `source-sans-pro`, `casual`, `cursive`
- семейства `variable-*` и `/product/etc/fonts_customization.xml` (Pixel-специфичные)

## Как это проверялось

Патч собирается скриптом на устройстве из настоящего `fonts.xml`: на стоковом файле меняются ровно четыре блока семейств, остальное остаётся байт в байт (1611 строк в `fonts.xml`, 559 в `font_fallback.xml`, все 160 семейств и 24 алиаса на месте). Проверено на `bash` и `zsh`, повторная сборка идемпотентна.

## Настройка без терминала

В модуле есть WebUI: **KernelSU Next → Модули → Google Sans Bold → шестерёнка**.

- четыре кнопки начертания: 400 Обычный, 500 Средний, 600 Полужирный, 700 Жирный
- переключатель `sans-serif-condensed`
- «Применить» и «Применить и перезагрузить»

Выше 700 вариантов нет намеренно: у Google Sans диапазон `wght` 400–700, всё остальное Minikin всё равно зажмёт. Границы проверяются и в WebUI, и в `rebuild.sh`.

Настройки лежат в `config.conf` рядом с модулем:

```
WEIGHT=700
OPSZ=18
CONDENSED=1
```

WebUI пишет этот файл через `rebuild.sh`, который затем пересобирает все три XML из оригиналов, сохранённых при установке. Поэтому после обновления прошивки модуль переустанавливать не нужно — достаточно запустить действие модуля.

API WebUI принимает колбэк по имени в глобальной области, поэтому обработчик висит на `window.onShell`:

```javascript
window.onShell = onShell;
ksu.exec('cat ' + dir + '/config.cfg', 'onShell');
```

Если открыть `index.html` обычным браузером, страница покажет подсказку — это ожидаемо, нужны права KernelSU.
