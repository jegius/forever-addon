# Code review — ForeverAddon 1.1.2

Дата: 2026-11-27. Ревью проведено по коду в `ForeverAddon/` и по mock/CI-тестам.
Формат: **Critical / High / Medium / Architecture / Roadmap**.

## Вердикт

Архитектура после разбиения стала заметно лучше: есть `PriceService`, `MarketService`,
`FlipService`, `ChainService`, `RecipeService`, `AdvisorService`, UI-слой отделён от расчётов.
Но в текущем виде код **ещё не production-ready**: при механическом разбиении потерялись
локальные функции/состояние, и часть путей падала бы только в игре (сканирование,
рецепты, bag-события). Критические найденные дефекты исправлены в этом проходе и покрыты тестами.

## Critical (исправлено в этом проходе)

### C1. `MarketService` не имел `nowDay`
`nowDay()` использовался в `RecordSample`, `ApplyScan`, `Prune`, `SetSelectedItem`, но после
разделения `Market.lua` остался локальным в `PriceService`. Любой скан/запись истории падали
с `attempt to call global 'nowDay' (nil)`.
**Исправлено:** локальный `nowDay` в `MarketService`; добавлен `tests/test_market.lua`.

### C2. `RecipeService` потерял `L`, `buildRecipe`, `cheapestPrice`
После выноса в `RecipeCore` в `RecipeService` остались вызовы `L(...)`, `pcall(buildRecipe, ...)`,
`cheapestPrice(reagent)`. Это ломало `ScanCatalog`/`StartScanAll`/`Finish`.
**Исправлено:** `local L`, `Core.buildRecipe`, `Core.cheapestPrice`; добавлен
`tests/test_recipe_scan.lua`.

### C3. `InitBagMarks` сохранял не тот frame
`self.bagScanFrame = UI.frame` вместо локального event-frame. Событие `BAG_UPDATE_DELAYED`
не попадало в обработчик, frame мог быть потерян. После перехода на popup-подсказку
bag-хуки вообще удалены как мёртвый код.
**Исправлено:** удалены `InitBagMarks`/`MarkBagButton`/`ScanContainerFrames`/`InitBaganator`;
`/fa bagtest` теперь только сообщает, что метки отключены.

### C4. DE всегда был 0
В таблицах DE использовались `strangeDust`, `lesserMagic` и т.д. как глобальные переменные,
которых не существовало; `MATERIALS[key]` был nil, цена 0. Это была главная причина «DE всегда 0».
**Исправлено:** алиасы `MATERIALS.*`; добавлен `tests/test_disenchant.lua`.

### C5. `GetCraftUseIndex` вызывал полный расчёт цепочек
`UI:GetItemCategory` вызывает `GetCraftUseIndex` на каждый предмет/тултип. Индекс строился через
`GetCatalogChains` (2354 рецепта, цены, DE), что давало фризы при наведении.
**Исправлено:** индекс строится статически по реагентам каталога и кэшируется по build.

### C6. `ItemService`: шторм запросов и устаревший classCache
`RequestLoadItemDataByID` вызывался при `itemLevel <= 0` — у реагентов/расходников это норма,
поэтому запросы шли на каждый предмет. `classCache` не очищался после `ITEM_DATA_LOAD_RESULT`,
поэтому classID=0 оставался навсегда.
**Исправлено:** запрос только при отсутствии name/classID; `classCache[itemID] = nil` в событии.

### C7. Разные цены у рецептов и цепочек
`RecipeCore.compute` и `GetIngredients` использовали `GetPrice` (min), цепочки — медиану.
Один предмет оценивался по-разному.
**Исправлено:** `cheapestPrice`/`GetIngredients` используют `PriceService:GetRecommendedPrice`
с fallback на min.

## High (требует внимания)

### H1. Auction API/event assumptions
- `AUCTION_HOUSE_BROWSE_RESULTS_ADDED` в retail **не передаёт payload**; код берёт `...`, что может
  быть nil. Сейчас основной путь — `..._UPDATED`, но добавлен только guard для `GetBrowseResults`.
- `C_AuctionHouse`/`GetBrowseResults` могут отсутствовать в Forever-клиенте/при смене API.
- `C_AuctionHouse.SendSearchQuery` вызывается из таймера; возможны ограничения/таймаут.
- `Auction:Finish` автоматически запускает detail-scan; при частых сканах можно упереться в лимит
  100 запросов/мин.
**Рекомендация:** pcall/feature-detect для всех методов, интеграционные тесты с mock
`C_AuctionHouse`, отключаемый auto-detail и бюджет запросов.

### H2. `GetCatalogChains` синхронно перебирает весь каталог
2354 рецепта × реагенты + DE + сортировка на каждое изменение `priceVersion`. На слабом ПК/при
открытии вкладки это заметный фриз. Кэш помогает, но первый вызов и смена настроек — тяжёлые.
**Рекомендация:** инкрементальный кэш по `itemID`, порционный расчёт через `C_Timer.After(0)`,
прогресс в UI, отмена устаревших расчётов по `requestToken`.

### H3. UI-таблицы без виртуализации
На 2000+ рецептов/цепочек создаются/обновляются все строки; `HideRows` скрывает, но layout
и `GetRow` остаются дорогими. Поиск есть только в цепочках.
**Рекомендация:** виртуализация (pool + visible range), поиск/фильтры во всех вкладках,
debounce ввода.

### H4. Локализация неполная
`Util:Money` всегда пишет `г/с/м`; `IngredientSource`, `sourceLabel` fallback, `Core.printReport`,
`UI:RefreshScan` (`"с"`), `Charts` (`"мин. цена, медь"`) содержат русские строки. enUS-локаль
фактически частичная.
**Рекомендация:** все строки в `Locales`, `Util` не должен форматировать валюту без locale.

### H5. SavedVariables может расти
`db.itemMeta` не ограничен; `db.exportJson` — полный снимок; `prices` обрезается только в
`DB:Init`, а `Market:ApplyScan` в течение сессии может добавить больше лимита. `samples` (20)
и `itemNames` не prune.
**Рекомендация:** cap для `itemMeta`/`exportJson`, `DB:Prune` после scan/detail, лимит `itemNames`,
счётчик размера в `/fa test`.

### H6. Tooltip-хуки и taint/производительность
`hooksecurefunc(GameTooltip, "SetBagItem"/"SetHyperlink")` + `OnTooltipSetItem` вызывают
`GetRecommendedPrice`, `GetLowOutlier`, `GetCraftUseIndex` на каждый показ. Индекс теперь дешёвый,
но проверка данных и `GetItemCategory` остаются. Нужно профилировать; возможно, кэшировать
category/price в `itemCache`.

### H7. `RecipeService:StartScanAll` имеет мёртвую ветку
При наличии `CatalogData` всегда вызывается `ScanCatalog`; код `enumerateAllProfessions`/`Step`
не используется. Это не ошибка, но увеличивает поверхность и путает ревью.
**Рекомендация:** оставить один путь — каталог; удалить/переписать старый скан.

### H8. Нет тестов Auction/Detail
Тесты покрывают Price/DE/Chain/DB/Advisor/Farming/UI smoke, но не реальные события
`C_AuctionHouse` и пагинацию `RequestMore...`. Это самые рискованные места после API.
**Рекомендация:** mock-события, page ladder, timeout/abort, 100/min бюджет.

## Medium

- `GetChains` (рецепты персонажа) считает только DE, а каталожные цепочки — direct+DE. Разная
  семантика; лучше один `ProfitCalculator`.
- `GetIngredients` схлопывает альтернативные реагенты в один `bestID`, теряя альтернативы;
  для аукциона это может выбрать неликвид.
- `RecipeCore.sourceLabel` fallback `"источник N"` и `SOURCE_LABELS` — локализация.
- `Disenchant:Estimate` fallback «последняя строка» для ilvl >65 может завышать/занижать;
  нужна таблица кастомных предметов или явный `estimated` (есть) + UI-предупреждение.
- `Farming:GetLeatherRanking`: `classID == 7 and leatherName(subtype) or leatherName(name)` —
  precedence работает, но читается плохо; вынести в `if`.
- `Farming` score-параметры (`yield/respawn/travel/competition`) не выводятся в UI и не
  настраиваются; пользователь не понимает цифру.
- `UI:MarkItem` оставляет вертикальную полоску в строке; после запроса «в попап» это
  компромисс, лучше убрать или сделать 1px и только для строк, не для сумок.
- `UI:RefreshScan` hardcoded `"с"`; `Charts` hardcoded подпись.
- `DB:Init` не делает backup при миграции; при ошибке schema можно потерять данные.
- `Catalog` — статический снимок; нет проверки build/checksum и предупреждения об устаревании.
- `GetCatalogChains` cache key не включает `catalog.build`; для статики пока ок, но при обновлении
  каталога без перезапуска будет stale.
- `PriceService:GetPriceStats` confidence — эвристика; не калибрована и не учитывает
  волатильность/MAD явно.
- `AdvisorService` — rule-based, не LLM; `/fa export` лишь отдаёт JSON, MCP-инструменты не подключены.
  Это нормально для безопасности, но назвать «AI-советником» можно только с оговоркой.
- `ExportService` JSON-энкодер не экранирует `\t`, `\b`, `\f`, невалидные UTF-8; для локального
  анализа обычно ок, но лучше использовать проверенный encoder.
- `TOC` нет `## Author`, `## X-Category`, `## IconTexture`; версия/интерфейс стоит проверить
  для Forever-клиента.

## Architecture / SOLID

### Что хорошо
- `PriceService` — единая ценовая политика, UI не считает медианы.
- `MarketService` — запись/история; `FlipService` — ранжирование; `ChainService` — цепочки.
- UI разбит на State/Widgets/Sorting/Panels/Shell/Tooltips/Refresh/Guide.
- `AdvisorService` отделён от UI; `ExportService` — отдельный адаптер.
- Тесты и CI появились; лимит 300 строк соблюдается.

### Что нарушает границы
1. `MarketService` смешивает **persistence** (`db.prices`), **агрегацию** (ApplyScan/Detail),
   **pruning** и **wrappers** PriceService. Лучше: `PriceRepository` + `MarketAggregator`.
2. `ItemService` — 300 строк и одновременно item meta, профессии, деньги, source, spell names.
   Разбить на `ItemMeta`, `Money`, `ProfessionNames`, `ItemSource`.
3. `RecipeCore` — «God object» helper-модуль: сканирование, schematic, compute, catalogPrice.
   Разделить `RecipeReader`, `RecipeProfit`, `CatalogPrice`.
4. `core/Core.lua` смешивает init/events/commands/printReport/printTest. Вынести
   `core/Events.lua`, `core/Commands.lua`, `core/Diagnostics.lua`.
5. `Database` смешивает defaults/schema/migration/storage/prune. Вынести `config/Schema.lua`.
6. `ns` — service locator; для аддона приемлемо, но зависимости неявные. Для тестов лучше
   передавать зависимости в `new()` или хотя бы документировать load-order.

## Roadmap улучшений

### P0 — до следующего релиза
1. Auction/Detail integration tests + feature detection.
2. `DB:Prune` после scan/detail; cap itemMeta/export.
3. Полная локализация `Money`, `IngredientSource`, `sourceLabel`, `Core`/`Charts`.
4. Убрать мёртвый `StartScanAll`/`bagtest` код или задокументировать.
5. Проверить `Interface`/C_AuctionHouse на реальном Forever-клиенте.

### P1 — производительность/UX
1. Инкрементальный/порционный `GetCatalogChains` с токеном отмены.
2. Виртуализация таблиц + поиск/фильтры во всех вкладках.
3. Настройки farming score в UI и объяснение.
4. Кэш `category/price` в `itemCache`, меньше работы на tooltip.

### P2 — данные/архитектура
1. Разделить `MarketService`/`ItemService`/`RecipeCore` по ответственности.
2. Схема каталога с build/checksum и обновлением.
3. Формальные unit-тесты для Auction/Detail/UI-событий.
4. MCP-инструменты `market_health/top_flips/craft_plan/...` поверх `exportJson`.

## Проверки

```text
lua5.1 tests/run.lua
→ price, market, recipe scan, disenchant, catalog/chain, database,
  advisor/export, farming, load-all, UI smoke — all passed
```

CI: `.github/workflows/tests.yml` — `luac5.1 -p`, лимит 300 строк, unit-тесты.

## Итог

Критические ошибки, которые гарантированно ломали бы скан/рецепты/DE, исправлены.
Следующий риск — **API-события аукциона и тяжёлые синхронные расчёты на 2354 рецептах**;
именно их нужно закрыть тестами и порционным расчётом перед тем, как считать аддон
production-ready.

## Обновление после roadmap-прохода

Закрыто в коде после первичного ревью:

- **H1/H8**: добавлены feature detection (`HasAPI`), guard для `GetBrowseResults`,
  mock-тесты `tests/test_auction.lua` и `tests/test_detail.lua`.
- **H5**: добавлены caps `maxMetaEntries`, pruning `itemMeta`; `DB:Prune` вызывается после
  scan/detail, а не только при входе.
- **Локализация**: `Money`, `IngredientSource`, `Charts`, `SCAN_SECONDS`, source fallback
  переведены на `ns.L`; добавлены enUS-ключи. Остались `Advisor`/часть diagnostic-текстов.
- **Архитектура**: `MarketService` разделён на `MarketStore`/`MarketQuery`; `ItemService` —
  на `ItemMeta`/`Formatting`; `Core` — на `Init`/`Commands`.
- **Catalog**: добавлен `CatalogMeta` с build/date/count/schema и проверкой целостности.
- **Craft index**: статический, без полного пересчёта цепочек на tooltip.

Осталось на следующие проходы: H2 (порционный `GetCatalogChains`), H3 (виртуализация UI),
H6 (профилирование tooltip-хуков), H7 (мёртвый `StartScanAll`), MCP-инструменты поверх
`exportJson`.

