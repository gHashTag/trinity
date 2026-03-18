// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// QUEEN CRON — Pure Zig Cron Scheduler for Tamagotchi Reports
// ═══════════════════════════════════════════════════════════════════════════════
// Schedules periodic tasks (e.g., 15-minute Tamagotchi growth reports)
// Uses std.Thread for background scheduling — no shell scripts, pure Zig
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const qt = @import("queen_types.zig");
const ofc = @import("queen_ofc.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// CRON STATE — Global daemon state (thread-safe)
// ═══════════════════════════════════════════════════════════════════════════════

pub const CronStatus = struct {
    job_id: []const u8 = "tamagotchi-report",
    next_run: i64 = 0,
    last_run: i64 = 0,
    run_count: u32 = 0,
    is_active: bool = false,

    pub fn format(self: CronStatus, allocator: Allocator) ![]const u8 {
        const next_str = if (self.next_run > 0)
            try fmtTimestamp(allocator, self.next_run)
        else
            try allocator.dupe(u8, "N/A");
        defer if (self.next_run > 0) allocator.free(next_str);

        const last_str = if (self.last_run > 0)
            try fmtTimestamp(allocator, self.last_run)
        else
            try allocator.dupe(u8, "never");
        defer if (self.last_run > 0) allocator.free(last_str);

        return std.fmt.allocPrint(allocator,
            \\Cron Job: {s}
            \\Status: {s}
            \\Runs: {d}
            \\Last: {s}
            \\Next: {s}
        , .{
            self.job_id,
            if (self.is_active) "ACTIVE" else "STOPPED",
            self.run_count,
            last_str,
            next_str,
        });
    }
};

fn fmtTimestamp(allocator: Allocator, ts: i64) ![]const u8 {
    const epoch = std.time.epoch.EpochSeconds{ .secs = @intCast(ts) };

    const year_day = epoch.getEpochDay().calculateYearDay();
    const month = year_day.calculateMonthDay();
    const month_name = switch (month.month) {
        .Jan => "Jan",
        .Feb => "Feb",
        .Mar => "Mar",
        .Apr => "Apr",
        .May => "May",
        .Jun => "Jun",
        .Jul => "Jul",
        .Aug => "Aug",
        .Sep => "Sep",
        .Oct => "Oct",
        .Nov => "Nov",
        .Dec => "Dec",
    };

    const seconds = epoch.getDaySeconds();
    const hour = seconds.getHoursIntoDay();
    const minute = seconds.getMinutesIntoHour();

    return std.fmt.allocPrint(allocator, "{s} {d} {d:0>2}:{d:0>2}", .{
        month_name, month.day_index + 1, hour, minute,
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
// CRON SCHEDULE — Parse and match cron expressions
// ═══════════════════════════════════════════════════════════════════════════════

pub const CronSchedule = struct {
    minute: ScheduleField,
    hour: ScheduleField,
    day_of_month: ScheduleField,
    month: ScheduleField,
    day_of_week: ScheduleField,

    pub fn init(spec: []const u8) !CronSchedule {
        // Parse "*/15 * * * *" format (min hour dom month dow)
        var parts = std.mem.splitScalar(u8, spec, ' ');
        const min_str = parts.first();
        const hour_str = parts.next() orelse return error.InvalidCronSpec;
        const dom_str = parts.next() orelse return error.InvalidCronSpec;
        const month_str = parts.next() orelse return error.InvalidCronSpec;
        const dow_str = parts.next() orelse return error.InvalidCronSpec;

        return CronSchedule{
            .minute = try parseField(min_str, 0, 59),
            .hour = try parseField(hour_str, 0, 23),
            .day_of_month = try parseField(dom_str, 1, 31),
            .month = try parseField(month_str, 1, 12),
            .day_of_week = try parseField(dow_str, 0, 6),
        };
    }

    /// Check if given timestamp matches this schedule
    pub fn matches(self: *const CronSchedule, ts: i64) bool {
        const epoch = std.time.epoch.EpochSeconds{ .secs = @intCast(ts) };
        const day_secs = epoch.getDaySeconds();
        const minute = day_secs.getMinutesIntoHour();
        const hour = day_secs.getHoursIntoDay();

        // Day of week calculation (0=Sun, 6=Sat)
        // Unix epoch (1970-01-01) was Thursday (4)
        const epoch_day = epoch.getEpochDay();
        const day_of_week = @as(u3, @intCast((epoch_day.day + 4) % 7));

        const year_day = epoch_day.calculateYearDay();
        const month_and_day = year_day.calculateMonthDay();
        const month_val = @intFromEnum(month_and_day.month) + 1;

        return self.minute.matches(minute) and
            self.hour.matches(hour) and
            self.day_of_month.matches(month_and_day.day_index + 1) and
            self.month.matches(month_val) and
            self.day_of_week.matches(day_of_week);
    }

    /// Calculate next run time after given timestamp
    pub fn nextRun(self: *const CronSchedule, after_ts: i64) i64 {
        var ts = after_ts + 60; // Start checking from next minute
        var max_iterations: u32 = 525600; // ~1 year of minutes, prevent infinite loop

        while (max_iterations > 0) : (max_iterations -= 1) {
            if (self.matches(ts)) return ts;
            ts += 60;
        }

        return after_ts + 900; // Fallback: 15 minutes from now
    }
};

pub const ScheduleField = struct {
    values: [64]bool = [_]bool{false} ** 64, // Bitmap for 0-63
    is_all: bool = false,

    pub fn matches(self: *const ScheduleField, value: u6) bool {
        return if (self.is_all) true else self.values[value];
    }
};

fn parseField(spec: []const u8, min: u6, max: u6) !ScheduleField {
    var field = ScheduleField{};

    // "*" means all values
    if (std.mem.eql(u8, spec, "*")) {
        field.is_all = true;
        return field;
    }

    // "*/N" means every N (e.g., "*/15" = every 15 minutes)
    if (std.mem.startsWith(u8, spec, "*/")) {
        const step_str = spec[2..];
        const step = std.fmt.parseInt(u6, step_str, 10) catch return error.InvalidCronSpec;
        if (step == 0) return error.InvalidCronSpec;

        var i: u6 = min;
        while (i <= max) : (i += step) {
            field.values[i] = true;
        }
        return field;
    }

    // Single number (e.g., "5")
    const value = std.fmt.parseInt(u6, spec, 10) catch return error.InvalidCronSpec;
    if (value < min or value > max) return error.OutOfRange;
    field.values[value] = true;

    return field;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAMAGOTCHI STATE — Growth metrics
// ═══════════════════════════════════════════════════════════════════════════════

pub const TamagotchiState = struct {
    hunger: u8 = 50, // 0-100 (100 = full, 0 = starving)
    happiness: u8 = 50, // 0-100
    discipline: u8 = 50, // 0-100
    rest: u8 = 100, // 0-100 (energy)
    health: u8 = 100, // 0-100
    arousal: u8 = 0, // 0-5 (Locus Coeruleus arousal level)

    age_hours: u32 = 0,
    stage: Stage = .egg,
    last_update: i64 = 0,
    feed_count: u32 = 0,
    play_count: u32 = 0,

    pub const Stage = enum {
        egg, // 0-2 hours
        baby, // 2-6 hours
        child, // 6-24 hours
        teen, // 24-72 hours
        adult, // 72+ hours

        pub fn label(self: Stage) []const u8 {
            return switch (self) {
                .egg => "EGG",
                .baby => "BABY",
                .child => "CHILD",
                .teen => "TEEN",
                .adult => "ADULT",
            };
        }

        pub fn emoji(self: Stage) []const u8 {
            return switch (self) {
                .egg => "\xf0\x9f\xa5\x9a", // 🥚
                .baby => "\xf0\x9f\x91\xb6", // 👶
                .child => "\xf0\x9f\xa7\x92", // 🧒
                .teen => "\xf0\x9f\x91\xa6", // 👦
                .adult => "\xf0\x9f\x91\xa8", // 👨
            };
        }

        pub fn fromAge(hours: u32) Stage {
            if (hours < 2) return .egg;
            if (hours < 6) return .baby;
            if (hours < 24) return .child;
            if (hours < 72) return .teen;
            return .adult;
        }
    };

    pub fn updateStage(self: *TamagotchiState) void {
        self.stage = Stage.fromAge(self.age_hours);
    }

    pub fn decay(self: *TamagotchiState) void {
        // Natural decay over 15 minutes
        if (self.hunger > 0) self.hunger -|= 2;
        if (self.happiness > 0) self.happiness -|= 1;
        if (self.rest > 0) self.rest -|= 1;
        if (self.discipline > 0) self.discipline -|= 1;
        self.age_hours += 1; // Approximate (15 min chunks)
        self.updateStage();
    }

    pub fn isSick(self: *const TamagotchiState) bool {
        return self.health < 30 or self.hunger < 10 or self.rest < 10;
    }

    pub fn healthStatus(self: *const TamagotchiState) []const u8 {
        if (self.health >= 80 and self.hunger >= 70) return "Thriving";
        if (self.health >= 50) return "Healthy";
        if (self.health >= 30) return "Weak";
        return "Critical";
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// GLOBAL STATE (protected by mutex)
// ═══════════════════════════════════════════════════════════════════════════════

var cron_mutex = std.Thread.Mutex{};
var cron_state: CronState = .{
    .schedule = undefined,
    .tamagotchi = .{},
    .thread_handle = null,
    .should_stop = false,
    .allocator = undefined,
    .initialized = false,
};

const CronState = struct {
    schedule: CronSchedule,
    tamagotchi: TamagotchiState,
    thread_handle: ?std.Thread,
    should_stop: bool,
    allocator: Allocator,
    initialized: bool,
};

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API
// ═══════════════════════════════════════════════════════════════════════════════

/// Start Tamagotchi cron daemon
pub fn startTamagotchiCron(allocator: Allocator) !void {
    cron_mutex.lock();
    defer cron_mutex.unlock();

    if (cron_state.initialized and cron_state.thread_handle != null) {
        return error.AlreadyRunning;
    }

    // Initialize schedule (every 15 minutes)
    cron_state.schedule = try CronSchedule.init("*/15 * * * *");
    cron_state.allocator = allocator;
    cron_state.should_stop = false;
    cron_state.initialized = true;

    // Load previous state if exists
    loadTamagotchiState(&cron_state.tamagotchi);

    // Spawn cron thread
    const thread = try std.Thread.spawn(.{}, cronLoop, .{});
    cron_state.thread_handle = thread;
    cron_state.tamagotchi.last_update = std.time.timestamp();
}

/// Stop Tamagotchi cron daemon
pub fn stopTamagotchiCron() !void {
    cron_mutex.lock();
    defer cron_mutex.unlock();

    if (!cron_state.initialized) {
        return error.NotRunning;
    }

    cron_state.should_stop = true;

    if (cron_state.thread_handle) |handle| {
        // Signal thread to wake up
        std.Thread.Condition{};
        handle.join();
        cron_state.thread_handle = null;
    }

    cron_state.initialized = false;
}

/// Get cron job status
pub fn getCronStatus() CronStatus {
    cron_mutex.lock();
    defer cron_mutex.unlock();

    const next_run = if (cron_state.initialized)
        cron_state.schedule.nextRun(std.time.timestamp())
    else
        0;

    return CronStatus{
        .job_id = "tamagotchi-report",
        .next_run = next_run,
        .last_run = cron_state.tamagotchi.last_update,
        .run_count = cron_state.tamagotchi.age_hours, // Approximate
        .is_active = cron_state.initialized and !cron_state.should_stop,
    };
}

/// Generate rich Tamagotchi report (called by cron)
pub fn generateTamagotchiReport(allocator: Allocator) ![]const u8 {
    cron_mutex.lock();
    const tama = cron_state.tamagotchi;
    cron_mutex.unlock();

    const stage_emoji = tama.stage.emoji();
    const stage_label = tama.stage.label();

    // Progress bars (5 chars each: [████_] = 80%)
    const hunger_bar = buildProgressBar(tama.hunger);
    const happy_bar = buildProgressBar(tama.happiness);
    const disc_bar = buildProgressBar(tama.discipline);
    const rest_bar = buildProgressBar(tama.rest);
    const health_bar = buildProgressBar(tama.health);

    // Status emoji
    const health_emoji = if (tama.health >= 80) qt.E_CHECK else if (tama.health >= 50) qt.E_WRENCH else qt.E_SIREN;
    const mood_emoji = if (tama.happiness >= 70) "\xf0\x9f\x98\x8a" else if (tama.happiness >= 40) "\xf0\x9f\x98\x90" else "\xf0\x9f\x98\xa2"; // 😊 😐 😢

    // Stage-specific messages
    const stage_message = switch (tama.stage) {
        .egg => "Sleeping in the egg... Wake me in 2 hours!",
        .baby => "Needs lots of attention! Feed me often!",
        .child => "Growing strong! Teach me discipline.",
        .teen => "Getting rebellious... Keep me in line!",
        .adult => "Fully grown! Maintaining health.",
    };

    // Build report
    return std.fmt.allocPrint(allocator,
        \\{s} {s} STAGE — {s}
        \\
        \\{s} Health: {s} {d}%
        \\{s} Hunger: {s} {d}%
        \\{s} Happy: {s} {d}%
        \\{s} Discip: {s} {d}%
        \\{s}  Rest: {s} {d}%
        \\{s} Arousal: Level {d}/5
        \\
        \\{s} Age: {d}h | Fed: {d}x | Played: {d}x
        \\
        \\{s}
        \\
        \\_Queen Cron v1.0 — Pure Zig Scheduler_
    , .{
        stage_emoji,     stage_label,
        // Health
        health_emoji,    health_bar,
        tama.health,
        // Hunger
            if (tama.hunger >= 70) qt.E_CHECK else if (tama.hunger >= 30) qt.E_WRENCH else qt.E_SIREN,
        hunger_bar,      tama.hunger,
        // Happiness
        mood_emoji,      happy_bar,
        tama.happiness,
        // Discipline
         qt.E_GEAR,
        disc_bar,        tama.discipline,
        // Rest
        qt.E_TIMER,      rest_bar,
        tama.rest,
        // Arousal
              qt.E_BOLT,
        tama.arousal,
        // Stats
           qt.E_CHART,
        tama.age_hours,  tama.feed_count,
        tama.play_count,
        // Message
        qt.E_BRAIN,
        stage_message,
    });
}

/// Feed the Tamagotchi (increase hunger, small happiness boost)
pub fn feedTamagotchi() !void {
    cron_mutex.lock();
    defer cron_mutex.unlock();

    if (!cron_state.initialized) return error.NotRunning;

    cron_state.tamagotchi.hunger = @min(100, cron_state.tamagotchi.hunger + 20);
    cron_state.tamagotchi.happiness = @min(100, cron_state.tamagotchi.happiness + 5);
    cron_state.tamagotchi.feed_count += 1;
    cron_state.tamagotchi.last_update = std.time.timestamp();

    try saveTamagotchiState(&cron_state.tamagotchi);
}

/// Play with the Tamagotchi (increase happiness, decrease rest)
pub fn playTamagotchi() !void {
    cron_mutex.lock();
    defer cron_mutex.unlock();

    if (!cron_state.initialized) return error.NotRunning;

    cron_state.tamagotchi.happiness = @min(100, cron_state.tamagotchi.happiness + 15);
    cron_state.tamagotchi.rest = if (cron_state.tamagotchi.rest >= 10) cron_state.tamagotchi.rest - 10 else 0;
    cron_state.tamagotchi.play_count += 1;
    cron_state.tamagotchi.last_update = std.time.timestamp();

    try saveTamagotchiState(&cron_state.tamagotchi);
}

/// Discipline the Tamagotchi (increase discipline, decrease happiness)
pub fn disciplineTamagotchi() !void {
    cron_mutex.lock();
    defer cron_mutex.unlock();

    if (!cron_state.initialized) return error.NotRunning;

    cron_state.tamagotchi.discipline = @min(100, cron_state.tamagotchi.discipline + 15);
    cron_state.tamagotchi.happiness = if (cron_state.tamagotchi.happiness >= 10) cron_state.tamagotchi.happiness - 10 else 0;
    cron_state.tamagotchi.last_update = std.time.timestamp();

    try saveTamagotchiState(&cron_state.tamagotchi);
}

/// Rest the Tamagotchi (restore rest)
pub fn restTamagotchi() !void {
    cron_mutex.lock();
    defer cron_mutex.unlock();

    if (!cron_state.initialized) return error.NotRunning;

    cron_state.tamagotchi.rest = @min(100, cron_state.tamagotchi.rest + 25);
    cron_state.tamagotchi.health = @min(100, cron_state.tamagotchi.health + 5);
    cron_state.tamagotchi.last_update = std.time.timestamp();

    try saveTamagotchiState(&cron_state.tamagotchi);
}

// ═══════════════════════════════════════════════════════════════════════════════
// INTERNAL FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

fn cronLoop() void {
    const interval_ns: u64 = 60 * std.time.ns_per_s; // Check every minute

    while (true) {
        // Check if we should stop
        {
            cron_mutex.lock();
            const should_stop = cron_state.should_stop;
            cron_mutex.unlock();

            if (should_stop) break;
        }

        const now = std.time.timestamp();

        // Check if schedule matches
        cron_mutex.lock();
        const matches = cron_state.schedule.matches(now);
        cron_mutex.unlock();

        if (matches) {
            // Execute report
            executeReport() catch |err| {
                std.debug.print("Cron report failed: {}\n", .{err});
            };

            // Decay stats
            cron_mutex.lock();
            cron_state.tamagotchi.decay();
            cron_state.tamagotchi.last_update = now;

            // Check health status
            if (cron_state.tamagotchi.isSick()) {
                // Trigger alert via OFC
                sendHealthAlert(&cron_state.tamagotchi) catch {};
            }

            cron_mutex.unlock();

            // Save state
            saveTamagotchiState(&cron_state.tamagotchi) catch {};
        }

        // Sleep until next check
        std.Thread.sleep(interval_ns);
    }
}

fn executeReport() !void {
    const report = try generateTamagotchiReport(cron_state.allocator);
    defer cron_state.allocator.free(report);

    // Send via OFC (Queen Telegram)
    try ofc.send(cron_state.allocator, .group, report);
}

fn sendHealthAlert(tama: *const TamagotchiState) !void {
    const alert = try std.fmt.allocPrint(
        cron_state.allocator,
        "{s} {s} is {s}!\n\n{s} Hunger: {d}%\n{s} Health: {d}%",
        .{
            tama.stage.emoji(),
            tama.stage.label(),
            tama.healthStatus(),
            if (tama.hunger < 10) qt.E_SIREN else qt.E_WRENCH,
            tama.hunger,
            if (tama.health < 30) qt.E_SIREN else qt.E_WRENCH,
            tama.health,
        },
    );
    defer cron_state.allocator.free(alert);

    try ofc.send(cron_state.allocator, .alert, alert);
}

fn buildProgressBar(value: u8) []const u8 {
    const filled = if (value == 0) @as(u8, 0) else (1 + (value - 1) / 20); // 0-5 blocks (min 1 if > 0)

    if (filled == 0) return "[     ]";
    if (filled == 1) return "[█    ]";
    if (filled == 2) return "[██   ]";
    if (filled == 3) return "[███  ]";
    if (filled == 4) return "[████ ]";
    return "[█████]";
}

const STATE_PATH = ".trinity/queen_tamagotchi.json";

fn saveTamagotchiState(tama: *const TamagotchiState) !void {
    const file = try std.fs.cwd().createFile(STATE_PATH, .{});
    defer file.close();

    const writer = file.writer();

    try writer.print(
        \\{{"hunger":{d},"happiness":{d},"discipline":{d},"rest":{d},"health":{d},"arousal":{d},"age_hours":{d},"stage":"{s}","last_update":{d},"feed_count":{d},"play_count":{d}}}
    , .{
        tama.hunger,
        tama.happiness,
        tama.discipline,
        tama.rest,
        tama.health,
        tama.arousal,
        tama.age_hours,
        @tagName(tama.stage),
        tama.last_update,
        tama.feed_count,
        tama.play_count,
    });
}

fn loadTamagotchiState(tama: *TamagotchiState) void {
    const file = std.fs.cwd().openFile(STATE_PATH, .{}) catch return;
    defer file.close();

    var buf: [512]u8 = undefined;
    const n = file.readAll(&buf) catch return;
    const data = buf[0..n];

    if (qt.findJsonU32(data, "\"hunger\":")) |v| tama.hunger = @intCast(v);
    if (qt.findJsonU32(data, "\"happiness\":")) |v| tama.happiness = @intCast(v);
    if (qt.findJsonU32(data, "\"discipline\":")) |v| tama.discipline = @intCast(v);
    if (qt.findJsonU32(data, "\"rest\":")) |v| tama.rest = @intCast(v);
    if (qt.findJsonU32(data, "\"health\":")) |v| tama.health = @intCast(v);
    if (qt.findJsonU32(data, "\"arousal\":")) |v| tama.arousal = @intCast(v);
    if (qt.findJsonU32(data, "\"age_hours\":")) |v| tama.age_hours = v;
    if (qt.findJsonI64(data, "\"last_update\":")) |v| tama.last_update = v;
    if (qt.findJsonU32(data, "\"feed_count\":")) |v| tama.feed_count = v;
    if (qt.findJsonU32(data, "\"play_count\":")) |v| tama.play_count = v;

    if (qt.findJsonStr(data, "\"stage\":\"")) |stage_str| {
        if (std.mem.eql(u8, stage_str, "egg")) tama.stage = .egg;
        if (std.mem.eql(u8, stage_str, "baby")) tama.stage = .baby;
        if (std.mem.eql(u8, stage_str, "child")) tama.stage = .child;
        if (std.mem.eql(u8, stage_str, "teen")) tama.stage = .teen;
        if (std.mem.eql(u8, stage_str, "adult")) tama.stage = .adult;
    }

    tama.updateStage();
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "queen_cron — CronSchedule parses */15" {
    const schedule = try CronSchedule.init("*/15 * * * *");
    try std.testing.expectEqual(true, schedule.minute.values[0]);
    try std.testing.expectEqual(true, schedule.minute.values[15]);
    try std.testing.expectEqual(true, schedule.minute.values[30]);
    try std.testing.expectEqual(true, schedule.minute.values[45]);
}

test "queen_cron — CronSchedule parses single values" {
    const schedule = try CronSchedule.init("5 12 * * *");
    try std.testing.expectEqual(true, schedule.minute.values[5]);
    try std.testing.expectEqual(true, schedule.hour.values[12]);
}

test "queen_cron — CronSchedule parses wildcard" {
    const schedule = try CronSchedule.init("* * * * *");
    try std.testing.expect(schedule.hour.is_all);
}

test "queen_cron — TamagotchiStage fromAge" {
    try std.testing.expectEqual(TamagotchiState.Stage.egg, TamagotchiState.Stage.fromAge(0));
    try std.testing.expectEqual(TamagotchiState.Stage.egg, TamagotchiState.Stage.fromAge(1));
    try std.testing.expectEqual(TamagotchiState.Stage.baby, TamagotchiState.Stage.fromAge(2));
    try std.testing.expectEqual(TamagotchiState.Stage.baby, TamagotchiState.Stage.fromAge(5));
    try std.testing.expectEqual(TamagotchiState.Stage.child, TamagotchiState.Stage.fromAge(6));
    try std.testing.expectEqual(TamagotchiState.Stage.child, TamagotchiState.Stage.fromAge(23));
    try std.testing.expectEqual(TamagotchiState.Stage.teen, TamagotchiState.Stage.fromAge(24));
    try std.testing.expectEqual(TamagotchiState.Stage.teen, TamagotchiState.Stage.fromAge(71));
    try std.testing.expectEqual(TamagotchiState.Stage.adult, TamagotchiState.Stage.fromAge(72));
    try std.testing.expectEqual(TamagotchiState.Stage.adult, TamagotchiState.Stage.fromAge(1000));
}

test "queen_cron — TamagotchiState decay" {
    var tama = TamagotchiState{
        .hunger = 100,
        .happiness = 100,
        .discipline = 100,
        .rest = 100,
        .age_hours = 0,
    };

    tama.decay();
    try std.testing.expectEqual(@as(u8, 98), tama.hunger);
    try std.testing.expectEqual(@as(u8, 99), tama.happiness);
    try std.testing.expectEqual(@as(u8, 99), tama.discipline);
    try std.testing.expectEqual(@as(u8, 99), tama.rest);
    try std.testing.expectEqual(@as(u32, 1), tama.age_hours);
}

test "queen_cron — TamagotchiState isSick" {
    var tama = TamagotchiState{ .health = 100, .hunger = 100, .rest = 100 };
    try std.testing.expect(!tama.isSick());

    tama.health = 20;
    try std.testing.expect(tama.isSick());

    tama.health = 100;
    tama.hunger = 5;
    try std.testing.expect(tama.isSick());
}

test "queen_cron — TamagotchiState healthStatus" {
    var tama = TamagotchiState{ .health = 90, .hunger = 80 };
    try std.testing.expectEqualStrings("Thriving", tama.healthStatus());

    tama.health = 60;
    try std.testing.expectEqualStrings("Healthy", tama.healthStatus());

    tama.health = 35;
    try std.testing.expectEqualStrings("Weak", tama.healthStatus());

    tama.health = 20;
    try std.testing.expectEqualStrings("Critical", tama.healthStatus());
}

test "queen_cron — buildProgressBar" {
    try std.testing.expectEqualStrings("[     ]", buildProgressBar(0));
    try std.testing.expectEqualStrings("[█    ]", buildProgressBar(10));
    try std.testing.expectEqualStrings("[██   ]", buildProgressBar(30));
    try std.testing.expectEqualStrings("[███  ]", buildProgressBar(50));
    try std.testing.expectEqualStrings("[████ ]", buildProgressBar(80));
    try std.testing.expectEqualStrings("[█████]", buildProgressBar(100));
}

test "queen_cron — CronSchedule nextRun" {
    const schedule = try CronSchedule.init("*/15 * * * *");
    const base_ts: i64 = 1700000000; // Some arbitrary timestamp

    // Next run should be within 15 minutes (900 seconds)
    const next = schedule.nextRun(base_ts);
    try std.testing.expect(next > base_ts);
    try std.testing.expect(next - base_ts <= 900);
}

test "queen_cron — getCronStatus returns default when not running" {
    const status = getCronStatus();
    try std.testing.expect(!status.is_active);
    try std.testing.expectEqual(@as(u32, 0), status.run_count);
    try std.testing.expectEqualStrings("tamagotchi-report", status.job_id);
}

test "queen_cron — Stage emoji and label" {
    try std.testing.expectEqualStrings("EGG", TamagotchiState.Stage.egg.label());
    try std.testing.expectEqualStrings("BABY", TamagotchiState.Stage.baby.label());
    try std.testing.expectEqualStrings("CHILD", TamagotchiState.Stage.child.label());
    try std.testing.expectEqualStrings("TEEN", TamagotchiState.Stage.teen.label());
    try std.testing.expectEqualStrings("ADULT", TamagotchiState.Stage.adult.label());

    // Check emojis are valid UTF-8
    for ([_]TamagotchiState.Stage{ .egg, .baby, .child, .teen, .adult }) |stage| {
        const emoji = stage.emoji();
        try std.testing.expect(emoji.len > 0);
        // Verify first byte is valid UTF-8 start byte (0xE0-0xF0 for 3-4 byte emojis)
        try std.testing.expect(emoji[0] >= 0xE0 and emoji[0] <= 0xF0);
    }
}

test "queen_cron — CronSchedule nextRun for hourly schedule" {
    const schedule = try CronSchedule.init("0 * * * *"); // Every hour at minute 0
    const base_ts: i64 = 1700000000;

    const next = schedule.nextRun(base_ts);
    try std.testing.expect(next > base_ts);
    try std.testing.expect(next - base_ts <= 3600); // Within 1 hour
}
