# Brain Observability Export API

## Overview

The Brain Observability Export module provides external monitoring systems access to Trinity brain telemetry data. It supports multiple export formats including Prometheus, OpenTelemetry, JSON, InfluxDB, and StatsD.

## Features

- **Prometheus Format**: Text-based exposition format for Prometheus scraping
- **JSON Format**: Generic JSON for dashboards and custom integrations
- **OpenTelemetry**: Standardized telemetry format (planned)
- **InfluxDB**: Line protocol for time-series databases (planned)
- **StatsD**: DogStatsD protocol for metrics aggregation (planned)
- **Real-time Streaming**: Continuous metrics streaming (planned)
- **HTTP Endpoint**: Built-in metrics server for Prometheus scraping (planned)

## CLI Usage

### Export to stdout

```bash
# Export in Prometheus format (default)
tri brain --export prometheus

# Export in JSON format
tri brain --export json

# Export to stdout (default format)
tri brain --export
```

### Export to file

```bash
# Export Prometheus metrics to file
tri brain --export prometheus --output metrics.prom

# Export JSON metrics to file
tri brain --export json --output brain_metrics.json

# Short form
tri brain --export -o metrics.json
```

### Help

```bash
tri brain --export --help
```

## Programmatic Usage

### Basic Export

```zig
const std = @import("std");
const observability_export = @import("brain/observability_export");

pub fn main() !void {
    const gpa = std.heap.page_allocator;

    // Create exporter
    var exporter = try observability_export.ObservabilityExporter.init(gpa, "my-service");
    defer exporter.deinit();

    // Export to stdout in Prometheus format
    const stdout = std.fs.File.stdout().deprecatedWriter();
    try exporter.exportPrometheus(stdout);
}
```

### Export to File

```zig
const std = @import("std");
const observability_export = @import("brain/observability_export");

pub fn main() !void {
    const gpa = std.heap.page_allocator;

    var exporter = try observability_export.ObservabilityExporter.init(gpa, "my-service");
    defer exporter.deinit();

    // Export to file
    try exporter.exportToFile(.prometheus, "/tmp/metrics.prom");
}
```

### Using collectAndExport

```zig
const std = @import("std");
const observability_export = @import("brain/observability_export");

pub fn main() !void {
    const gpa = std.heap.page_allocator;

    var exporter = try observability_export.ObservabilityExporter.init(gpa, "my-service");
    defer exporter.deinit();

    var buffer = std.ArrayList(u8).init(gpa);
    defer buffer.deinit();

    // Collect and export in desired format
    try exporter.collectAndExport(buffer.writer(), .json);

    // Use the exported data
    std.debug.print("{s}\n", .{buffer.items});
}
```

## Export Formats

### Prometheus

The Prometheus format follows the text-based exposition format specification:

```
# HELP s3ai_brain_health_score Overall brain health (0-100)
# TYPE s3ai_brain_health_score gauge
s3ai_brain_health_score 100.0
s3ai_brain_region_health{region="basal_ganglia"} 100.0
s3ai_brain_active_claims 0
```

**Metrics exported:**
- `s3ai_brain_health_score` (gauge): Overall brain health score (0-100)
- `s3ai_brain_region_health` (gauge): Per-region health with `region` label
- `s3ai_brain_active_claims` (gauge): Number of active task claims

### JSON

The JSON format provides a structured view of brain telemetry:

```json
{
  "timestamp": 1773958351735,
  "service": "trinity-brain",
  "overall_health": 100.0,
  "regions": [
    {
      "name": "Basal Ganglia",
      "status": "healthy",
      "health_score": 100.0,
      "metrics": {"active_claims": "0"}
    },
    ...
  ]
}
```

## Integration Examples

### Prometheus Scrape Config

Add to your `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'trinity-brain'
    scrape_interval: 15s
    static_configs:
      - targets: ['localhost:9090']
    # If using HTTP server (planned feature)
    # metrics_path: '/metrics'
```

### Grafana Dashboard

Import the JSON export into Grafana:

1. Create a new JSON data source
2. Point to your exported JSON file or HTTP endpoint
3. Use JSONPath queries to extract metrics

### Python Integration

```python
import json
import subprocess

# Get brain metrics as JSON
result = subprocess.run(['tri', 'brain', '--export', 'json'],
                       capture_output=True, text=True)
metrics = json.loads(result.stdout)

print(f"Brain health: {metrics['overall_health']}")
for region in metrics['regions']:
    print(f"  {region['name']}: {region['health_score']}")
```

### Bash Integration

```bash
# Get health score
HEALTH=$(tri brain --export json | jq -r '.overall_health')
echo "Brain health: $HEALTH"

# Alert if health is low
if (( $(echo "$HEALTH < 70" | bc -l) )); then
    echo "WARNING: Brain health is low!"
fi
```

## API Reference

### `ObservabilityExporter`

Main struct for exporting brain metrics.

#### Functions

- `init(allocator, service_name) !ObservabilityExporter`: Initialize exporter
- `deinit(self: *Self) void`: Clean up resources
- `collectAndExport(self, writer, format) !void`: Collect and export metrics
- `exportPrometheus(self, writer) !void`: Export in Prometheus format
- `exportJson(self, writer) !void`: Export in JSON format
- `exportToFile(self, format, path) !void`: Export to file

### `ExportFormat`

Enum of supported export formats:

- `prometheus`: Prometheus text-based exposition
- `opentelemetry`: OpenTelemetry JSON (planned)
- `json`: Generic JSON
- `influxdb`: InfluxDB line protocol (planned)
- `statsd`: StatsD protocol (planned)

### `MetricsStreamer` (Planned)

Real-time metrics streaming support.

### `MetricsServer` (Planned)

HTTP server for Prometheus scraping.

## Future Enhancements

1. **OpenTelemetry Support**: Full OTLP protocol support
2. **InfluxDB Line Protocol**: Direct InfluxDB write support
3. **StatsD Protocol**: Real-time metrics push
4. **HTTP Server**: Built-in `/metrics` endpoint
5. **Real-time Streaming**: WebSocket-based live metrics
6. **Custom Metrics**: User-defined metric registration
7. **Histogram Support**: Distribution metrics
8. **Metric Labels**: Additional label support

## Sacred Formula Integration

The export system respects the Trinity sacred formula: `phi^2 + 1/phi^2 = 3`

Brain health scores are normalized to 0-100 scale, where:
- 100 = Optimal (phi state)
- 70-99 = Healthy
- 50-69 = Recovering
- 0-49 = Critical

## Version

v5.1 - Initial implementation with Prometheus and JSON support.

## License

MIT License - Part of the Trinity Project
