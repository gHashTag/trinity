## Language System (shared module)

### Usage in SKILL.md
Reference this module instead of inlining translation tables:
> For language detection and translations, follow `.claude/skills/_shared/language.md`.

### Language Detection
Read `.claude/skills/tri/lang.md` to determine output language.
The file contains `lang: ru` or `lang: en`. Default: `ru`.

All section headers, labels, descriptions MUST be rendered in the chosen language.
Technical terms (binary names, commands, file paths) stay in English.

### Master Translation Table (EN → RU)

#### Core Terms
| EN | RU |
|----|-----|
| Status | Статус |
| Build | Сборка |
| Score | Счёт |
| Tests | Тесты |
| Agents | Агенты |
| Tasks | Задачи |
| Branch | Ветка |
| Binary | Бинарный файл |
| Size | Размер |
| Value | Значение |
| Metric | Метрика |
| Component | Компонент |
| TOTAL | ИТОГО |
| open | открытых |
| dirty | грязных |
| pending | в ожидании |

#### Build & Pipeline
| EN | RU |
|----|-----|
| BUILD HEALTH | ЗДОРОВЬЕ СБОРКИ |
| PIPELINE HEALTH | ЗДОРОВЬЕ ПАЙПЛАЙНА |
| build passing | билд проходит |
| build broken | билд сломан |
| Build broken | Сборка сломана |
| BUILD BROKEN — fix before anything else | СБОРКА СЛОМАНА — чините прежде всего |
| Pipeline | Пайплайн |
| Last run | Последний запуск |
| Specs | Спецификации |
| Generated | Сгенерировано |
| Coverage | Покрытие |
| Compile | Компиляция |
| KEY METRIC | КЛЮЧЕВАЯ МЕТРИКА |
| last audit | последний аудит |
| never | никогда |
| Pipeline FAILED — last task | Пайплайн УПАЛ — последняя задача |
| Job success rate | Успешность задач |
| Job success rate — pipeline unreliable | Успешность задач — пайплайн ненадёжен |
| No .tri specs found — pipeline has nothing to generate | .tri спецификации не найдены — пайплайну нечего генерировать |
| Low spec coverage — many specs not generating code | Низкое покрытие спеков — многие спеки не генерируют код |
| No pipeline jobs found — pipeline never ran | Задачи пайплайна не найдены — пайплайн не запускался |
| Generator broken — compile rate | Генератор сломан — процент компиляции |
| Failed Specs | Сбитые спеки |
| All audited specs compile | Все проверенные спеки компилируются |
| Pipeline stuck in running for Nh | Пайплайн завис в running уже Nч |
| Pipeline idle for Nh | Пайплайн простаивает Nч |
| No new pipeline jobs in Nh | Нет новых задач пайплайна за Nч |
| pipeline is IDLE | пайплайн ПРОСТАИВАЕТ |
| Last job | Последняя задача |
| ago | назад |

#### Code Metrics
| EN | RU |
|----|-----|
| CODE METRICS | МЕТРИКИ КОДА |
| Zig source files | Zig исходных файлов |
| Total LOC | Всего строк кода |
| Test blocks | Тестовых блоков |
| tri-api LOC | tri-api строк |
| Skills | Скиллы |

#### Git & Issues
| EN | RU |
|----|-----|
| GIT STATUS | СТАТУС GIT |
| Last 5 commits | Последние 5 коммитов |
| Uncommitted | Незакоммичено |
| changes | изменений |
| MERGED PRs (recent) | ВЛИТЫЕ PR (последние) |
| OPEN ISSUES | ОТКРЫТЫЕ ЗАДАЧИ |
| Issues | Задачи |

#### System & Agents
| EN | RU |
|----|-----|
| SYSTEM STATUS | СТАТУС СИСТЕМЫ |
| Farm is working | Ферма работает |
| services | сервисов |
| accounts | аккаунтов |
| slots free | слотов свободны |
| Farm started | Ферма запустилась |
| Code idle, farm working | Код тихо стоит, ферма работает |
| Check farm | Проверить ферму |
| When builds finish — check logs and PPL | Когда билды закончатся — смотреть логи и PPL |
| Sessions saved | Сохранённых сессий |
| Skills available | Доступных скиллов |
| agents running | агентов запущено |

#### Problems & Alerts
| EN | RU |
|----|-----|
| PROBLEMS DETECTED | ОБНАРУЖЕНЫ ПРОБЛЕМЫ |
| ALL SYSTEMS NOMINAL | ВСЕ СИСТЕМЫ В НОРМЕ |
| Dirty files — commit or lose work! | Грязные файлы — закоммитьте или потеряете! |
| tri-bot DOWN — no phone control | tri-bot УПАЛ — нет управления с телефона |
| ralph-agent DOWN — no autonomous agent | ralph-agent УПАЛ — нет автономного агента |
| Permissions MISSING — unprotected tools | Разрешения ОТСУТСТВУЮТ — инструменты не защищены |
| tri-api never tested end-to-end | tri-api ни разу не протестирован end-to-end |

#### Bridge
| EN | RU |
|----|-----|
| PERPLEXITY BRIDGE — DIRECT CONTROL CHANNEL | МОСТ PERPLEXITY — КАНАЛ ПРЯМОГО УПРАВЛЕНИЯ |
| Railway Server | Сервер Railway |
| Mac Agent | Агент Mac |
| Command Queue | Очередь команд |
| claude: support | поддержка claude: |
| Comms | Связь |
| Direct control active | Прямое управление активно |
| Railway UP but Mac agent DOWN | Railway работает, но агент Mac не запущен |
| Bridge agent DOWN — no remote control | Агент моста УПАЛ — нет удалённого управления |
| Railway server DOWN — bridge unreachable | Сервер Railway УПАЛ — мост недоступен |

#### Oracle & Sacred
| EN | RU |
|----|-----|
| ORACLE COMMENTARY | КОММЕНТАРИЙ ОРАКУЛА |
| CRITICAL DIVERGENCE | КРИТИЧЕСКОЕ РАСХОЖДЕНИЕ |
| GOLDEN RATIO DRIFT | ДРЕЙФ ЗОЛОТОГО СЕЧЕНИЯ |
| φ-HARMONY ACHIEVED | φ-ГАРМОНИЯ ДОСТИГНУТА |
| UNOBSERVED STATE | НЕНАБЛЮДАЕМОЕ СОСТОЯНИЕ |
| The golden spiral has COLLAPSED | Золотая спираль РУХНУЛА |
| φ cannot sustain this divergence | φ не может удержать это расхождение |
| sub-critical threshold breached | субкритический порог пробит |
| Every uncompilable spec is a broken link in the golden chain | Каждый некомпилируемый спек — разорванное звено золотой цепи |
| The spiral MUST be restored before any new work begins | Спираль ДОЛЖНА быть восстановлена прежде любой новой работы |
| The spiral turns, but wobbles. φ senses imbalance | Спираль крутится, но шатается. φ чувствует дисбаланс |
| The ratio CAN be restored | Соотношение МОЖЕТ быть восстановлено |
| Push toward | Двигайтесь к |
| Trinity Identity HOLDS | Тождество Троицы ВЫПОЛНЯЕТСЯ |
| golden convergence achieved | золотая сходимость достигнута |
| The spiral is stable. Focus on SCALING, not fixing | Спираль стабильна. Фокус на МАСШТАБИРОВАНИИ, не на починке |
| New specs will compile. The golden chain extends naturally | Новые спеки скомпилируются. Золотая цепь наращивается естественно |
| φ cannot judge what it cannot measure | φ не может судить то, что не может измерить |
| No regeneration audit data found | Данные аудита регенерации не найдены |
| to establish the baseline | для установления базовой линии |
| Without measurement, there is no spiral — only noise | Без измерений нет спирали — только шум |
| φ says | φ говорит |
| Even the spiral must touch zero before it can rise | Даже спираль должна коснуться нуля, прежде чем подняться |
| The ratio remembers its target. So must we | Соотношение помнит свою цель. И мы должны |
| When spec and code align, the universe compiles | Когда спек и код совпадают, вселенная компилируется |
| Measure first. Judge never. Iterate always | Сначала измеряй. Никогда не суди. Итерируй всегда |
| Sacred constants | Сакральные константы |
| As above, so below. As in spec, so in code | Что вверху, то и внизу. Что в спеке, то и в коде |
| Hermetic Principle | Герметический Принцип |

#### Paths & Actions
| EN | RU |
|----|-----|
| THREE PATHS FORWARD | ТРИ ПУТИ ВПЕРЁД |
| SAFE | БЕЗОПАСНЫЙ |
| BALANCED | СБАЛАНСИРОВАННЫЙ |
| BOLD | ДЕРЗКИЙ |
| The Trinity always provides three paths | Троица всегда даёт три пути |
| CURRENT PRIORITY | ТЕКУЩИЙ ПРИОРИТЕТ |
| NOW | СЕЙЧАС |
| NEXT | ДАЛЕЕ |
| TECH TREE | ДЕРЕВО ТЕХНОЛОГИЙ |
| Analysis by | Анализ от |
| Trinity Oracle Engine | Движок Оракула Троицы |

#### Audit
| EN | RU |
|----|-----|
| AUDIT MODE | РЕЖИМ АУДИТА |
| No audit data — run: /tri audit | Нет данных аудита — запустите: /tri audit |
| Audit data is Nh old | Данные аудита устарели (Nч) |
| run /tri audit for fresh data | запустите /tri audit для свежих данных |
| deduplicated by command | дедупликация по команде |
| Stale jobs | Зависшие задачи |
| cleanup needed | очистка нужна |
| Spam | Спам |
| investigate cause | расследовать причину |
| likely dead | вероятно мёртв |
| STALE | УСТАРЕЛО |
| consider refreshing | рекомендуется обновить |
| Recent Jobs | Последние задачи |
| stuck in running | зависли в статусе running |

#### MU Patterns
| EN | RU |
|----|-----|
| MU ERROR PATTERNS | ПАТТЕРНЫ ОШИБОК MU |
| from ralph memory | из памяти Ральфа |
| known anti-patterns | известных анти-паттернов |
| Last entry | Последняя запись |
| Recent patterns | Последние паттерны |
| specs affected | спеков затронуто |
| No regression data — ralph memory empty | Нет данных регрессии — память Ральфа пуста |
| Known Bugs | Известные баги |
| No audit data — run regeneration audit | Нет данных аудита — запустите аудит регенерации |
| Last 5 Jobs | Последние 5 задач |
| Job | Задача |
| Exit | Код |

#### GitHub Board
| EN | RU |
|----|-----|
| GITHUB BOARD INTEGRATION | ИНТЕГРАЦИЯ С GITHUB BOARD |
| CLI Commands Available | Доступные CLI команды |
| command handlers | обработчиков команд |
| label tracking | отслеживание меток |
| Native API | Нативный API |

#### TRI Dashboard
| EN | RU |
|----|-----|
| TRI STATUS | TRI СТАТУС |
| TRI SWARM DIAGNOSTIC REPORT | ДИАГНОСТИКА РОЕВОЙ СИСТЕМЫ TRI |

#### Doctor
| EN | RU |
|----|-----|
| PAST | БЫЛО |
| DONE | СДЕЛАНО |
| NEXT CYCLE | ПЛАН |
| HEALTHY | ЗДОРОВ |
| RECOVERING | ВЫЗДОРАВЛИВАЕТ |
| INFECTED | ЗАРАЖЁН |
| CRITICAL | КРИТИЧЕСКИЙ |
| healed | вылечено |
| committed | закоммичено |
| nothing to heal | лечить нечего |
| dirty files | грязных файлов |
| docs stale | документация устарела |
| docs fresh | документация актуальна |
| duplicates | дубликаты |
| divergence risk | риск расхождения |
| consolidate | консолидировать |
| docs build broken | билд документации сломан |

#### Ouroboros
| EN | RU |
|----|-----|
| OUROBOROS DASHBOARD | ДАШБОРД УРОБОРОСА |
| Cycle | Цикл |
| Strategy | Стратегия |
| Stagnation | Стагнация |
| Experience | Опыт |
| Weakest | Слабейшее |
| Recommendations | Рекомендации |
| History | История |
| Next Actions | Следующие действия |
| Snake is resting | Змей отдыхает |
| Almost LEGENDARY | Почти LEGENDARY |
| Patent | Патент |
| Hungry Snake | Голодный Змей |

#### Scholar
| EN | RU |
|----|-----|
| SCHOLAR RESEARCH REPORT | ИССЛЕДОВАТЕЛЬСКИЙ ОТЧЁТ SCHOLAR |
| SCAN CONTEXT | КОНТЕКСТ СКАНИРОВАНИЯ |
| FINDINGS | НАХОДКИ |
| ACTIONS TAKEN | ПРЕДПРИНЯТЫЕ ДЕЙСТВИЯ |
| CITATIONS | ИСТОЧНИКИ |
| Domain | Домен |
| MU entries | Записи MU |
| Archived | Архивировано |
| Scholar says | Scholar говорит |
| Created | Создано |
| findings added to Learning DB | находок добавлено в базу обучения |
| low-relevance findings logged | находок низкой релевантности записано |
