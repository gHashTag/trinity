# Fly.io FPGA Synthesis — Cloud Pipeline

Синтез FPGA в облаке без нагрузки локальной машины.

## Архитектура

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────┐
│  Локальная Mac  │────▶│  fly.io (облако) │────▶│   FPGA      │
│                 │◀────│                  │     │  (JTAG)     │
│  - JTAG only    │     │  - Yosys         │     │             │
│  - UART client  │     │  - nextpnr       │     │             │
│  - Lightweight  │     │  - fasm2frames   │     │             │
└─────────────────┘     └──────────────────┘     └─────────────┘
```

## Быстрый старт

### 1. Деплой на fly.io (один раз)

```bash
cd fpga/openxc7-synth
fly launch --no-deploy
fly deploy
```

### 2. Синтез в облаке

```bash
# Простой способ
fpga/tools/cloud-synth.sh uart_top.v uart_top

# Получишь uart_top.bit готовый для прошивки
```

### 3. Прошивка FPGA

```bash
# Сначала firmware для JTAG (если нужно)
sudo fpga/tools/fxload -v -t fx2 -d 03fd:0013 -i fpga/tools/xusb_xp2.hex
# Переподключить кабель

# Прошить
sudo fpga/tools/jtag_program uart_top.bit
```

## Файлы

| Файл | Описание |
|------|----------|
| `fly.toml` | Конфиг fly.io (4 CPU, 8GB RAM) |
| `Dockerfile.fly` | Docker образ с Python API |
| `synth_cloud.py` | HTTP API для синтеза |
| `../tools/cloud-synth.sh` | Клиент для локальной машины |
| `../tools/uart-bitstream.py` | UART доставка (опционально) |

## API

### POST /synthesize

```json
{
    "verilog": "module top...",
    "top": "uart_top",
    "xdc": "set_property..." // опционально
}
```

Response:
```json
{
    "bitstream": "<base64>",
    "status": "success",
    "size_bytes": 3774864
}
```

### GET /

Health check — возвращает статус сервиса.

## Стоимость

- **CPU**: 4 vCPU
- **RAM**: 8 GB
- **Disk**: 40 GB
- **Остановка**: auto_stop_machines = true (не платишь когда не используешь)

Примерная цена: ~$0.50/час активного использования.

## Troubleshooting

### "Cannot get app URL"
```bash
fly status -a trinity-fpga-synth
```

### "Synthesis timeout"
Увеличь timeout в `synth_cloud.py` (default: 300 сек)

### "chipdb not found"
Скопируй `chipdb/xc7a100tfgg676.bin` в директорию перед деплоем.
