// @origin(spec:farm_stats.tri) @regen(manual-impl)

// ═══════════════════════════════════════════════════════════════════════
// FARM STATS — Терминные воркеры vs Симуляция
// ═════════════════════════════════════════════════════════════════════════════
//
// Сопоставляет статистику реальных тернарных воркеров с результатами симуляции.
// Используется для калибровки meta-optimizer.
//
// φ² + 1/φ² = 3 = TRINITY
// ═════════════════════════════════════════════════════════════════════════════

const std = @import("std");

const Allocator = std.mem.Allocator;

// ANSI цвета
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const DIM = "\x1b[2m";

// ═════════════════════════════════════════════════════════════════════════════
// ДАННЫЕ СИМУЛЯЦИИ
// ═════════════════════════════════════════════════════════════════════════════════

pub const SimulationEntry = struct {
    step: u64,
    scenario_id: []const u8,
    ppl: f64,
    diversity: f64,
    alive: f64,
    culled: f64,
    byzantine: f64,
    converged: bool,
    energy_cost: f64,
    fpga_lut: f64,
    fpga_bram: f64,
    fpga_cost_norm: f64,
    seed_rate: f64,
    kill_rate: f64,
    ntp_weight: f64,
    jepa_weight: f64,
    nca_weight: f64,
    quantum_superposition: f64,
    quantum_coherence: f64,
    quantum_interference: f64,
    quantum_collapse_prob: f64,
};

pub const ScenarioSummary = struct {
    id: []const u8,
    final_ppl: f64,
    avg_diversity: f64,
    avg_energy: f64,
    converged_count: u64,
};

/// Загрузить данные симуляции из simulation_results.csv
/// Формат CSV: step,scenario_id,ppl,diversity,alive,culled,byzantine,...
pub fn loadSimulationData(allocator: Allocator) !std.ArrayList(SimulationEntry) {
    const file = std.fs.cwd().openFile("simulation_results.csv", .{}) catch |err| {
        std.debug.print("{s}❌ Ошибка открытия simulation_results.csv: {s}{s}\n", .{ RED, @errorName(err), RESET });
        return err;
    };
    defer file.close();

    const contents = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(contents);

    var entries = std.ArrayList(SimulationEntry).init(allocator);

    // Пропустить заголовок
    var lines = std.mem.splitSequence(u8, contents, '\n');
    var line_iter = lines.iterator();
    _ = line_iter.next(); // Пропустить header

    while (line_iter.next()) |line| {
        if (line.len == 0) continue; // Пропустить пустые строки

        var fields = std.mem.splitSequence(u8, line, ',');
        const fields_iter = fields.iterator();

        // Парсинг полей
        const step_str = if (fields_iter.next()) |f| f else break;
        const scenario_str = if (fields_iter.next()) |f| f else break;
        const ppl_str = if (fields_iter.next()) |f| f else break;
        const diversity_str = if (fields_iter.next()) |f| f else break;
        const alive_str = if (fields_iter.next()) |f| f else break;
        const culled_str = if (fields_iter.next()) |f| f else break;
        const byzantine_str = if (fields_iter.next()) |f| f else break;
        const converged_str = if (fields_iter.next()) |f| f else break;
        const energy_str = if (fields_iter.next()) |f| f else break;
        const fpga_lut_str = if (fields_iter.next()) |f| f else break;
        const fpga_bram_str = if (fields_iter.next()) |f| f else break;
        const fpga_cost_str = if (fields_iter.next()) |f| f else break;
        const seed_rate_str = if (fields_iter.next()) |f| f else break;
        const kill_rate_str = if (fields_iter.next()) |f| f else break;
        const ntp_weight_str = if (fields_iter.next()) |f| f else break;
        const jepa_weight_str = if (fields_iter.next()) |f| f else break;
        const nca_weight_str = if (fields_iter.next()) |f| f else break;
        const qs_str = if (fields_iter.next()) |f| f else break;
        const qc_str = if (fields_iter.next()) |f| f else break;
        const qint_str = if (fields_iter.next()) |f| f else break;
        const qcp_str = if (fields_iter.next()) |f| f else break;

        const step = std.fmt.parseInt(u64, step_str, 10) catch 0;
        const ppl = std.fmt.parseFloat(f64, ppl_str) catch 0.0;
        const diversity = std.fmt.parseFloat(f64, diversity_str) catch 0.0;
        const alive = std.fmt.parseFloat(f64, alive_str) catch 0.0;
        const culled = std.fmt.parseFloat(f64, culled_str) catch 0.0;
        const byzantine = std.fmt.parseFloat(f64, byzantine_str) catch 0.0;
        const converged = std.mem.eql(u8, converged_str, "1");
        const energy_cost = std.fmt.parseFloat(f64, energy_str) catch 0.0;
        const fpga_lut = std.fmt.parseFloat(f64, fpga_lut_str) catch 0.0;
        const fpga_bram = std.fmt.parseFloat(f64, fpga_bram_str) catch 0.0;
        const fpga_cost_norm = std.fmt.parseFloat(f64, fpga_cost_str) catch 0.0;
        const seed_rate = std.fmt.parseFloat(f64, seed_rate_str) catch 0.0;
        const kill_rate = std.fmt.parseFloat(f64, kill_rate_str) catch 0.0;
        const ntp_weight = std.fmt.parseFloat(f64, ntp_weight_str) catch 0.0;
        const jepa_weight = std.fmt.parseFloat(f64, jepa_weight_str) catch 0.0;
        const nca_weight = std.fmt.parseFloat(f64, nca_weight_str) catch 0.0;
        const quantum_superposition = std.fmt.parseFloat(f64, qs_str) catch 0.0;
        const quantum_coherence = std.fmt.parseFloat(f64, qc_str) catch 0.0;
        const quantum_interference = std.fmt.parseFloat(f64, qint_str) catch 0.0;
        const quantum_collapse_prob = std.fmt.parseFloat(f64, qcp_str) catch 0.0;

        // ID сценария - нужно скопировать
        const scenario_id = try allocator.dupe(u8, scenario_str);

        try entries.append(.{
            .step = step,
            .scenario_id = scenario_id,
            .ppl = ppl,
            .diversity = diversity,
            .alive = alive,
            .culled = culled,
            .byzantine = byzantine,
            .converged = converged,
            .energy_cost = energy_cost,
            .fpga_lut = fpga_lut,
            .fpga_bram = fpga_bram,
            .fpga_cost_norm = fpga_cost_norm,
            .seed_rate = seed_rate,
            .kill_rate = kill_rate,
            .ntp_weight = ntp_weight,
            .jepa_weight = jepa_weight,
            .nca_weight = nca_weight,
            .quantum_superposition = quantum_superposition,
            .quantum_coherence = quantum_coherence,
            .quantum_interference = quantum_interference,
            .quantum_collapse_prob = quantum_collapse_prob,
        });
    }

    return entries;
}

/// Сгруппировать записи по сценариям и найти финальный PPL для каждого
pub fn aggregateByScenario(allocator: Allocator, entries: std.ArrayList(SimulationEntry)) !std.ArrayList(ScenarioSummary) {
    var scenarios = std.StringHashMap(std.ArrayList(SimulationEntry)).init(allocator);
    defer {
        var iter = scenarios.iterator();
        while (iter.next()) |entry| {
            for (entry.value_ptr.items) |item| {
                allocator.free(item.scenario_id);
            }
            allocator.destroy(entry.value_ptr);
        }
        scenarios.deinit();
    }

    // Группировка по scenario_id
    for (entries.items) |entry| {
        const result = try scenarios.getOrPut(entry.scenario_id, std.ArrayList(SimulationEntry).init(allocator));
        try result.append(entry);
    }

    var summaries = std.ArrayList(ScenarioSummary).init(allocator);
    var iter = scenarios.iterator();
    while (iter.next()) |entry| {
        const scenario_entries = entry.value_ptr;
        defer allocator.destroy(scenario_entries);

        if (scenario_entries.items.len == 0) continue;

        // Найти запись с минимальным PPL (финальный результат)
        var best_idx: usize = 0;
        var best_ppl: f64 = scenario_entries.items[0].ppl;
        var total_diversity: f64 = 0.0;
        var total_energy: f64 = 0.0;
        var converged_count: u64 = 0;

        for (scenario_entries.items, 0..) |item, i| {
            total_diversity += item.diversity;
            total_energy += item.energy_cost;
            if (item.converged) converged_count += 1;
            if (item.ppl < best_ppl) {
                best_ppl = item.ppl;
                best_idx = i;
            }
        }

        const avg_diversity = if (scenario_entries.items.len > 0)
            total_diversity / @as(f64, @floatFromInt(scenario_entries.items.len))
        else
            0.0;

        const avg_energy = if (scenario_entries.items.len > 0)
            total_energy / @as(f64, @floatFromInt(scenario_entries.items.len))
        else
            0.0;

        const scenario_id = try allocator.dupe(u8, scenario_entries.items[best_idx].scenario_id);

        try summaries.append(.{
            .id = scenario_id,
            .final_ppl = best_ppl,
            .avg_diversity = avg_diversity,
            .avg_energy = avg_energy,
            .converged_count = converged_count,
        });
    }

    return summaries;
}

// ═════════════════════════════════════════════════════════════════════════════
// ДАННЫЕ ФЕРМЫ
// ═══════════════════════════════════════════════════════════════════════════════════

pub const FarmWorker = struct {
    name: []const u8,
    ppl: f64,
    loss: f64,
    step: u64,
    lr: []const u8,
    batch: []const u8,
    optimizer: []const u8,
    seed: u32,
    grad_clip: f64,
    warmup: u64,
    context: u64,
};

/// Загрузить снапшот фермы из JSON файла
pub fn loadFarmSnapshot(allocator: Allocator, path: []const u8) !std.ArrayList(FarmWorker) {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        std.debug.print("{s}❌ Ошибка открытия {s}: {s}{s}\n", .{ RED, path, @errorName(err), RESET });
        return err;
    };
    defer file.close();

    const contents = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(contents);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, contents, .{}) catch |err| {
        std.debug.print("{s}❌ Ошибка парсинга JSON: {s}{s}\n", .{ RED, @errorName(err), RESET });
        return error.ParseFailed;
    };
    defer parsed.deinit();

    if (parsed.value != .array) {
        std.debug.print("{s}❌ Ожидается массив JSON{ s}\n", .{ RESET });
        return error.InvalidFormat;
    }

    var workers = std.ArrayList(FarmWorker).init(allocator);

    for (parsed.value.array.items) |item| {
        if (item != .object) continue;

        const name = if (item.object.get("name")) |v| blk: {
            if (v != .string) break :blk "";
            break :blk v.string;
        } else "";

        const ppl_val = if (item.object.get("ppl")) |v| blk: {
            if (v != .number_float and v != .number_int) break :blk 0.0;
            break :blk @as(f64, v.float);
        } else 0.0;

        const loss_val = if (item.object.get("loss")) |v| blk: {
            if (v != .number_float and v != .number_int) break :blk 0.0;
            break :blk @as(f64, v.float);
        } else 0.0;

        const step_val = if (item.object.get("step")) |v| blk: {
            if (v != .number_int and v != .number_float) break :blk 0;
            break :blk @as(u64, v.int);
        } else 0;

        const lr = if (item.object.get("lr")) |v| blk: {
            if (v != .string) break :blk "";
            break :blk v.string;
        } else "";

        const batch = if (item.object.get("batch")) |v| blk: {
            if (v != .string) break :blk "";
            break :blk v.string;
        } else "";

        const optimizer = if (item.object.get("optimizer")) |v| blk: {
            if (v != .string) break :blk "";
            break :blk v.string;
        } else "";

        const seed_val = if (item.object.get("seed")) |v| blk: {
            if (v != .number_int and v != .number_float) break :blk 0;
            break :blk @as(u32, v.int);
        } else 0;

        const grad_clip_val = if (item.object.get("grad_clip")) |v| blk: {
            if (v != .number_float and v != .number_int) break :blk 1.0;
            break :blk @as(f64, v.float);
        } else 1.0;

        const warmup_val = if (item.object.get("warmup")) |v| blk: {
            if (v != .number_int and v != .number_float) break :blk 0;
            break :blk @as(u64, v.int);
        } else 0;

        const context_val = if (item.object.get("context")) |v| blk: {
            if (v != .number_int and v != .number_float) break :blk 27;
            break :blk @as(u64, v.int);
        } else 27;

        const name_copy = try allocator.dupe(u8, name);
        const lr_copy = try allocator.dupe(u8, lr);
        const batch_copy = try allocator.dupe(u8, batch);
        const opt_copy = try allocator.dupe(u8, optimizer);

        try workers.append(.{
            .name = name_copy,
            .ppl = ppl_val,
            .loss = loss_val,
            .step = step_val,
            .lr = lr_copy,
            .batch = batch_copy,
            .optimizer = opt_copy,
            .seed = seed_val,
            .grad_clip = grad_clip_val,
            .warmup = warmup_val,
            .context = context_val,
        });
    }

    return workers;
}

/// Вычислить средние метрики по воркерам фермы
pub fn computeFarmStats(allocator: Allocator, workers: std.ArrayList(FarmWorker)) !struct {
    total_workers: usize,
    avg_ppl: f64,
    min_ppl: f64,
    max_ppl: f64,
    ppl_std: f64,
    avg_step: f64,
    diversity_workers: usize, // Воркеры с diversity > 0
} {
    if (workers.items.len == 0) {
        return .{
            .total_workers = 0,
            .avg_ppl = 0.0,
            .min_ppl = 0.0,
            .max_ppl = 0.0,
            .ppl_std = 0.0,
            .avg_step = 0.0,
            .diversity_workers = 0,
        };
    }

    var sum_ppl: f64 = 0.0;
    var sum_ppl_sq: f64 = 0.0;
    var sum_step: f64 = 0.0;
    var min_ppl_val: f64 = workers.items[0].ppl;
    var max_ppl_val: f64 = workers.items[0].ppl;
    var diversity_count: usize = 0;

    for (workers.items) |worker| {
        sum_ppl += worker.ppl;
        sum_ppl_sq += worker.ppl * worker.ppl;
        sum_step += @as(f64, @floatFromInt(worker.step));

        if (worker.ppl < min_ppl_val) min_ppl_val = worker.ppl;
        if (worker.ppl > max_ppl_val) max_ppl_val = worker.ppl;

        // Если воркер использует нестандартный LR/BATCH, считаем его как diverse
        // Все w7 воркеры используют LAMB 1e-3, batch=66
        const is_diverse = !std.mem.eql(u8, worker.lr, "1e-3") or
                          !std.mem.eql(u8, worker.batch, "66") or
                          !std.mem.eql(u8, worker.optimizer, "lamb");
        if (is_diverse) diversity_count += 1;
    }

    const n = @as(f64, @floatFromInt(workers.items.len));
    const avg_ppl_val = sum_ppl / n;
    const variance = (sum_ppl_sq / n) - (avg_ppl_val * avg_ppl_val);
    const ppl_std_val = @sqrt(variance);
    const avg_step_val = sum_step / n;

    return .{
        .total_workers = workers.items.len,
        .avg_ppl = avg_ppl_val,
        .min_ppl = min_ppl_val,
        .max_ppl = max_ppl_val,
        .ppl_std = ppl_std_val,
        .avg_step = avg_step_val,
        .diversity_workers = diversity_count,
    };
}

// ═════════════════════════════════════════════════════════════════════════════
// СОПОСТАВЛЕНИЕ И ОТЧЁТЫ
// ═══════════════════════════════════════════════════════════════════════

pub const ComparisonMetric = struct {
    name: []const u8,
    sim_value: f64,
    real_value: f64,
    delta: f64,
    delta_percent: f64,
    conclusion: []const u8,
};

/// Сгенерировать отчёт сравнения симуляции и реальности
pub fn generateComparisonReport(
    allocator: Allocator,
    sim_scenarios: std.ArrayList(ScenarioSummary),
    farm_stats: struct {
        total_workers: usize,
        avg_ppl: f64,
        min_ppl: f64,
        max_ppl: f64,
        ppl_std: f64,
        avg_step: f64,
        diversity_workers: usize,
    },
    scenario_filter: ?[]const u8,
) !void {
    std.debug.print("\n{s}═════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}                    {s}СТАТИСТИКА: СИМУЛЯЦИЯ VS РЕАЛЬНОСТЬ{s}                         {s}\n", .{ CYAN, BOLD, RESET, CYAN });
    std.debug.print("{s}═════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });

    // Найти базовые сценарии для сравнения
    var s1_summary: ?ScenarioSummary = null;
    var s3_summary: ?ScenarioSummary = null;

    for (sim_scenarios.items) |summary| {
        if (std.mem.eql(u8, summary.id, "S1")) s1_summary = summary;
        if (std.mem.eql(u8, summary.id, "S3")) s3_summary = summary;
    }

    // Показать статистику фермы
    std.debug.print("\n{s}🌾 ФЕРМА (реальные воркеры){s}\n", .{ BOLD, RESET });
    std.debug.print("{s}  Воркеров: {d} | Средний PPL: {d:.2} | Диапазон: {d:.2} - {d:.2}{s}\n", .{
        farm_stats.total_workers, farm_stats.avg_ppl, farm_stats.min_ppl, farm_stats.max_ppl, RESET });
    std.debug.print("  Diverse воркеров: {d}/{d} ({d:.1}%){s}\n\n", .{
        farm_stats.diversity_workers, farm_stats.total_workers,
        @as(f64, @floatFromInt(farm_stats.diversity_workers)) / @as(f64, @floatFromInt(farm_stats.total_workers)) * 100.0,
        RESET });
    std.debug.print("  Средний шаг: {d:.0}K{ s}\n\n", .{ farm_stats.avg_step / 1000.0, RESET });

    // Показать статистику симуляции (для всех сценариев)
    std.debug.print("{s}📊 СИМУЛЯЦИЯ (simulation_results.csv){s}\n", .{ BOLD, RESET });
    std.debug.print("  Сценариев: {d}{s}\n", .{ sim_scenarios.items.len, RESET });

    if (s1_summary) |s1| {
        const comparison_str = if (s1.final_ppl < farm_stats.avg_ppl) "лучше" else "хуже";
        std.debug.print("  {s}S1 (NTP): {s}{s}", .{
            if (s1.final_ppl < farm_stats.avg_ppl) GREEN else RED,
            std.fmt.allocPrint(allocator, "{d:.2}", .{s1.final_ppl}),
        });
    }

    if (s3_summary) |s3| {

    if (s3_summary) |s3| {
            std.debug.print("  {s}S3 (Multi-obj): {s}{s}", .{
                if (s3.final_ppl < farm_stats.avg_ppl) GREEN else RED,
                std.fmt.allocPrint(allocator, "{d:.2}", .{s3.final_ppl}),
            });
        }
    }

    // Таблица сравнения (если указан фильтр сценария)
    if (scenario_filter) |filter| {
        std.debug.print("\n{s}📈 Детали по сценарию {s}:{s}\n", .{ BOLD, filter, RESET });
        std.debug.print("{s}─────────────────────────────────────────────────────────{s}\n", .{ DIM, RESET });

        for (sim_scenarios.items) |summary| {
            if (!std.mem.eql(u8, summary.id, filter)) continue;

            const sim_ppl = summary.final_ppl;
            const sim_div = summary.avg_diversity;
            const sim_conv_pct = if (summary.converged_count > 0)
                @as(f64, @floatFromInt(summary.converged_count)) / 100.0
            else
                0.0;

            std.debug.print("  {s}", .{ summary.id, RESET });

            // PPL сравнение
            const ppl_delta = sim_ppl - farm_stats.avg_ppl;
            const ppl_delta_pct = if (farm_stats.avg_ppl > 0)
                (ppl_delta / farm_stats.avg_ppl) * 100.0
            else
                0.0;

            const ppl_color = if (ppl_delta < 0) GREEN else RED;
            const ppl_conclusion = if (ppl_delta < -5) "Сим занижил сильно" else if (ppl_delta < 0) "Сим занижил" else if (ppl_delta > 5) "Сим завысил" else if (ppl_delta > 0) "Сим завысил сильно" else "Точно";

            std.debug.print("    PPL: {s} {d:.2} vs {d:.2} = {s}{d:.2}% ({s}){s}", .{
                ppl_color,
                std.fmt.allocPrint(allocator, "  {d:.2}", .{sim_ppl, farm_stats.avg_ppl, ppl_delta_pct, ppl_conclusion }),
            });

            // Diversity
            const div_delta = sim_div - 0.0; // Сравниваем с zero diversity в w7
            const div_delta_pct = if (sim_div > 0) div_pct else 0.0;
            const div_conclusion = if (sim_div > 0.1) "Сим предсказал" else if (sim_div > 0) "Сим точно" else if (sim_div == 0) "Не применимо" else "Сим занижил";

            const div_color = if (div_delta > 0) GREEN else YELLOW;
            std.debug.print("    Diversity: {s} {d:.3} vs 0.0 = {s} ({s}){s}", .{
                div_color,
                std.fmt.allocPrint(allocator, "  {d:.3}", .{sim_div, div_delta_pct, div_conclusion }),
            });

            // Convergence
            const conv_delta = sim_conv_pct * 100.0 - 0.0; // w7 converged ~0%
            const conv_conclusion = if (conv_delta < -20) "Сим завысил" else if (conv_delta > 20) "Сим занижил" else "Точно";

            const conv_color = if (conv_delta > 0) GREEN else RED;
            std.debug.print("    Convergence: {s} {d:.1}% vs 0% = {s} ({s}){s}", .{
                conv_color,
                sim_conv_pct,
                std.fmt.allocPrint(allocator, "  {d:.1}%", .{conv_delta, conv_conclusion }),
            });

            std.debug.print("    Energy: {d:.1} (avg по сценарию){s}", .{ YELLOW, summary.avg_energy / 1000.0, RESET });
        }
        std.debug.print("{s}─────────────────────────────────────────────────────────{s}\n", .{ DIM, RESET });
    }

    // Ключевые инсайты
    std.debug.print("\n{s}💡 Ключевые инсайты{ s}\n", .{ BOLD, RESET });
    if (s1_summary) |s1| {
        if (s3_summary) |s3| {
            const diff = s3.final_ppl - s1.final_ppl;
            const diff_pct = (diff / s1.final_ppl) * 100.0;

            std.debug.print("  Multi-obj vs NTP: {s} {d:.2}% ({d} в сим, {s} в реальн){s}", .{
                if (diff_pct > 0) GREEN else YELLOW,
                std.fmt.allocPrint(allocator, "{d:.1}", .{ diff_pct }),
                std.debug.print(" ({d:.2}pp vs {d:.2}pp)", .{ s3.final_ppl, s1.final_ppl }),
            });
        }
    }

    if (s3_summary) |s3| {
        // S3 использует diversity>0
        const diversity_benefit_pct = ((s3.avg_diversity - 0.0) / s3.final_ppl) * 100.0;

        const diversity_color = if (diversity_benefit_pct > 5) GREEN else if (diversity_benefit_pct > 0) YELLOW else DIM;
        std.debug.print("  Diversity ({s}): {s}{d:.1}% улучшение PPL{ s}", .{
            diversity_color,
            s3.id,
            std.fmt.allocPrint(allocator, " {d:.1}", .{ diversity_benefit_pct }),
        });
    }

    std.debug.print("\n{s}═══════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
}

/// Основная функция генерации отчёта
pub fn generateReport(allocator: Allocator) !void {
    // Загрузить данные симуляции
    const sim_entries = try loadSimulationData(allocator);
    defer {
        for (sim_entries.items) |entry| {
            allocator.free(entry.scenario_id);
        }
        sim_entries.deinit(allocator);
    }

    const sim_scenarios = try aggregateByScenario(allocator, sim_entries);
    defer {
        for (sim_scenarios.items) |summary| {
            allocator.free(summary.id);
        }
        sim_scenarios.deinit(allocator);
    }

    // Загрузить снапшот фермы
    const farm_workers = try loadFarmSnapshot(allocator, ".trinity/farm/w7v2_snapshot.json");
    defer {
        for (farm_workers.items) |worker| {
            allocator.free(worker.name);
            allocator.free(worker.lr);
            allocator.free(worker.batch);
            allocator.free(worker.optimizer);
        }
        farm_workers.deinit(allocator);
    }

    const farm_stats = try computeFarmStats(allocator, farm_workers);

    // Генерация отчёта
    try generateComparisonReport(allocator, sim_scenarios, farm_stats, null);
}

/// Показать только статистику фермы (без сравнения)
pub fn showFarmStatsOnly(allocator: Allocator) !void {
    std.debug.print("\n{s}═════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}                    {s}СТАТИСТИКА ФЕРМЫ{ s}                              {s}\n", .{ CYAN, BOLD, RESET, CYAN });
    std.debug.print("{s}═══════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });

    const farm_workers = try loadFarmSnapshot(allocator, ".trinity/farm/w7v2_snapshot.json");
    defer {
        for (farm_workers.items) |worker| {
            allocator.free(worker.name);
            allocator.free(worker.lr);
            allocator.free(worker.batch);
            allocator.free(worker.optimizer);
        }
        farm_workers.deinit(allocator);
    }

    if (farm_workers.items.len == 0) {
        std.debug.print("{s}⚠️  Нет данных о воркерах{ s}\n", .{ YELLOW, RESET });
        return;
    }

    std.debug.print("  Воркеры: {d}{s}\n", .{ farm_workers.items.len, RESET });
    std.debug.print("{s}  ───────────────────────────────────────────────────────{s}\n", .{ DIM, RESET });
    std.debug.print("  {s}                PPL  Loss   Step  LR     Batch Opt   Seed  Ctx  GC   Warmup{ s}\n", .{ RESET });

    for (farm_workers.items) |worker| {
        const ppl_color = if (worker.ppl < 10.0) GREEN else if (worker.ppl < 20.0) YELLOW else RED;
        std.debug.print("  {s}{s} {s} {d:.2} {d:.2} {d:6}  {s} {s} {s} {s} {d} {s} {d} {d} {d} {s}{s}\n", .{
            worker.name,
            ppl_color,
            std.fmt.allocPrint(allocator, "{d:.2}", .{worker.ppl }),
            std.fmt.allocPrint(allocator, "{d:.2}", .{worker.loss }),
            std.fmt.allocPrint(allocator, "{d}", .{worker.step }),
            worker.lr,
            worker.batch,
            worker.optimizer,
            worker.seed,
            worker.context,
            worker.grad_clip,
            worker.warmup,
            RESET,
        });
    }

    const farm_stats_computed = try computeFarmStats(allocator, farm_workers);

    std.debug.print("  ───────────────────────────────────────────────────────{s}\n", .{ DIM, RESET });
    std.debug.print("  Средний PPL: {d:.2} (σ={d:.2}){ s}\n", .{
        farm_stats_computed.avg_ppl,
        farm_stats_computed.ppl_std,
        RESET,
    });
    std.debug.print("  Средний шаг: {d:.0}K{ s}\n", .{ farm_stats_computed.avg_step / 1000.0, RESET });
    std.debug.print("\n{s}═════════════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
}

/// Экспорт статистики в CSV для визуализации
pub fn exportToCSV(allocator: Allocator) !void {
    const farm_workers = try loadFarmSnapshot(allocator, ".trinity/farm/w7v2_snapshot.json");
    defer {
        for (farm_workers.items) |worker| {
            allocator.free(worker.name);
            allocator.free(worker.lr);
            allocator.free(worker.batch);
            allocator.free(worker.optimizer);
        }
        farm_workers.deinit(allocator);
    }

    const csv_file = try std.fs.cwd().createFile("farm_stats_export.csv", .{});
    defer csv_file.close();

    const header = "name,ppl,loss,step,lr,batch,optimizer,seed,grad_clip,warmup,context\n";
    try csv_file.writeAll(header);

    for (farm_workers.items) |worker| {
        const line = std.fmt.allocPrint(allocator, "{s},{d:.2},{d:.2},{d},{s},{s},{s},{d},{d:.2},{d},{d}\n", .{
            worker.name,
            worker.ppl,
            worker.loss,
            worker.step,
            worker.lr,
            worker.batch,
            worker.optimizer,
            worker.seed,
            worker.grad_clip,
            worker.warmup,
            worker.context,
        });
        try csv_file.writeAll(line);
    }

    std.debug.print("{s}✅ Экспортировано в farm_stats_export.csv ({d} воркеров){s}\n", .{ GREEN, farm_workers.items.len, RESET });
}

// ═════════════════════════════════════════════════════════════════════════════
// CLI ВХОДНАЯ ТОЧКА
// ═════════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var args = std.process.argsAlloc(allocator, std.process.ArgIterator) catch {
        std.debug.print("Ошибка получения аргументов\n", .{});
        return;
    };
    defer allocator.free(args);

    // Пропустить имя бинарника
    _ = args.skip();
    const binary_name = args.next() orelse "farm-stats";

    var show_farm_only = false;
    var export_csv = false;
    var scenario_filter: ?[]const u8 = null;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--farm") or std.mem.eql(u8, arg, "-f")) {
            show_farm_only = true;
        } else if (std.mem.eql(u8, arg, "--export") or std.mem.eql(u8, arg, "-e")) {
            export_csv = true;
        } else if (std.mem.eql(u8, arg, "--scenario") or std.mem.eql(u8, arg, "-s")) {
            if (args.next()) |filter| {
                scenario_filter = filter;
            }
        } else {
            std.debug.print("Неизвестный флаг: {s}\n", .{arg});
            std.debug.print("Использование: farm-stats [--farm] [--export] [--scenario S1|S3|...]\n", .{});
            std.process.exit(1);
        }
    }

    if (export_csv) {
        try exportToCSV(allocator);
        return;
    }

    if (show_farm_only) {
        try showFarmStatsOnly(allocator);
    } else {
        try generateReport(allocator);
    }
}

test "loadSimulationData" {
    const allocator = std.testing.allocator;
    const test_csv =
        \\step,scenario_id,ppl,diversity,alive,culled,byzantine,converged,energy_cost
        \\0,S1,504.600,0.000,25,0,0,1,2500.00
        \\1,S1,49.163,0.000,25,0,0,1,5000.00
        ;

    // Создаём временный файл для теста
    const test_file = try std.fs.cwd().createFile("test_simulation.csv", .{});
    defer std.fs.cwd().deleteFile("test_simulation.csv") catch {};
    defer test_file.close();

    try test_file.writeAll(test_csv);

    const entries = try loadSimulationData(allocator);
    defer {
        for (entries.items) |entry| {
            allocator.free(entry.scenario_id);
        }
        entries.deinit(allocator);
    }

    try std.testing.expectEqual(entries.items.len, 2);
    try std.testing.expectEqual(entries.items[0].step, 0);
    try std.testing.expectEqual(entries.items[0].ppl, 504.600);
    try std.testing.expectEqual(entries.items[0].scenario_id, "S1");
}

test "loadFarmSnapshot" {
    const allocator = std.testing.allocator;
    const test_json = \\[
        {"name":"w7-35","ppl":4.46,"loss":1.49,"step":42000,"lr":"1e-3","batch":"66","optimizer":"lamb","seed":735}
        \\];

    const test_file = try std.fs.cwd().createFile("test_snapshot.json", .{});
    defer std.fs.cwd().deleteFile("test_snapshot.json") catch {};
    defer test_file.close();

    try test_file.writeAll(test_json);

    const workers = try loadFarmSnapshot(allocator, "test_snapshot.json");
    defer {
        for (workers.items) |worker| {
            allocator.free(worker.name);
            allocator.free(worker.lr);
            allocator.free(worker.batch);
            allocator.free(worker.optimizer);
        }
        workers.deinit(allocator);
    }

    try std.testing.expectEqual(workers.items.len, 1);
    try std.testing.expectEqual(workers.items[0].name, "w7-35");
    try std.testing.expectEqual(workers.items[0].ppl, 4.46);
}

test "aggregateByScenario" {
    const allocator = std.testing.allocator;
    var entries = std.ArrayList(SimulationEntry).init(allocator);

    // Добавляем тестовые записи для S1 (разные PPL)
    try entries.append(.{
        .step = 0,
        .scenario_id = try allocator.dupe(u8, "S1"),
        .ppl = 50.0,
        .diversity = 0.0,
        .alive = 25.0,
        .culled = 0.0,
        .byzantine = 0.0,
        .converged = true,
        .energy_cost = 2500.0,
        .fpga_lut = 8000,
        .fpga_bram = 30,
        .fpga_cost_norm = 0.220,
        .seed_rate = 0.0,
        .kill_rate = 0.0,
        .ntp_weight = 1.0,
        .jepa_weight = 0.0,
        .nca_weight = 0.0,
        .quantum_superposition = 0.0,
        .quantum_coherence = 0.0,
        .quantum_interference = 0.0,
        .quantum_collapse_prob = 0.0,
    });
    try entries.append(.{
        .step = 1,
        .scenario_id = try allocator.dupe(u8, "S1"),
        .ppl = 45.0,
        .diversity = 0.0,
        .alive = 25.0,
        .culled = 0.0,
        .byzantine = 0.0,
        .converged = false,
        .energy_cost = 5000.0,
        .fpga_lut = 8000,
        .fpga_bram = 30,
        .fpga_cost_norm = 0.440,
        .seed_rate = 0.0,
        .kill_rate = 0.0,
        .ntp_weight = 1.0,
        .jepa_weight = 0.0,
        .nca_weight = 0.0,
        .quantum_superposition = 0.0,
        .quantum_coherence = 0.0,
        .quantum_interference = 0.0,
        .quantum_collapse_prob = 0.0,
    });

    const summaries = try aggregateByScenario(allocator, entries);
    defer {
        for (summaries.items) |summary| {
            allocator.free(summary.id);
        }
        summaries.deinit(allocator);
    }

    // Должна быть одна сводка для S1
    try std.testing.expectEqual(summaries.items.len, 1);
    // Должна выбрать минимальный PPL (45.0)
    try std.testing.expectEqual(summaries.items[0].final_ppl, 45.0);
}
