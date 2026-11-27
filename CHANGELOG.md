# Changelog

## 1.1.2

- Auction/Detail feature detection + mock integration tests.
- DB caps for itemMeta, prune after scan/detail.
- Localization: Money, ingredient sources, chart subtitle, scan duration, source fallback.
- Architecture: MarketStore/MarketQuery, ItemMeta/Formatting, core Init/Commands.
- CatalogMeta integrity check (build/date/count/schema).
- Static craft-use index and gear-only DE in catalog chains.
- MCP tool contract (`mcp/tools.json`).

## 1.1.1

- Code review fixes: `MarketService` missing `nowDay`, `RecipeService` missing
  `L`/`Core.buildRecipe`/`Core.cheapestPrice`, stale `bagScanFrame` (bag hooks removed).
- Static craft-use index (no full chain calc on every tooltip).
- `ItemService`: no request storm for itemLevel 0, classCache invalidation.
- Median prices in recipe/ingredient calculations.
- Auction/Detail optional-event registration and `GetBrowseResults` guard.
- Review document: `docs/code-review-2026-11-27.md`.

## 1.1.0

- Архитектура разбита на сервисы: Price/Market/Flip/Chain/Recipe/Component/Farming/Advisor/Export.
- Каждый Lua-файл ≤ 300 строк; каталог разбит на 10 чанков.
- PriceService: volume-weighted median, p25/p75, MAD, confidence.
- Приоритетное докачивание цен по ожидаемой прибыли; покрытие профессий.
- DE: исправлены MATERIALS-алиасы (почему DE всегда был 0), itemMeta-кэш, estimated-флаг.
- Реалистичная прибыль: saleProbability, deposit, expectedProfit, riskCapital.
- Фарм: score с yield/respawn/travel/competition, сессии и золото/час, датасет кожи.
- UI: поиск по цепочкам, ожидаемая прибыль и формула в подсказке.
- DB: schemaVersion=2, миграции, лимит истории/записей.
- `/fa advice`, `/fa export`, `/fa farmstart`, `/fa farmstop`.
- tests/ + GitHub Actions (luac, лимит строк, unit-тесты).
- LICENSE MIT.

## 1.0.4

- Popup-подсказка вместо громоздких меток на иконках инвентаря.
- Рекомендуемая цена, текущий минимум и предупреждение о демпинге в подсказке предмета.
- DE-fallback для предметов без точного ilvl/качества; `—` вместо ложного нуля.
- Отрицательные цепочки скрыты.
- Подсказка цепочки: что купить → что скрафтить → что расщепить/продать → прибыль/ROI.
- DIAG: `/fa bagtest`.

## 1.0.3

- Принудительная инициализация меток/хуков по `/fa bagtest`.
- Хуки `SetBagItem`, `SetInventoryItem`, `SetHyperlink`.

## 1.0.2

- Повторная регистрация Baganator-виджета, BAG_UPDATE.
- Подсказка цепочки с покупкой/крафтом/DE/продажей.

## 1.0.1

- Метки сумок, рекомендуемая цена, предупреждение о демпинге.

## 1.0.0

- Вкладка «Фарм»: рейтинг зон трав/руды по GatherMate2, рейтинг видов кожи.

## 0.9.3

- Вкладка «Компоненты», описания вкладок по кнопке `?`, исторический фильтр.

## 0.9.2

- Фильтр цен вне медианы, метки Baganator, покрытие цен и «Докачать цены».

## 0.9.1

- `/fa allprof` работает по каталогу без открытия окна профессии.

## 0.9.0

- Раскрытие цепочек, метки инвентаря, скроллбары, подсказки колонок/вкладок.

## 0.8.0

- Каталог рецептов, вкладка «Профессии», глобальные цепочки, метки ценности.

## 0.7.0

- Сортировка колонок, клик по предмету ищет его на аукционе, вкладка «Цепочки».

## 0.6.1

- Линейный график, прокрутка не перекрывает кнопки.

## 0.6.0

- «Сканировать все профессии» без открытия окон.

## 0.5.0

- Неизученные рецепты, источник рецепта, вкладка «Ингредиенты».

## 0.4.0

- Экипировка в флипах.

## 0.3.0

- Детальный скан, «ресайл»-флипы, докачка цен рецептов.

## 0.2.1

- Исправлен слой `TOOLTIP` у графика.
