# Деплой Trinity на Fly.io

## φ² + 1/φ² = 3 = TRINITY

Инструкция по деплою Trinity LLM inference на Fly.io с максимальными ресурсами (16 CPU cores).

---

## Предварительные требования

1. Аккаунт на [Fly.io](https://fly.io)
2. Установленный `flyctl` CLI

---

## Шаг 1: Установка flyctl

```bash
# Linux/macOS
curl -L https://fly.io/install.sh | sh

# Добавить в PATH
export FLYCTL_INSTALL="$HOME/.fly"
export PATH="$FLYCTL_INSTALL/bin:$PATH"

# Проверить установку
flyctl version
```

---

## Шаг 2: Авторизация

```bash
flyctl auth login
```

Откроется браузер для входа в аккаунт Fly.io.

---

## Шаг 3: Клонирование репозитория

```bash
git clone https://github.com/gHashTag/trinity.git
cd trinity
```

---

## Шаг 4: Создание приложения

```bash
flyctl apps create trinity-inference
```

---

## Шаг 5: Выбор размера машины

Доступные размеры в `fly.toml`:

| Size | CPU | RAM | Цена/час |
|------|-----|-----|----------|
| shared-cpu-1x | 1 shared | 256MB-2GB | ~$0.0035 |
| shared-cpu-2x | 2 shared | 512MB-4GB | ~$0.007 |
| shared-cpu-4x | 4 shared | 1GB-8GB | ~$0.014 |
| shared-cpu-8x | 8 shared | 2GB-16GB | ~$0.028 |
| performance-1x | 1 dedicated | 2GB-8GB | ~$0.057 |
| performance-2x | 2 dedicated | 4GB-16GB | ~$0.114 |
| performance-4x | 4 dedicated | 8GB-32GB | ~$0.228 |
| performance-8x | 8 dedicated | 16GB-64GB | ~$0.456 |
| **performance-16x** | **16 dedicated** | **32GB-128GB** | ~$0.912 |

Текущая конфигурация в `fly.toml`:

```toml
[[vm]]
  size = "performance-16x"
  memory = "32gb"
  cpus = 16
```

Для изменения размера отредактируйте `fly.toml`.

---

## Шаг 6: Деплой

```bash
flyctl deploy
```

Это:
1. Соберёт Docker образ
2. Загрузит на Fly.io
3. Запустит машину с 16 CPU cores

---

## Шаг 7: Проверка статуса

```bash
# Статус приложения
flyctl status

# Логи
flyctl logs

# SSH в машину
flyctl ssh console
```

---

## Шаг 8: Запуск benchmark

После деплоя, подключитесь к машине и запустите:

```bash
flyctl ssh console

# Внутри машины
cd /app
./tri_inference /app/models/smollm2-360m.tri
```

---

## Ожидаемая производительность

| Машина | Cores | Скорость | Speedup |
|--------|-------|----------|---------|
| Gitpod (текущая) | 2 | ~8 tok/s | 1x |
| performance-4x | 4 | ~15 tok/s | 2x |
| performance-8x | 8 | ~28 tok/s | 3.5x |
| **performance-16x** | **16** | **~50 tok/s** | **6x** |

---

## Остановка машины (экономия денег)

```bash
# Остановить машину
flyctl machine stop

# Удалить приложение
flyctl apps destroy trinity-inference
```

---

## Альтернативный запуск (одноразовая машина)

Для быстрого теста без постоянного деплоя:

```bash
flyctl machine run \
  --app trinity-inference \
  --vm-size performance-16x \
  --vm-memory 32768 \
  --entrypoint "/app/tri_inference /app/models/smollm2-360m.tri" \
  registry.fly.io/trinity-inference:latest
```

---

## Troubleshooting

### Ошибка "No access token"
```bash
flyctl auth login
```

### Ошибка "App not found"
```bash
flyctl apps create trinity-inference
```

### Ошибка "Out of memory"
Уменьшите размер модели или увеличьте RAM в `fly.toml`.

### Медленная сборка
Используйте remote builder:
```bash
flyctl deploy --remote-only
```

---

## Файлы конфигурации

- `fly.toml` - конфигурация Fly.io
- `Dockerfile.flyio` - Docker образ для деплоя
- `benchmark_flyio.sh` - скрипт оценки производительности

---

**KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED | φ² + 1/φ² = 3**
