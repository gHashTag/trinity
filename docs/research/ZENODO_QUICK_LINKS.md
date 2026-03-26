# Zenodo Quick Links — Таблица быстрых ссылок

**Автор:** Дмитрий Васильев
**Дата:** 2026-03-26
**Версия:** 1.0

---

## DOI всех бандлов

| Код | Название | DOI | Ссылка |
|------|----------|-----|--------|
| **B001** | Ternarial Neural Networks | 10.5281/zenodo.19224354 | [https://doi.org/10.5281/zenodo.19224354](https://doi.org/10.5281/zenodo.19224354) |
| **B002** | Zero-DSP FPGA Architecture | 10.5281/zenodo.19224355 | [https://doi.org/10.5281/zenodo.19224355](https://doi.org/10.5281/zenodo.19224355) |
| **B003** | TRI-27 ISA | 10.5281/zenodo.19224356 | [https://doi.org/10.5281/zenodo.19224356](https://doi.org/10.5281/zenodo.19224356) |
| **B004** | Queen Lotus Cycle | 10.5281/zenodo.19224357 | [https://doi.org/10.5281/zenodo.19224357](https://doi.org/10.5281/zenodo.19224357) |
| **B005** | Tri Language | 10.5281/zenodo.19224360 | [https://doi.org/10.5281/zenodo.19224360](https://doi.org/10.5281/zenodo.19224360) |
| **B006** | Sacred GF16/TF3 | 10.5281/zenodo.19224361 | [https://doi.org/10.5281/zenodo.19224361](https://doi.org/10.5281/zenodo.19224361) |
| **B007** | VSA Operations | 10.5281/zenodo.19224362 | [https://doi.org/10.5281/zenodo.19224362](https://doi.org/10.5281/zenodo.19224362) |
| **PARENT** | Trinity S³AI Framework | 10.5281/zenodo.19224363 | [https://doi.org/10.5281/zenodo.19224363](https://doi.org/10.5281/zenodo.19224363) |

---

## Ключевые научные статьи (48)

### Калибровка (8)

| Статья | Год | DOI/arXiv |
|--------|-----|----------|
| Verbalized Confidence in LLMs (Full-ECE) | 2024 | [arXiv:2406.11345](https://arxiv.org/abs/2406.11345) |
| On Calibration of Modern NNs | 2017 | [arXiv:1706.04599](https://arxiv.org/abs/1706.04599) |
| Adaptive Calibration Error | 2024 | NeurIPS |
| Dynamic Calibration Error | 2024 | NeurIPS |
| Calibration under Prior Shift | 2024 | ICLR |

### Обнаружение загрязнений (4)

| Статья | Год | DOI/arXiv |
|--------|-----|----------|
| Min-K%++ Probabilities | 2024 | [arXiv:2404.02936](https://arxiv.org/abs/2404.02936) |
| CoDeC Context-based Detection | 2025 | [arXiv:2510.27055](https://arxiv.org/abs/2510.27055) |

### Статистика (10)

| Статья | Год | DOI/arXiv |
|--------|-----|----------|
| Better Bootstrap CI (BCa) | 1987 | JASA 82(397) |
| Comparing AUCs (DeLong) | 1988 | Biometrics 44(3) |
| Controlling FDR (BH) | 1995 | JRSS 57(1) |
| Statistical Power Analysis | 1988 | Erlbaum |

---

## Документация по категориям

### Научные руководства

| Документ | LOC | Описание |
|----------|-----|----------|
| `ZENODO_ADVANCED_PATTERNS_2026.md` | 700 | Передовые практики публикации |
| `SCIENTIFIC_METRICS_2026_PAPERS.md` | 390 | 48 научных статей |
| `STATISTICAL_COMPUTING_PATTERNS_2026.md` | 660 | Статистические паттерны |
| `REPRODUCIBILITY_GUIDE_2026.md` | 756 | Воспроизводимость |
| `STATISTICAL_QUICK_REFERENCE.md` | 287 | Шпаргалка |
| `GLOSSARY_RU_2026.md` | 335 | Глоссарий (русский) |
| `ZENODO_NIGHT_REPORT_RU.md` | 437 | Ночной отчёт (русский) |

**Всего:** ~3,565 LOC научной документации

### Шаблоны

| Документ | Назначение |
|----------|------------|
| `ZENODO_SCIENTIFIC_TEMPLATE.md` | Шаблон описания |
| `ZENODO_BEST_PRACTICES.md` | Лучшие практики |
| `SCIENTIFIC_PAPER_TEMPLATE.md` | Шаблон статьи |

---

## API и скрипты

### Zenodo API

**Базовый URL:**
```
https://zenodo.org/api
```

**Эндпоинты:**
- `POST /deposit/depositions` — создать депозицию
- `PUT /deposit/depositions/{id}` — обновить метаданные
- `POST /deposit/depositions/{id}/files` — загрузить файл
- `POST /deposit/depositions/{id}/actions/publish` — опубликовать

### Скрипты

| Скрипт | Описание |
|--------|----------|
| `ZENODO_ADVANCED_PATTERNS_2026.md` | Python upload скрипт |
| `.zenodo.json` | Метаданные шаблон |

---

## Формулы цитирования

### BibTeX

```bibtex
@software{vasilev_2026_trinity,
  title        = {Trinity S³AI Framework: Ternary Computing for Edge AI},
  author       = {Vasilev, Dmitrii},
  year         = {2026},
  version      = {4.0},
  doi          = {10.5281/zenodo.19224363},
  url          = {https://github.com/gHashTag/trinity}
}
```

### APA

```
Vasilev, D. (2026). Trinity S³AI Framework: Ternary Computing for Edge AI
(Version 4.0) [Computer software]. Zenodo.
https://doi.org/10.5281/zenodo.19224363
```

### IEEE

```
D. Vasilev, "Trinity S³AI Framework: Ternary Computing for Edge AI,"
2026, doi: 10.5281/zenodo.19224363.
```

---

## Ключевые метрики

| Метрика | Значение |
|---------|----------|
| **Всего бандлов** | 7 |
| **Всего DOI** | 8 |
| **Всего открытий** | 69 |
| **Статей в библиографии** | 48 |
| **Документация** | ~15,000 LOC |
| **Тесты проходящие** | 2,836/2,836 |
| **Покрытие кода** | 93% |

---

## Быстрые команды

### Проверка метаданных

```bash
# Проверить .zenodo.json
python -m json.tool .zenodo.json

# Валидация CITATION.cff
cff-lint CITATION.cff
```

### Загрузка на Zenodo

```python
from requests import post

ACCESS_TOKEN = "YOUR_TOKEN"
headers = {"Authorization": f"Bearer {ACCESS_TOKEN}"}

# Создать депозицию
response = post(
    "https://zenodo.org/api/deposit/depositions",
    params={"access_token": ACCESS_TOKEN}
)
deposition_id = response.json()["id"]
print(f"Created: {deposition_id}")
```

---

## Обновления

| Версия | Дата | Изменения |
|--------|------|----------|
| 1.0 | 2026-03-26 | Первая версия |

---

**φ² + 1/φ² = 3 | TRINITY**
