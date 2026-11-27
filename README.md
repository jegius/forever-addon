# ForeverAddon

Аналитический аддон для **World of Warcraft: Forever**: сканирует аукцион, хранит историю цен, ищет
флипы, считает прибыль рецептов, крафтящихся компонентов и цепочек «крафт → распыление», помогает
выбирать профессию и зоны легального фарма.

**Аддон ничего не нажимает, не читает экран и не управляет персонажем.** Он работает только с
разрешённым игровым API и SavedVariables; все действия в игре выполняет человек.

> **Статус: v1.2.2.** Архитектура разбита на сервисы; каждый Lua-файл ≤ 300 строк. Есть unit-тесты
> и GitHub Actions. Код проверен статически и mock-тестами, в игре — ещё нет; сделайте бэкап `WTF`.
> Ревью: [docs/code-review-2026-11-27.md](docs/code-review-2026-11-27.md). MCP: [mcp/README.md](mcp/README.md).

## Возможности

- Скан аукциона через `C_AuctionHouse.SendBrowseQuery`.
- Детальный скан до 60 товаров и 20 предметов экипировки: полная лестница цен, медиана, «ресайл».
- История цен по дням: минимум, объём, число сканов, сэмплы.
- Флипы: покупка дешёвого лота → продажа по следующему уровню, прибыль после 5% комиссии, ROI,
  надёжность, фильтр выбросов по медиане.
- График: линейный график дневной истории или точек сканов.
- Рецепты текущего персонажа и **глобальный каталог рецептов всех 12 профессий** (снимок данных
  WoW Forever Build 69876).
- Компоненты: крафтящиеся промежуточные ингредиенты, их себестоимость, рынок и прибыль.
- Цепочки: глобальные цепочки по каталогу; раскрытие ингредиентов, переход в аукцион по клику;
  подсказка «что купить → что скрафтить → что расщепить/продать».
- Рекомендуемая цена в popup-подсказке предмета: медиана, текущий минимум, предупреждение о
  демпинге; без громоздких меток на иконках.
- Лучшие зоны фарма трав/руды по GatherMate2 и рейтинг видов кожи.
- Сортировка всех таблиц, скроллбары, подсказки колонок и вкладок, кнопка `?` с описанием вкладки.
- **Поиск/фильтр цепочек** по рецепту, профессии или выходу.
- **Советник** `/fa advice`: здоровье рынка, топ флипов с confidence, guardrails.
- **JSON-экспорт** `/fa export` для локального MCP/LLM (без HTTP из аддона).
- **Сессии фарма** `/fa farmstart` / `/fa farmstop`: золото/час и история.
- Локализация ruRU/enUS.

## Установка

1. Скопируйте папку `ForeverAddon` в:
   `World of Warcraft\_forever_\Interface\AddOns\ForeverAddon`
2. Перезапустите клиент.
3. Проверьте, что аддон включён в списке аддонов.
4. Введите `/fa`.

TOC: `## Interface: 16001`, `## SavedVariables: ForeverAddonDB`.

## Команды

```text
/fa                 — открыть окно
/fa scan            — скан аукциона
/fa detail          — детальный скан лотов
/fa report          — сводка в чат
/fa allprof         — каталог всех профессий (без открытия окна)
/fa chains          — вкладка «Цепочки»
/fa professions     — рейтинг профессий
/fa components      — крафтящиеся компоненты
/fa prices          — докачать цены каталога (до 50 предметов)
/fa zones           — лучшие зоны фарма
/fa flips           — вкладка флипов
/fa chart <itemID>  — график предмета
/fa recipes         — рецепты персонажа
/fa farm            — зоны фарма
/fa roi <0..1>      — минимальный ROI
/fa profit <медь>   — минимальная прибыль
/fa history <дни>   — глубина истории
/fa test            — диагностика
/fa bagtest         — диагностика Baganator/хуков (для отладки)
/fa advice          — безопасный советник (без автокликов)
/fa export          — JSON-снимок в SavedVariables для локального MCP/LLM
/fa farmstart [zone]— старт сессии фарма
/fa farmstop        — стоп сессии, золото/час
```

## Структура

```text
ForeverAddon/
  ForeverAddon.toc
  Locales.lua / locales/{ruRU,enUS}.lua
  config/Database.lua          — SavedVariables, schemaVersion, миграции, pruning
  data/CatalogData.lua         — метаданные каталога
  data/CatalogChunk_01..10.lua — каталог рецептов (по ≤300 строк)
  data/CatalogMeta.lua        — проверка целостности каталога
  util/ItemMeta.lua            — предметы, классы, источники
  util/Formatting.lua          — деньги, проценты, числа
  services/PriceService.lua    — volume-weighted median, p25/p75, MAD, confidence
  services/MarketStore.lua     — запись истории/сканов, prune
  services/MarketQuery.lua     — чтение, кандидаты, график, обёртки
  services/FlipService.lua     — флипы и группы фарма
  services/DisenchantService.lua — DE-таблицы и fallback
  services/FarmingService.lua  — зоны, сессии фарма
  services/AuctionService.lua  — browse-скан
  services/DetailService.lua   — детальный скан
  services/RecipeCore.lua      — общие расчёты рецептов
  services/RecipeService.lua   — сканирование профессий
  services/RecipeListService.lua — списки/ингредиенты/сводка
  services/ChainService.lua    — цепочки, покрытие, приоритет цен
  services/ComponentService.lua — крафтящиеся компоненты
  services/AdvisorService.lua  — безопасный rule-based советник
  services/ExportService.lua   — JSON для локального MCP/LLM
  ui/State.lua, Widgets.lua, Sorting.lua, Panels.lua, Shell.lua,
  ui/Tooltips.lua, RefreshLists.lua, Chains.lua, RefreshCatalog.lua,
  ui/Guide.lua, Charts.lua
  core/Init.lua                — инициализация
  core/Commands.lua            — slash-команды
  mcp/server.js                — локальный MCP stdio сервер
  mcp/tools.json               — контракт внешнего советника
```

## Ключевые формулы

- Флип: `profit = resale * 0.95 - buy`, `ROI = profit / buy`.
- Цепочка: `cost = Σ(reagent_median * qty)`, `profit = max(direct_sale, de_value) * 0.95 - cost`.
- Ожидаемая прибыль: `profit * saleProbability - deposit`; вероятность оценивается по лотам/объёму.
- DE: ожидание по таблицам Classic (ilvl/качество); fallback помечается `estimated`.
- Зона фарма: `nodes * yield * price / (respawn + travel) * competition`.
- Выброс: после 2 дней истории/3 сэмплов цена, отличающаяся от медианы более чем на 50%,
  отбрасывается (`settings.maxDeviation`).
- PriceService: volume-weighted median, p25/p75, MAD, confidence.

## Ограничения

- Каталог рецептов — **снимок** данных, а не живой API; названия рецептов могут быть английскими.
- Цены/объёмы — только из вашего скана аукциона; без скана анализа нет.
- DE — вероятностная оценка; фактический результат случаен.
- GatherMate2 хранит узлы трав/руды, но **не** узлы снятия шкур; кожа ранжируется по видам.
- API не позволяет выбрать конкретный лот: клик по предмету открывает поиск в аукционе.
- Нет автоматизации кликов, чтения пикселей, эмуляции ввода и обхода античита.

## Разработка, тесты и ревью

```bash
lua5.1 tests/run.lua
```

CI: `.github/workflows/tests.yml` — `luac5.1 -p` для всех файлов, лимит 300 строк и unit-тесты.
Тесты покрывают PriceService, DE, каталог/цепочки, БД/миграции, advisor/export и загрузку TOC.

Полезные точки для code review:
- `services/PriceService.lua` — медианы/квантили/confidence.
- `services/MarketService.lua` — применение сканов, prune.
- `services/ChainService.lua` — себестоимость, покрытие, ожидаемая прибыль.
- `services/DisenchantService.lua` — таблицы и fallback.
- `ui/` — shell, панели, таблицы, подсказки.

AI-советник: [docs/ai-advisor.md](docs/ai-advisor.md).

## Данные и источники

- Каталог: [professions-data.json](https://maf2414.github.io/wow-forever-talents/professions-data.json)
  (WoW Forever Build 1.60.1.69876).
- GatherMate2 — локальные SavedVariables пользователя.
- Снимок каталога лежит в `data/` и не содержит персональных данных.

## Лицензия

MIT — см. [LICENSE](LICENSE).

## Безопасность

Проект не является ботом. Не добавляйте сюда автоклики, чтение экрана, эмуляцию ввода или обход
античита — это нарушает правила Blizzard и может привести к блокировке аккаунта.
