# World of Warcraft: Forever — заметки по разработке аддонов

Собрано 7 ноября 2026 года. Часть сведений получена из беты и публичных гайдов, а не из финального
клиента, поэтому всё, что помечено «проверить», нужно перепроверить в игре на установленном билде
`1.60.1.70790`.

## 1. Что за клиент

- **World of Warcraft: Forever** — отдельный игровой клиент Blizzard, запущен 4 ноября 2026 года
  (уровневый кап 60, классический Азерот, но современный интерфейс). Установлен локально в
  `C:\Program Files (x86)\World of Warcraft\_forever_`.
- Локально подтверждено:
  - `.flavor.info` → `wowf`; `.build.info` → `Version 1.60.1.70790`, `Product wowf`;
  - `Wow.exe` → `FileVersion 1.60.1.70790`;
  - `WTF\Config.wtf` → `engineSurveyPatch "16001"`, `lastAddonVersion "16001"`;
  - в `Interface\AddOns` стоят сторонние аддоны (Auctionator, Baganator, Wayfarer и др.), их TOC
    объявляют `16001` наряду с `120100`/`120105` (Retail 12.1.x) и `11509` (Classic Era).
- Публичные источники: [Wowhead](https://www.wowhead.com/forever/news/wow-forever-will-have-addon-changes-from-midnight-382921),
  [wowforever.be](https://wowforever.be/news/wow-forever-addon-changes-from-midnight/),
  [гайд по аддонам](https://wowforeverguides.com/addons/developers).

## 2. TOC: версия интерфейса и тип игры

Минимальный TOC для аддона только под Forever:

```text
## Interface: 16001
## Title: My Addon
## Notes: ...
## Version: 0.1.0

Core.lua
```

- `16001` — версия интерфейса Forever (ветка 16.0.1). Подтверждают Warcraft Wiki
  ([TOC format](https://warcraft.wiki.gg/wiki/TOC_format)), гайд и TOC установленных аддонов;
  Forever-only аддоны в природе объявляют только это значение (например,
  [Questie_Camelot.toc](https://raw.githubusercontent.com/Questie/Questie/master/Questie_Camelot.toc)).
  Проверить в игре: `/dump select(4, GetBuildInfo())`.
- Одного совпадающего значения достаточно. Перечисление через запятую
  (`## Interface: 16001, 120105, 11509`) нужно только для одного пакета под несколько клиентов.
  Несовпавший Interface помечает аддон как «out of date», но загрузить его всё равно можно.
- Тип игры Forever в клиенте называется **Camelot**: `camelot` — родное значение, `forever` —
  алиас, добавленный в 1.60.1 ([TOC format](https://warcraft.wiki.gg/wiki/TOC_format)).
  `wowhack` — это другой тип игры (Talebound), не Forever.
- `## Game` / `## GameType` директивы не существует. `[Game]` — это переменная в имени файла в TOC
  (`[Game]\File.lua`), а `_Camelot.toc` / `_Forever.toc` — суффиксы flavor-файлов TOC.
- **`## AllowLoadGameType` не используем как защиту для Forever-only аддона:** если ни один из
  перечисленных токенов не распознан, условие всё равно проходит. Ограничиваемся `## Interface`.
- Имя папки аддона и имя `.toc`-файла должны совпадать: `ForeverAddon\ForeverAddon.toc`.
- TOC читается построчно: порядок строк = порядок загрузки файлов; путь к подпапкам — через `\`;
  длина строки — до 1024 символов; UTF-8 **без BOM** (все локальные TOC начинаются с `## `).
  Неизвестные `##`-директивы игнорируются (поведение не документировано Blizzard).
- `## Version` не обязателен для `16001`; он нужен только для тултипа и апдейтеров.

Полезные поля TOC (современный формат):

| Поле | Назначение |
| --- | --- |
| `## Interface` | версия интерфейса клиента |
| `## Title`, `## Notes`, `## Notes-ruRU` | название и описание (можно с локалью) |
| `## Version`, `## Author` | версия и автор |
| `## SavedVariables` | глобальные таблицы, сохраняемые между сессиями |
| `## SavedVariablesPerCharacter` | то же, но на персонажа |
| `## Dependencies`, `## OptionalDeps` | обязательные/необязательные зависимости |
| `## LoadSavedVariablesFirst` | загрузить SavedVariables до файлов аддона |
| `## IconTexture` | иконка в списке аддонов (путь внутри `Interface\...`) |
| `## Category` | категория в списке аддонов |
| `## AddonCompartmentFunc` | функция для кнопки в Addon Compartment |
| `## AllowLoadGameType` / `## ExcludeLoadGameType` | ограничение по типу игры (см. предупреждение выше) |

SavedVariables пишутся в `WTF\Account\<account>\SavedVariables\` (общие) и
`WTF\Account\<account>\<realm>\<character>\SavedVariables\` (per-character).

## 3. Lua и API

- **Lua 5.1** (модифицированная): нет `goto`, `//`, `_ENV`, битовых операторов; для битов — `bit.*`.
  Нет `require`, `dofile`, `loadfile`, `io`, `os`. Порядок загрузки задаётся только TOC-файлом.
- Каждый файл начинается с `local addonName, ns = ...`; общее состояние живёт в `ns`, глобалы —
  только SavedVariables, slash-команды и колбэки, названные в TOC.
- Forever использует **Mainline-архитектуру**: «vast majority of APIs available in 12.1.5» плюс
  ограничения Midnight ([Wowhead](https://www.wowhead.com/forever/news/wow-forever-will-have-addon-changes-from-midnight-382921)).
  Это не Classic API.
- На бете (build 69913) отсутствовали глобалы `GetSpellInfo`, `GetItemInfo`,
  `GetSpellBookItemName`, `GetNumTalentTabs`, `GetTalentInfo`, `GetNumSkillLines`. Вместо них —
  `C_Spell.GetSpellInfo` (возвращает таблицу) и `C_Item.GetItemInfo` (несколько значений, как старый
  глобал). Оба могут вернуть `nil`, пока данные не закэшированы; нужны
  `C_Spell.RequestLoadSpellData` / `C_Item.RequestLoadItemDataByID` и события загрузки.
  **Проверить на 70790.**
- `WOW_PROJECT_ID`: на бете build 69913 возвращал `1` (Mainline), на build 70338 — `18`
  (`WOW_PROJECT_CAMELOT`). Нельзя строить логику «Forever или Classic» только по этому числу;
  надёжнее проверять наличие нужного API и `select(4, GetBuildInfo())`.
- **Combat log**: на Midnight регистрация `COMBAT_LOG_EVENT_UNFILTERED` приводит к ошибке; на Forever
  `CombatLogGetCurrentEventInfo` для аддонов недоступен (по отчётам беты). Не делать damage/healing
  meters и босс-моды на парсинге лога. **Проверить на 70790.**

## 4. Ограничения Midnight, которые переносятся на Forever

- **Secret values.** Игра скрывает часть данных от аддонов: значения можно сохранять, передавать и
  конкатенировать, но **нельзя** применять арифметику, сравнения/булевы проверки, `#`, использовать
  как ключи таблиц. Проверять `issecretvalue(value)` / `canaccessvalue(value)`. Некоторые виджет-сеттеры
  принимают секреты (например, `StatusBar:SetValue`) и сами применяют «секретные» аспекты —
  здоровье лучше передавать напрямую в `StatusBar:SetMinMaxValues` / `SetValue`
  ([Secret Values](https://warcraft.wiki.gg/wiki/Secret_Values)).
- На бете Forever ограничения строже, чем в Retail: сила игрока и здоровье цели — секретные даже вне
  боя; ауры и кулдауны — секретные в бою; **любое чтение аур в бою бросает ошибку**, а
  `UnitAura`/`UnitBuff`/`UnitDebuff` вообще удалены ([Forever probe plan](https://raw.githubusercontent.com/wealdly/justac/1959fbc7f1d1b895435730d55bfcd0b54064fa50/Documentation/FOREVER_PROBE_PLAN.md)).
  **Проверить на 70790.**
- **AuraContainer / AuraButton** (изменения 12.1.0) — поддерживаемый способ показывать информацию об
  аурах: создаются из шаблонов Blizzard, текстуры/кулдауны/полосы управляются color curves. Скрипты
  внутри кнопок заблокированы, обратного чтения состояния намеренно нет: это только отображение,
  по нему нельзя ветвиться ([Patch 12.1.0 API changes](https://warcraft.wiki.gg/wiki/Patch_12.1.0/API_changes),
  [INTRINSIC_AuraContainer](https://warcraft.wiki.gg/wiki/INTRINSIC_AuraContainer)).
- **Secure snippets**: на бете secure-сниппеты не компилировались (`loadstring_untainted`), из-за чего
  ломались click-casting и переключение action bar. Это может быть багом беты — не закладываться на
  сниппеты без проверки.
- `pcall` не делает защищённый вызов безопасным: возможен «Interface action failed because of an
  AddOn» без Lua-ошибки; счётчик сбрасывается только полным перезапуском клиента.
- `InCombatLockdown()` блокирует перемещение/показ защищённых фреймов; chat- и super-track вызовы
  защищены.
- Нельзя автоматизировать боевые решения; аддон должен скинить/информировать, а не играть за игрока.
- WeakAuras для Midnight/Forever нет: последняя версия не поддерживает Forever, а команда называет
  модель секретов технически несовместимой. Рассчитывать на неё как на зависимость нельзя.

## 5. Куда ставить аддон

```text
C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\ForeverAddon\
```

У каждого flavor своя папка `Interface\AddOns`: аддоны Retail/Classic из `_retail_`/`_classic_` сюда
не попадают. Новые папки аддонов клиент подхватывает при запуске (после добавления может
потребоваться перезапуск клиента).

## 6. Чек-лист перед первой реализацией

1. `/dump select(4, GetBuildInfo())` → `16001`.
2. `## Interface: 16001` в TOC; папка = имя TOC.
3. Нет `goto`/`//`/`_ENV`/`require`/`io`/`os`.
4. Каждый файл начинается с `local addonName, ns = ...`.
5. Нет `COMBAT_LOG_EVENT_UNFILTERED` и парсинга combat log.
6. Нет чтения аур в бою (`UnitAura` и т. п. удалены); для отображения аур — `AuraContainer`/`AuraButton`.
7. Значения юнитов проверяются через `issecretvalue`/`canaccessvalue` перед сравнением/печатью.
8. SavedVariables читаются в `ADDON_LOADED`, а не на верхнем уровне файла.
9. Изменения защищённых фреймов — после `InCombatLockdown()`/`PLAYER_REGEN_ENABLED`.
10. Нет ветвления «Classic/Retail» только по `WOW_PROJECT_ID`.

## 7. Открытые вопросы (перепроверить на релизном клиенте 70790)

- Не изменилась ли версия интерфейса `16001` к релизу.
- Доступны ли `GetSpellInfo`/`GetItemInfo` и прочие глобалы.
- Работают ли secure snippets (click-casting) и `COMBAT_LOG_EVENT_UNFILTERED`.
- Точное значение `WOW_PROJECT_ID`.
- Признаётся ли алиас `forever` (а не только `camelot`) на 70790.
- Насколько строги secret-ограничения на 70790 (замеры были на бета-билдах 69913–70338).

## 8. Ландшафт аддонов и выводы для проекта

- **GatherMate2** уже поддерживает Forever (`## Interface: 16001,120105,120107`, файл 1.60.1 от
  6 ноября 2026): память узлов трав/руды/сокровищ, пины на карте и миникарте, SavedVariables.
  Это базовый уровень, который нашему аддону нужно как минимум не хуже.
- **Routes** (редактор маршрутов, TSP-решатель) Forever не поддерживает (последний TOC 12.0.7,
  All Rights Reserved); **Gatherer** — только legacy; **GatherMate2_Data** не имеет данных Forever.
- Forever-нативные конкуренты: Xals Xpedited Routes (запись узлов + «оптимальный маршрут» + компас),
  ForeverGather (узлы + waypoints), DualTrack, ProfitHUB.ProfGuides / ForeverMaster, OpenRoad.
- **Ниша:** никто не связывает память узлов → маршрут с ограничениями (навык, вместимость сумок,
  риск) → план прокачки профессии. Xpedited ближе всех, но без danger-модели и profession-skill gating.
- **Данные:** координаты Wowhead/GatherMate2_Data нельзя бандлить (нет свободной лицензии). Свои узлы —
  только собранные игроком; импорт из установленного GatherMate2 — опциональная совместимость,
  без копирования GPL-кода.
- **Локальный ИИ:** аддон не имеет сети/файлов/ОС. Внешний companion общается через SavedVariables
  (при закрытой игре) или экспорт/импорт строкой; маршруты решает TSP/VRP (OR-Tools/deterministic),
  LLM — только план/объяснения. Пример архитектуры — [wow-ai](https://github.com/chelinho139/wow-ai).
- **Железо этой машины:** i5-14600KF, 64 ГБ RAM, RTX 4070 Ti 12 ГБ — Qwen3 4B/8B в Q4 помещаются;
  Ollama/LM Studio пока не установлены.

Подробная спецификация — [docs/spec.md](spec.md).

## Источники

- [GatherMate2](https://github.com/Nevcairiel/GatherMate2), [Routes](https://github.com/Nevcairiel/Routes),
  [wow-ai](https://github.com/chelinho139/wow-ai),
  [Xals Xpedited Routes](https://addon-radar.com/forever/addon/xals-xpedited-routes),
  [OR-Tools TSP](https://developers.google.com/optimization/routing/tsp),
  [Ollama Qwen3](https://ollama.com/library/qwen3)
- Blizzard: [UI Add-On Development Policy](https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534)
- Warcraft Wiki: [TOC format](https://warcraft.wiki.gg/wiki/TOC_format), [Secret Values](https://warcraft.wiki.gg/wiki/Secret_Values),
  [Patch 12.1.0/API changes](https://warcraft.wiki.gg/wiki/Patch_12.1.0/API_changes),
  [INTRINSIC_AuraContainer](https://warcraft.wiki.gg/wiki/INTRINSIC_AuraContainer)
- Wowhead: [WoW: Forever Will Have Addon Changes from Midnight](https://www.wowhead.com/forever/news/wow-forever-will-have-addon-changes-from-midnight-382921)
- wowforever.be: [Addon changes from Midnight carry over](https://wowforever.be/news/wow-forever-addon-changes-from-midnight/)
- WoW Forever Guides: [Addon Development Guide: Interface 16001](https://wowforeverguides.com/addons/developers),
  [Pitfalls](https://wowforeverguides.com/addons/pitfalls)
- Forever probe plan: [wealdly/justac](https://raw.githubusercontent.com/wealdly/justac/1959fbc7f1d1b895435730d55bfcd0b54064fa50/Documentation/FOREVER_PROBE_PLAN.md)
- Icy Veins: [Addons in WoW Forever](https://www.icy-veins.com/wow-forever/news/addons-in-wow-forever-blizzard-devs-just-addressed-the-big-question/)
- Blizzard: [Addon philosophy](https://worldofwarcraft.blizzard.com/en-us/news/24246290)
- Questie: [Questie_Camelot.toc](https://raw.githubusercontent.com/Questie/Questie/master/Questie_Camelot.toc)
- Локальная установка: `_forever_\.flavor.info`, `_forever_\Interface\AddOns\*\*.toc`,
  `_forever_\WTF\Config.wtf`.
