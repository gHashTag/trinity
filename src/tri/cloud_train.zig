// @origin(spec:cloud_train.tri) @regen(manual-impl)
// =============================================================================
// CLOUD TRAIN + FARM — HSLM training & multi-account farm management
// =============================================================================
//
// Extracted from tri_cloud.zig to reduce file size.
// Commands:
//   tri cloud farm [sync|capacity|rebalance]
//   tri cloud train <name> [--optimizer X] [--lr X] ...
//   tri cloud train-batch
//   tri cloud delete-service <service-id> [--account N]
//   tri cloud metal
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

const std = @import("std");
const Allocator = std.mem.Allocator;
const railway_api = @import("railway_api.zig");
const railway_farm = @import("railway_farm.zig");

const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const RED = "\x1b[31m";
const CYAN = "\x1b[36m";
const GRAY = "\x1b[90m";
const GOLDEN = "\x1b[38;5;220m";

const print = std.debug.print;
const eql = std.mem.eql;

// =============================================================================
// METAL -- Enable Metal build environment across all services
// =============================================================================

pub fn cloudMetal(allocator: Allocator) !void {
    var farm = railway_farm.RailwayFarm.init();

    if (farm.account_count == 0) {
        print("{s}No Railway accounts configured.{s}\n", .{ RED, RESET });
        return;
    }

    // Metal region: us-west2 = California Metal (Railway Metal)
    const METAL_REGION = "us-west2";

    print("\n{s}{s}=== RAILWAY METAL ==============================================={s}\n", .{ GOLDEN, BOLD, RESET });
    print("{s}Switching ALL services to Metal region ({s}) across {d} account(s)...{s}\n\n", .{ CYAN, METAL_REGION, farm.account_count, RESET });

    var total_ok: u32 = 0;
    var total_fail: u32 = 0;
    var total_already: u32 = 0;
    var total_services: u32 = 0;

    for (farm.accounts[0..farm.account_count]) |*acct| {
        print("  {s}{s}{s} (account {d}):\n", .{ BOLD, acct.getAlias(), RESET, acct.id });

        var api = farm.getApi(allocator, acct.id) catch {
            print("    {s}SKIP -- API init failed{s}\n", .{ RED, RESET });
            continue;
        };
        defer api.deinit();

        // 1. Check current service instances and their regions
        const env_id = api.environment_id;
        if (env_id.len == 0) {
            print("    {s}SKIP -- no RAILWAY_ENVIRONMENT_ID for this account{s}\n", .{ YELLOW, RESET });
            continue;
        }

        const instances_json = api.getServiceInstances("") catch |err| {
            print("    {s}SKIP -- getServiceInstances failed: {}{s}\n", .{ RED, err, RESET });
            // Fall through to service-based approach
            continue;
        };
        defer allocator.free(instances_json);

        // Display current regions
        {
            var offset: usize = 0;
            while (std.mem.indexOfPos(u8, instances_json, offset, "\"serviceName\":\"")) |sn_idx| {
                const sn_start = sn_idx + 15;
                const sn_end = std.mem.indexOfPos(u8, instances_json, sn_start, "\"") orelse break;
                const svc_name = instances_json[sn_start..sn_end];

                var region: []const u8 = "unknown";
                if (std.mem.indexOfPos(u8, instances_json, sn_end, "\"region\":\"")) |r_idx| {
                    const r_start = r_idx + 10;
                    const r_end = std.mem.indexOfPos(u8, instances_json, r_start, "\"") orelse r_start;
                    region = instances_json[r_start..r_end];
                }

                total_services += 1;
                // Metal regions: us-west2, us-east4, europe-west4, asia-southeast1
                // Non-metal: us-west1 (Oregon, old GCP)
                const is_metal = std.mem.eql(u8, region, "us-west2") or
                    std.mem.eql(u8, region, "us-east4") or
                    std.mem.eql(u8, region, "europe-west4") or
                    std.mem.eql(u8, region, "asia-southeast1") or
                    std.mem.indexOf(u8, region, "us-west2-") != null or
                    std.mem.indexOf(u8, region, "us-east4-") != null;

                if (is_metal) {
                    print("    {s}{s}{s} -- {s}{s} (already Metal){s}\n", .{ CYAN, svc_name, RESET, GREEN, region, RESET });
                    total_already += 1;
                } else {
                    print("    {s}{s}{s} -- {s}{s}{s} -> switching...\n", .{ CYAN, svc_name, RESET, YELLOW, region, RESET });
                }
                offset = sn_end + 1;
            }
        }

        // 2. Get all services (to get IDs)
        const services_json = api.getServices() catch |err| {
            print("    {s}SKIP -- getServices failed: {}{s}\n", .{ RED, err, RESET });
            continue;
        };
        defer allocator.free(services_json);

        // Parse service IDs and names
        var svc_ids: [50][]const u8 = undefined;
        var svc_names: [50][]const u8 = undefined;
        var svc_count: usize = 0;

        {
            var offset: usize = 0;
            while (svc_count < 50) {
                const id_needle = "\"id\":\"";
                const id_idx = std.mem.indexOfPos(u8, services_json, offset, id_needle) orelse break;
                const id_start = id_idx + id_needle.len;
                const id_end = std.mem.indexOfPos(u8, services_json, id_start, "\"") orelse break;

                const name_needle = "\"name\":\"";
                const name_idx = std.mem.indexOfPos(u8, services_json, id_end, name_needle) orelse break;
                const name_start = name_idx + name_needle.len;
                const name_end = std.mem.indexOfPos(u8, services_json, name_start, "\"") orelse break;

                svc_ids[svc_count] = services_json[id_start..id_end];
                svc_names[svc_count] = services_json[name_start..name_end];
                svc_count += 1;
                offset = name_end + 1;
            }
        }

        // 3. Update each service to Metal region
        for (svc_ids[0..svc_count], svc_names[0..svc_count]) |svc_id, svc_name| {
            print("    {s}{s}{s} -> {s} ... ", .{ CYAN, svc_name, RESET, METAL_REGION });

            const response = api.serviceInstanceUpdateRegion(svc_id, "", METAL_REGION) catch |err| {
                print("{s}FAIL ({s}){s}\n", .{ RED, @errorName(err), RESET });
                total_fail += 1;
                continue;
            };
            defer allocator.free(response);

            if (std.mem.indexOf(u8, response, "\"errors\"") != null) {
                if (std.mem.indexOf(u8, response, "\"message\":\"")) |msg_idx| {
                    const msg_start = msg_idx + 11;
                    const msg_end = std.mem.indexOfPos(u8, response, msg_start, "\"") orelse msg_start + 50;
                    const max_end = @min(msg_end, response.len);
                    print("{s}FAIL ({s}){s}\n", .{ RED, response[msg_start..max_end], RESET });
                } else {
                    print("{s}FAIL (API error){s}\n", .{ RED, RESET });
                }
                total_fail += 1;
            } else {
                print("{s}METAL{s}\n", .{ GREEN, RESET });
                total_ok += 1;
            }
        }
        print("\n", .{});
    }

    // Summary
    print("{s}{s}=== SUMMARY ================================================{s}\n", .{ GOLDEN, BOLD, RESET });
    print("  Services:    {d}\n", .{total_services});
    print("  {s}Metal OK:{s}    {d}\n", .{ GREEN, RESET, total_ok });
    if (total_already > 0) {
        print("  {s}Already Metal:{s} {d}\n", .{ GREEN, RESET, total_already });
    }
    if (total_fail > 0) {
        print("  {s}Failed:{s}      {d}\n", .{ RED, RESET, total_fail });
    }
    print("{s}============================================================{s}\n\n", .{ GOLDEN, RESET });
}

// =============================================================================
// FARM -- Multi-Account Management
// =============================================================================

pub fn cloudFarm(allocator: Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        return cloudFarmDashboard();
    }

    const subcmd = args[0];
    if (eql(u8, subcmd, "sync")) {
        return cloudFarmSync(allocator);
    } else if (eql(u8, subcmd, "capacity")) {
        return cloudFarmCapacity();
    } else if (eql(u8, subcmd, "rebalance")) {
        return cloudFarmRebalance(allocator);
    } else {
        print("{s}Unknown farm subcommand: {s}{s}\n", .{ RED, subcmd, RESET });
        print("Usage: tri cloud farm [sync|capacity|rebalance]\n", .{});
    }
}

/// tri cloud farm -- Dashboard showing all Railway accounts with capacity
fn cloudFarmDashboard() void {
    var farm = railway_farm.RailwayFarm.init();

    if (farm.account_count == 0) {
        print("{s}No Railway accounts configured.{s}\n", .{ RED, RESET });
        print("Set RAILWAY_API_TOKEN in .env (and _2, _3 for multi-account)\n", .{});
        return;
    }

    print("\n{s}{s}", .{ GOLDEN, BOLD });
    print("===============================================================\n", .{});
    print("  TRINITY FARM -- {d} Railway Account(s)\n", .{farm.account_count});
    print("==============================================================={s}\n", .{RESET});

    print("  {s}Account       Active   Slots   Daily (used/max){s}\n", .{ BOLD, RESET });
    print("  {s}------------  ------   -----   ----------------{s}\n", .{ GRAY, RESET });

    var total_active: u16 = 0;
    var total_max: u16 = 0;
    var total_daily_used: u16 = 0;
    var total_daily_max: u16 = 0;

    for (farm.accounts[0..farm.account_count]) |*acct| {
        const alias = acct.getAlias();
        const slots = acct.availableSlots();
        const color = if (slots > 5) GREEN else if (slots > 0) YELLOW else RED;

        // Pad alias to 12 chars
        var alias_buf: [12]u8 = [_]u8{' '} ** 12;
        const copy_len = @min(alias.len, 12);
        @memcpy(alias_buf[0..copy_len], alias[0..copy_len]);

        print("  {s}{s}{s}   {d}/{d}      {s}{d}{s}       {d}/{d}\n", .{
            CYAN,
            @as([]const u8, &alias_buf),
            RESET,
            acct.active_services,
            acct.max_concurrent,
            color,
            slots,
            RESET,
            acct.daily_creates,
            acct.max_daily_creates,
        });

        total_active += acct.active_services;
        total_max += acct.max_concurrent;
        total_daily_used += acct.daily_creates;
        total_daily_max += acct.max_daily_creates;
    }

    print("  {s}------------  ------   -----   ----------------{s}\n", .{ GRAY, RESET });

    const total_slots = total_max -| total_active;
    print("  {s}TOTAL         {d}/{d}     {d}       {d}/{d}{s}\n", .{
        BOLD,
        total_active,
        total_max,
        total_slots,
        total_daily_used,
        total_daily_max,
        RESET,
    });

    // Show next spawn recommendation
    if (farm.selectAccount()) |best| {
        print("\n  {s}Next spawn -> {s}{s} (most available){s}\n", .{ GRAY, GREEN, best.getAlias(), RESET });
    } else {
        print("\n  {s}All accounts exhausted -- wait for daily reset or kill idle agents{s}\n", .{ RED, RESET });
    }

    print("{s}==============================================================={s}\n\n", .{ GOLDEN, RESET });
}

/// tri cloud farm sync -- Refresh service counts from Railway APIs
fn cloudFarmSync(allocator: Allocator) void {
    var farm = railway_farm.RailwayFarm.init();

    if (farm.account_count == 0) {
        print("{s}No Railway accounts configured.{s}\n", .{ RED, RESET });
        return;
    }

    print("{s}Syncing {d} Railway account(s)...{s}\n", .{ CYAN, farm.account_count, RESET });
    farm.syncAll(allocator);

    for (farm.accounts[0..farm.account_count]) |*acct| {
        print("  {s}{s}{s}: {d} active services\n", .{
            GREEN,
            acct.getAlias(),
            RESET,
            acct.active_services,
        });
    }

    print("{s}Sync complete. State saved.{s}\n", .{ GREEN, RESET });
}

/// tri cloud farm capacity -- JSON output for scripts/MCP
fn cloudFarmCapacity() void {
    var farm = railway_farm.RailwayFarm.init();
    const cap = farm.totalCapacity();

    var buf: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const w = fbs.writer();

    std.fmt.format(w, "{{\"total_slots\":{d},\"total_active\":{d},\"total_daily_remaining\":{d},\"accounts\":[", .{
        cap.total_slots,
        cap.total_active,
        cap.total_daily_remaining,
    }) catch return;

    var first = true;
    for (farm.accounts[0..farm.account_count]) |*acct| {
        if (!first) w.writeAll(",") catch return;
        first = false;
        std.fmt.format(w, "\n  {{\"id\":{d},\"alias\":\"{s}\",\"active\":{d},\"slots\":{d},\"daily_remaining\":{d}}}", .{
            acct.id,
            acct.getAlias(),
            acct.active_services,
            acct.availableSlots(),
            acct.max_daily_creates -| acct.daily_creates,
        }) catch return;
    }

    w.writeAll("\n]}\n") catch return;
    print("{s}", .{fbs.getWritten()});
}

/// tri cloud farm rebalance -- Migrate services between accounts
fn cloudFarmRebalance(allocator: Allocator) void {
    var farm = railway_farm.RailwayFarm.init();

    if (farm.account_count < 2) {
        print("{s}Need at least 2 accounts to rebalance.{s}\n", .{ YELLOW, RESET });
        return;
    }

    // Find overloaded (>80%) and underloaded (<30%) accounts
    var overloaded: ?*railway_farm.RailwayAccount = null;
    var underloaded: ?*railway_farm.RailwayAccount = null;

    for (farm.accounts[0..farm.account_count]) |*acct| {
        const usage = if (acct.max_concurrent > 0)
            @as(u32, acct.active_services) * 100 / @as(u32, acct.max_concurrent)
        else
            0;

        if (usage > 80 and (overloaded == null or acct.active_services > overloaded.?.active_services)) {
            overloaded = acct;
        }
        if (usage < 30 and (underloaded == null or acct.active_services < underloaded.?.active_services)) {
            underloaded = acct;
        }
    }

    if (overloaded == null or underloaded == null) {
        print("{s}No rebalancing needed -- all accounts within 30-80%% capacity.{s}\n", .{ GREEN, RESET });
        return;
    }

    print("{s}Rebalance: {s} -> {s}{s}\n", .{
        CYAN,
        overloaded.?.getAlias(),
        underloaded.?.getAlias(),
        RESET,
    });

    // Find agents on overloaded account and migrate
    var migrated: u32 = 0;
    for (farm.agent_map[0..farm.agent_map_count]) |*m| {
        if (m.account_id != overloaded.?.id) continue;
        if (!underloaded.?.canSpawn()) break;

        print("  Migrating agent-{d}: {s} -> {s} ... ", .{
            m.issue,
            overloaded.?.getAlias(),
            underloaded.?.getAlias(),
        });

        // Kill on source
        var src_api = farm.getApi(allocator, overloaded.?.id) catch {
            print("{s}SKIP (API error){s}\n", .{ RED, RESET });
            continue;
        };
        defer src_api.deinit();
        _ = src_api.deleteService(m.getServiceId()) catch {
            print("{s}SKIP (delete failed){s}\n", .{ RED, RESET });
            continue;
        };

        // Create on target
        var tgt_api = farm.getApi(allocator, underloaded.?.id) catch {
            print("{s}FAIL (target API){s}\n", .{ RED, RESET });
            continue;
        };
        defer tgt_api.deinit();

        var name_buf: [32]u8 = undefined;
        const svc_name = std.fmt.bufPrint(&name_buf, "agent-{d}", .{m.issue}) catch continue;
        const response = tgt_api.createService(svc_name) catch {
            print("{s}FAIL (create failed){s}\n", .{ RED, RESET });
            continue;
        };
        allocator.free(response);

        // Update mapping
        m.account_id = underloaded.?.id;
        overloaded.?.active_services -|= 1;
        underloaded.?.active_services += 1;
        migrated += 1;
        print("{s}OK{s}\n", .{ GREEN, RESET });
    }

    farm.saveState();
    print("\n{s}Rebalanced {d} service(s){s}\n", .{ GREEN, migrated, RESET });
}

// =============================================================================
// HSLM TRAINING -- Spawn training experiments on Railway farm
// =============================================================================

pub const TrainConfig = struct {
    name: []const u8,
    optimizer: []const u8 = "adam",
    lr: []const u8 = "3e-4",
    batch: u32 = 66,
    grad_accum: u32 = 2,
    seed: u32 = 42,
    steps: u32 = 100000,
    context: u32 = 24,
    dropout: []const u8 = "0.1",
    wd: []const u8 = "0.1",
    lr_schedule: []const u8 = "cosine",
    restart_period: u32 = 0,
    full_ternary: bool = false,
    ternary_schedule: bool = false,
    adaptive_sparsity: bool = false,
    phi_scale: bool = false,
    workers: u32 = 6,
    checkpoint_every: u32 = 10000,
    account: u8 = 0, // 0 = auto-select
};

/// Shared logic: create service, connect repo, set env vars, set region.
fn spawnTrainService(allocator: Allocator, config: TrainConfig, farm: *railway_farm.RailwayFarm) !void {
    // Select account: pinned or auto
    const account = if (config.account > 0) blk: {
        for (farm.accounts[0..farm.account_count]) |*acct| {
            if (acct.id == config.account) break :blk acct;
        }
        print("{s}x Account {d} not found{s}\n", .{ RED, config.account, RESET });
        return error.ApiError;
    } else farm.selectAccount() orelse {
        print("{s}x All farm accounts exhausted -- no available slots{s}\n", .{ RED, RESET });
        return error.ApiError;
    };

    var api = farm.getApi(allocator, account.id) catch {
        print("{s}x Failed to init API for account {d}{s}\n", .{ RED, account.id, RESET });
        return error.ApiError;
    };
    defer api.deinit();

    // 1. Create service with repo source
    print("  {s}Creating service '{s}' + repo...{s}", .{ GRAY, config.name, RESET });
    const create_resp = api.createServiceWithRepo(config.name, "gHashTag/trinity", "main") catch {
        print(" {s}FAILED{s}\n", .{ RED, RESET });
        return error.ApiError;
    };
    defer allocator.free(create_resp);

    // Extract service ID
    const service_id = extractServiceId(create_resp) orelse {
        print(" {s}FAILED{s}\n", .{ RED, RESET });
        if (std.mem.indexOf(u8, create_resp, "\"message\":\"")) |msg_idx| {
            const msg_start = msg_idx + 11;
            if (std.mem.indexOfPos(u8, create_resp, msg_start, "\"")) |msg_end| {
                print("  {s}-> {s}{s}\n", .{ GRAY, create_resp[msg_start..msg_end], RESET });
            }
        }
        return error.ApiError;
    };
    print(" {s}OK{s} ({s})\n", .{ GREEN, RESET, service_id });

    // 3. Set environment variables
    setTrainEnvVars(&api, service_id, config);

    // 4. Set region
    setTrainRegion(&api, service_id);

    // 5. Track in farm
    trackTrainInFarm(config, account, farm, service_id);
}

/// tri cloud delete-service <service-id> [--account N]
pub fn cloudDeleteService(allocator: Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        print("{s}Usage: tri cloud delete-service <service-id> [--account N]{s}\n", .{ RED, RESET });
        return;
    }
    const service_id = args[0];
    var account_id: u8 = 0;
    if (args.len >= 3 and eql(u8, args[1], "--account")) {
        account_id = std.fmt.parseInt(u8, args[2], 10) catch 0;
    }

    var farm = railway_farm.RailwayFarm.init();
    var api = if (account_id > 0) farm.getApi(allocator, account_id) catch {
        print("{s}x Failed to init API for account {d}{s}\n", .{ RED, account_id, RESET });
        return;
    } else railway_api.RailwayApi.init(allocator) catch {
        print("{s}x Failed to init API{s}\n", .{ RED, RESET });
        return;
    };
    defer api.deinit();

    print("  {s}Deleting {s}...{s}", .{ GRAY, service_id, RESET });
    api.deleteService(service_id) catch {
        print(" {s}FAILED{s}\n", .{ RED, RESET });
        return;
    };
    print(" {s}OK{s}\n", .{ GREEN, RESET });
}

fn setTrainEnvVars(api: *railway_api.RailwayApi, service_id: []const u8, config: TrainConfig) void {
    print("  {s}Setting env vars...{s}", .{ GRAY, RESET });
    const env_id = api.environment_id;
    if (env_id.len == 0) {
        print(" {s}SKIP (no environment_id){s}\n", .{ YELLOW, RESET });
        return;
    }

    var fail_count: usize = 0;
    _ = api.upsertVariable(service_id, env_id, "RAILWAY_DOCKERFILE_PATH", "Dockerfile.hslm-train") catch {
        fail_count += 1;
    };
    _ = api.upsertVariable(service_id, env_id, "HSLM_OPTIMIZER", config.optimizer) catch {
        fail_count += 1;
    };
    _ = api.upsertVariable(service_id, env_id, "HSLM_LR", config.lr) catch {
        fail_count += 1;
    };

    var batch_buf: [16]u8 = undefined;
    const batch_str = std.fmt.bufPrint(&batch_buf, "{d}", .{config.batch}) catch "66";
    _ = api.upsertVariable(service_id, env_id, "HSLM_BATCH", batch_str) catch {
        fail_count += 1;
    };

    var ga_buf: [16]u8 = undefined;
    const ga_str = std.fmt.bufPrint(&ga_buf, "{d}", .{config.grad_accum}) catch "2";
    _ = api.upsertVariable(service_id, env_id, "HSLM_GRAD_ACCUM", ga_str) catch {
        fail_count += 1;
    };

    var seed_buf: [16]u8 = undefined;
    const seed_str = std.fmt.bufPrint(&seed_buf, "{d}", .{config.seed}) catch "42";
    _ = api.upsertVariable(service_id, env_id, "HSLM_SEED", seed_str) catch {
        fail_count += 1;
    };

    var steps_buf: [16]u8 = undefined;
    const steps_str = std.fmt.bufPrint(&steps_buf, "{d}", .{config.steps}) catch "100000";
    _ = api.upsertVariable(service_id, env_id, "HSLM_STEPS", steps_str) catch {
        fail_count += 1;
    };

    var ctx_buf: [16]u8 = undefined;
    const ctx_str = std.fmt.bufPrint(&ctx_buf, "{d}", .{config.context}) catch "24";
    _ = api.upsertVariable(service_id, env_id, "HSLM_CONTEXT", ctx_str) catch {
        fail_count += 1;
    };

    _ = api.upsertVariable(service_id, env_id, "HSLM_DROPOUT", config.dropout) catch {
        fail_count += 1;
    };
    _ = api.upsertVariable(service_id, env_id, "HSLM_WD", config.wd) catch {
        fail_count += 1;
    };
    _ = api.upsertVariable(service_id, env_id, "HSLM_LR_SCHEDULE", config.lr_schedule) catch {
        fail_count += 1;
    };

    if (config.restart_period > 0) {
        var rp_buf: [16]u8 = undefined;
        const rp_str = std.fmt.bufPrint(&rp_buf, "{d}", .{config.restart_period}) catch "0";
        _ = api.upsertVariable(service_id, env_id, "HSLM_RESTART_PERIOD", rp_str) catch {
            fail_count += 1;
        };
    }

    var workers_buf: [16]u8 = undefined;
    const workers_str = std.fmt.bufPrint(&workers_buf, "{d}", .{config.workers}) catch "6";
    _ = api.upsertVariable(service_id, env_id, "HSLM_WORKERS", workers_str) catch {
        fail_count += 1;
    };

    var ckpt_buf: [16]u8 = undefined;
    const ckpt_str = std.fmt.bufPrint(&ckpt_buf, "{d}", .{config.checkpoint_every}) catch "10000";
    _ = api.upsertVariable(service_id, env_id, "HSLM_CHECKPOINT_EVERY", ckpt_str) catch {
        fail_count += 1;
    };

    if (config.full_ternary) _ = api.upsertVariable(service_id, env_id, "HSLM_FULL_TERNARY", "1") catch {
        fail_count += 1;
    };
    if (config.ternary_schedule) _ = api.upsertVariable(service_id, env_id, "HSLM_TERNARY_SCHEDULE", "1") catch {
        fail_count += 1;
    };
    if (config.adaptive_sparsity) _ = api.upsertVariable(service_id, env_id, "HSLM_ADAPTIVE_SPARSITY", "1") catch {
        fail_count += 1;
    };
    if (config.phi_scale) _ = api.upsertVariable(service_id, env_id, "HSLM_PHI_SCALE", "1") catch {
        fail_count += 1;
    };

    if (fail_count > 0) {
        print(" {s}WARN ({d} vars failed){s}\n", .{ YELLOW, fail_count, RESET });
    } else {
        print(" {s}OK{s}\n", .{ GREEN, RESET });
    }
}

fn setTrainRegion(api: *railway_api.RailwayApi, service_id: []const u8) void {
    // Metal (us-west2) + Singapore (asia-southeast1) for speed
    print("  {s}Setting regions us-west2 + asia-southeast1...{s}", .{ GRAY, RESET });
    const gql = "mutation($serviceId: String!, $environmentId: String!, $input: ServiceInstanceUpdateInput!) { serviceInstanceUpdate(serviceId: $serviceId, environmentId: $environmentId, input: $input) }";
    const vars = std.fmt.allocPrint(api.allocator, "{{\"serviceId\":\"{s}\",\"environmentId\":\"{s}\",\"input\":{{\"multiRegionConfig\":{{\"us-west2\":{{\"numReplicas\":1}},\"asia-southeast1\":{{\"numReplicas\":1}}}}}}}}", .{
        service_id, api.environment_id,
    }) catch {
        print(" {s}SKIP{s}\n", .{ YELLOW, RESET });
        return;
    };
    defer api.allocator.free(vars);
    const region_resp = api.query(gql, vars) catch {
        print(" {s}SKIP{s}\n", .{ YELLOW, RESET });
        return;
    };
    api.allocator.free(region_resp);
    print(" {s}OK{s}\n", .{ GREEN, RESET });
}

fn trackTrainInFarm(config: TrainConfig, account: *railway_farm.RailwayAccount, farm: *railway_farm.RailwayFarm, service_id: []const u8) void {
    const name_hash = hashName(config.name);
    account.daily_creates += 1;
    account.active_services += 1;
    farm.recordAgent(name_hash, account.id, service_id);
    print("  {s}v {s} spawned on account {d} -- {s}{s}\n", .{ GREEN, config.name, account.id, service_id, RESET });
}

/// Hash experiment name to a u32 for farm tracking (pseudo-issue number).
fn hashName(name: []const u8) u32 {
    var h: u32 = 0x811c9dc5; // FNV-1a offset
    for (name) |c| {
        h ^= c;
        h *%= 0x01000193; // FNV-1a prime
    }
    // Use high range to avoid collision with real issue numbers
    return (h & 0x7FFFFFFF) | 0x40000000;
}

/// Extract "id" field from serviceCreate JSON response.
fn extractServiceId(json: []const u8) ?[]const u8 {
    const needle = "\"id\":\"";
    const idx = std.mem.indexOf(u8, json, needle) orelse return null;
    const start = idx + needle.len;
    const end_idx = std.mem.indexOfPos(u8, json, start, "\"") orelse return null;
    return json[start..end_idx];
}

/// tri cloud train <name> [--optimizer X] [--lr X] [--batch N] ...
pub fn cloudTrain(allocator: Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        print("{s}Usage: tri cloud train <name> [--optimizer adamw] [--lr 3e-4] [--batch 66] [--grad-accum 2] [--seed 42] [--steps 100000] [--context 24] [--dropout 0.1] [--wd 0.1] [--lr-schedule cosine] [--restart-period 33000] [--full-ternary] [--ternary-schedule] [--adaptive-sparsity] [--phi-scale]{s}\n", .{ RED, RESET });
        return;
    }

    var config = TrainConfig{ .name = args[0] };

    // Parse flags
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (eql(u8, arg, "--optimizer") and i + 1 < args.len) {
            i += 1;
            config.optimizer = args[i];
        } else if (eql(u8, arg, "--lr") and i + 1 < args.len) {
            i += 1;
            config.lr = args[i];
        } else if (eql(u8, arg, "--batch") and i + 1 < args.len) {
            i += 1;
            config.batch = std.fmt.parseInt(u32, args[i], 10) catch 66;
        } else if (eql(u8, arg, "--grad-accum") and i + 1 < args.len) {
            i += 1;
            config.grad_accum = std.fmt.parseInt(u32, args[i], 10) catch 2;
        } else if (eql(u8, arg, "--seed") and i + 1 < args.len) {
            i += 1;
            config.seed = std.fmt.parseInt(u32, args[i], 10) catch 42;
        } else if (eql(u8, arg, "--steps") and i + 1 < args.len) {
            i += 1;
            config.steps = std.fmt.parseInt(u32, args[i], 10) catch 100000;
        } else if (eql(u8, arg, "--context") and i + 1 < args.len) {
            i += 1;
            config.context = std.fmt.parseInt(u32, args[i], 10) catch 24;
        } else if (eql(u8, arg, "--dropout") and i + 1 < args.len) {
            i += 1;
            config.dropout = args[i];
        } else if (eql(u8, arg, "--lr-schedule") and i + 1 < args.len) {
            i += 1;
            config.lr_schedule = args[i];
        } else if (eql(u8, arg, "--restart-period") and i + 1 < args.len) {
            i += 1;
            config.restart_period = std.fmt.parseInt(u32, args[i], 10) catch 0;
        } else if (eql(u8, arg, "--full-ternary")) {
            config.full_ternary = true;
        } else if (eql(u8, arg, "--ternary-schedule")) {
            config.ternary_schedule = true;
        } else if (eql(u8, arg, "--adaptive-sparsity")) {
            config.adaptive_sparsity = true;
        } else if (eql(u8, arg, "--phi-scale")) {
            config.phi_scale = true;
        } else if ((eql(u8, arg, "--weight-decay") or eql(u8, arg, "--wd")) and i + 1 < args.len) {
            i += 1;
            config.wd = args[i];
        } else if (eql(u8, arg, "--workers") and i + 1 < args.len) {
            i += 1;
            config.workers = std.fmt.parseInt(u32, args[i], 10) catch 6;
        } else if (eql(u8, arg, "--checkpoint-every") and i + 1 < args.len) {
            i += 1;
            config.checkpoint_every = std.fmt.parseInt(u32, args[i], 10) catch 10000;
        } else if (eql(u8, arg, "--account") and i + 1 < args.len) {
            i += 1;
            config.account = std.fmt.parseInt(u8, args[i], 10) catch 0;
        }
    }

    print("\n{s}{s}=== HSLM TRAINING =============================================={s}\n", .{ GOLDEN, BOLD, RESET });
    print("{s}Experiment: {s}{s}\n", .{ CYAN, config.name, RESET });
    print("{s}  optimizer={s} lr={s} batch={d} ga={d} seed={d} steps={d}{s}\n", .{
        GRAY, config.optimizer, config.lr, config.batch, config.grad_accum, config.seed, config.steps, RESET,
    });

    var farm = railway_farm.RailwayFarm.init();
    if (farm.account_count == 0) {
        print("{s}x No Railway accounts configured{s}\n", .{ RED, RESET });
        return;
    }

    spawnTrainService(allocator, config, &farm) catch {};

    print("{s}================================================================={s}\n", .{ GOLDEN, RESET });
}

/// tri cloud train-batch -- Spawn 13 HSLM training experiments across 3 accounts
pub fn cloudTrainBatch(allocator: Allocator) !void {
    const experiments = [_]TrainConfig{
        // Account 1 (primary): R5, R6, R8, R9, T1
        .{ .name = "hslm-r5", .optimizer = "adam", .lr = "1e-3", .grad_accum = 4, .context = 27, .steps = 30000, .seed = 5, .account = 1 },
        .{ .name = "hslm-r6", .optimizer = "adam", .lr = "3e-4", .grad_accum = 2, .ternary_schedule = true, .steps = 99000, .seed = 6, .account = 1 },
        .{ .name = "hslm-r8", .optimizer = "adam", .lr = "6e-4", .grad_accum = 8, .seed = 8, .account = 1 },
        .{ .name = "hslm-r9", .optimizer = "adamw", .lr = "3e-4", .grad_accum = 2, .dropout = "0.15", .seed = 9, .account = 1 },
        .{ .name = "hslm-t1", .optimizer = "adam", .lr = "3e-4", .grad_accum = 2, .full_ternary = true, .seed = 11, .account = 1 },
        // Account 2 (farm-2): R10, R11, R12, R13
        .{ .name = "hslm-r10", .optimizer = "lamb", .lr = "3e-3", .grad_accum = 8, .seed = 10, .account = 2 },
        .{ .name = "hslm-r11", .optimizer = "adam", .lr = "3e-4", .grad_accum = 2, .lr_schedule = "cosine-restarts", .restart_period = 33000, .seed = 11, .account = 2 },
        .{ .name = "hslm-r12", .optimizer = "adam", .lr = "3e-4", .grad_accum = 2, .phi_scale = true, .seed = 12, .account = 2 },
        .{ .name = "hslm-r13", .optimizer = "lamb", .lr = "3e-3", .grad_accum = 4, .context = 27, .ternary_schedule = true, .steps = 30000, .seed = 13, .account = 2 },
        // Account 3 (farm-3): R14, R15, R16, R17
        .{ .name = "hslm-r14", .optimizer = "adam", .lr = "3e-4", .grad_accum = 2, .adaptive_sparsity = true, .seed = 14, .account = 3 },
        .{ .name = "hslm-r15", .optimizer = "lamb", .lr = "1e-3", .grad_accum = 4, .phi_scale = true, .adaptive_sparsity = true, .ternary_schedule = true, .seed = 15, .account = 3 },
        .{ .name = "hslm-r16", .optimizer = "adam", .lr = "5e-4", .grad_accum = 4, .seed = 16, .account = 3 },
        .{ .name = "hslm-r17", .optimizer = "adamw", .lr = "5e-4", .grad_accum = 4, .wd = "0.05", .seed = 17, .account = 3 },
    };

    print("\n{s}{s}=== HSLM TRAIN BATCH ==========================================={s}\n", .{ GOLDEN, BOLD, RESET });
    print("{s}Spawning {d} experiments across Railway farm...{s}\n\n", .{ CYAN, experiments.len, RESET });

    var farm = railway_farm.RailwayFarm.init();
    if (farm.account_count == 0) {
        print("{s}x No Railway accounts configured{s}\n", .{ RED, RESET });
        return;
    }

    var spawned: u32 = 0;
    var failed: u32 = 0;

    for (experiments, 0..) |config, idx| {
        print("{s}[{d}/{d}] {s}{s}\n", .{ BOLD, idx + 1, experiments.len, config.name, RESET });
        spawnTrainService(allocator, config, &farm) catch {
            failed += 1;
            continue;
        };
        spawned += 1;

        // Rate limit: 2s between spawns
        if (idx + 1 < experiments.len) {
            std.posix.nanosleep(2, 0);
        }
    }

    print("\n{s}=== BATCH SUMMARY =============================================={s}\n", .{ GOLDEN, RESET });
    print("  {s}v Spawned: {d}{s}\n", .{ GREEN, spawned, RESET });
    if (failed > 0) print("  {s}x Failed:  {d}{s}\n", .{ RED, failed, RESET });
    print("  {s}Accounts: {d} | Farm slots used{s}\n", .{ GRAY, farm.account_count, RESET });
    print("{s}================================================================={s}\n", .{ GOLDEN, RESET });
}

/// Print training/farm usage help (called from tri_cloud.zig printUsage)
pub fn printTrainUsage() void {
    print("\n  {s}Multi-Account Farm:{s}\n", .{ BOLD, RESET });
    print("  {s}tri cloud farm{s}                Farm dashboard (all accounts + capacity)\n", .{ GREEN, RESET });
    print("  {s}tri cloud farm sync{s}           Refresh service counts from Railway APIs\n", .{ GREEN, RESET });
    print("  {s}tri cloud farm capacity{s}       JSON capacity output (for MCP/scripts)\n", .{ GREEN, RESET });
    print("  {s}tri cloud farm rebalance{s}      Migrate services between accounts\n", .{ GREEN, RESET });
    print("\n  {s}HSLM Training:{s}\n", .{ BOLD, RESET });
    print("  {s}tri cloud train <name> [opts]{s}  Spawn training service on farm\n", .{ GREEN, RESET });
    print("  {s}tri cloud train-batch{s}          Spawn all 13 training experiments\n", .{ GREEN, RESET });
}

test "cloud_train_config_defaults" {
    const config = TrainConfig{
        .name = "test-run",
    };
    try std.testing.expectEqualStrings("test-run", config.name);
    try std.testing.expectEqualStrings("adam", config.optimizer);
    try std.testing.expectEqualStrings("cosine", config.lr_schedule);
    try std.testing.expectEqual(@as(u32, 66), config.batch);
    try std.testing.expectEqual(@as(u32, 42), config.seed);
}
