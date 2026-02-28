// ============================================================================
// Cycle 113 Self-Funding Engine - Demo/Example Usage
// ============================================================================
//
// This file demonstrates how to use the Self-Funding Engine
// with practical examples for revenue tracking, infrastructure payments,
// and financial autonomy assessment.
//
// ============================================================================

const std = @import("std");
const self_funding = @import("cycle113_self_funding.zig");

const Allocator = std.mem.Allocator;

/// Demo: Setting up basic funding sources
pub fn setupDemoFundingSources(allocator: Allocator) ![]self_funding.IncomeSource {
    const sources = [_]self_funding.IncomeSource{
        .{
            .id = "compute_rental_001",
            .name = "GPU Compute Rental",
            .source_type = .computing_services,
            .rate = 2.50, // $2.50 per hour
            .currency = "USD",
            .active = true,
            .last_earned = 0,
            .total_earned = 0.0,
            .phi_fee_multiplier = self_funding.PHI, // 1.618x multiplier
            .auto_renewal = true,
            .renewal_threshold = 100.0,
            .metadata = std.StringHashMap([]const u8).init(allocator),
        },
        .{
            .id = "storage_sharing_002",
            .name = "Decentralized Storage",
            .source_type = .storage_rental,
            .rate = 0.05, // $0.05 per GB per month
            .currency = "USD",
            .active = true,
            .last_earned = 0,
            .total_earned = 0.0,
            .phi_fee_multiplier = self_funding.PHI_SQUARED, // 2.618x multiplier
            .auto_renewal = true,
            .renewal_threshold = 50.0,
            .metadata = std.StringHashMap([]const u8).init(allocator),
        },
        .{
            .id = "inference_api_003",
            .name = "Model Inference API",
            .source_type = .model_inference,
            .rate = 0.10, // $0.10 per request
            .currency = "USD",
            .active = true,
            .last_earned = 0,
            .total_earned = 0.0,
            .phi_fee_multiplier = 1.382, // φ^2 - 1 (custom multiplier)
            .auto_renewal = false,
            .renewal_threshold = 0.0,
            .metadata = std.StringHashMap([]const u8).init(allocator),
        },
    };

    const duped = try allocator.alloc(self_funding.IncomeSource, sources.len);
    for (sources, 0..) |src, i| {
        duped[i] = src;
        // Duplicate name and ID for actual use
        duped[i].id = try allocator.dupe(u8, src.id);
        duped[i].name = try allocator.dupe(u8, src.name);
        duped[i].currency = try allocator.dupe(u8, src.currency);
    }

    return duped;
}

/// Demo: Setting up expense categories
pub fn setupDemoExpenses(allocator: Allocator) ![]self_funding.ExpenseCategory {
    const expenses = [_]self_funding.ExpenseCategory{
        .{
            .id = "server_hosting_001",
            .name = "Server Hosting",
            .category_type = .server_costs,
            .amount = 150.0,
            .currency = "USD",
            .frequency = .monthly,
            .recurring = true,
            .last_paid = 0,
            .next_due = std.time.timestamp() + 86400 * 30, // 30 days from now
            .priority = 10, // High priority
            .auto_pay = true,
            .payment_method = "crypto",
        },
        .{
            .id = "bandwidth_002",
            .name = "Bandwidth Costs",
            .category_type = .bandwidth,
            .amount = 50.0,
            .currency = "USD",
            .frequency = .monthly,
            .recurring = true,
            .last_paid = 0,
            .next_due = std.time.timestamp() + 86400 * 30,
            .priority = 8,
            .auto_pay = true,
            .payment_method = "crypto",
        },
        .{
            .id = "monitoring_003",
            .name = "Monitoring Service",
            .category_type = .monitoring,
            .amount = 25.0,
            .currency = "USD",
            .frequency = .monthly,
            .recurring = true,
            .last_paid = 0,
            .next_due = std.time.timestamp() + 86400 * 30,
            .priority = 6,
            .auto_pay = true,
            .payment_method = "crypto",
        },
    };

    const duped = try allocator.alloc(self_funding.ExpenseCategory, expenses.len);
    for (expenses, 0..) |exp, i| {
        duped[i] = exp;
        duped[i].id = try allocator.dupe(u8, exp.id);
        duped[i].name = try allocator.dupe(u8, exp.name);
        duped[i].currency = try allocator.dupe(u8, exp.currency);
        duped[i].payment_method = try allocator.dupe(u8, exp.payment_method);
    }

    return duped;
}

/// Demo: Main usage example
pub fn demo(allocator: Allocator) !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print("=== Cycle 113 Self-Funding Engine Demo ===\n\n", .{});

    // 1. Setup funding sources and expenses
    try stdout.print("1. Setting up funding sources...\n", .{});
    const sources = try setupDemoFundingSources(allocator);
    defer {
        for (sources) |src| {
            allocator.free(src.id);
            allocator.free(src.name);
            allocator.free(src.currency);
        }
        allocator.free(sources);
    }

    try stdout.print("   - Configured {d} income sources\n", .{sources.len});

    try stdout.print("\n2. Setting up expenses...\n", .{});
    const expenses = try setupDemoExpenses(allocator);
    defer {
        for (expenses) |exp| {
            allocator.free(exp.id);
            allocator.free(exp.name);
            allocator.free(exp.currency);
            allocator.free(exp.payment_method);
        }
        allocator.free(expenses);
    }

    try stdout.print("   - Configured {d} expense categories\n", .{expenses.len});

    // 2. Create sample revenue events
    try stdout.print("\n3. Simulating revenue events...\n", .{});
    const now = std.time.timestamp();

    var revenue_events = std.ArrayList(self_funding.RevenueEvent).init(allocator);
    defer revenue_events.deinit();

    // Simulate 10 hours of GPU compute rental
    for (0..10) |_| {
        try revenue_events.append(.{
            .source_id = "compute_rental_001",
            .amount = 2.50,
            .timestamp = now,
            .metadata = null,
        });
    }

    // Simulate 500 GB of storage rental
    try revenue_events.append(.{
        .source_id = "storage_sharing_002",
        .amount = 25.0, // 500 * 0.05
        .timestamp = now,
        .metadata = null,
    });

    try stdout.print("   - Generated {d} revenue events\n", .{revenue_events.items.len});

    // 3. Track revenue
    try stdout.print("\n4. Tracking revenue with φ-based fees...\n", .{});
    const tracker = try self_funding.trackRevenue(allocator, sources, revenue_events.items);
    defer {
        var iter = tracker.sources.iterator();
        while (iter.next()) |entry| {
            entry.key_ptr.deinit();
        }
        tracker.sources.deinit();
        tracker.renewal_queue.deinit();
    }

    try stdout.print("   - Base revenue: ${d:.2}\n", .{tracker.total_revenue});
    try stdout.print("   - φ-adjusted revenue: ${d:.2}\n", .{tracker.phi_adjusted_revenue});
    try stdout.print("   - Revenue boost: {d:.1}%\n", .{
        ((tracker.phi_adjusted_revenue - tracker.total_revenue) / tracker.total_revenue) * 100.0,
    });

    // 4. Setup budget state
    const budget = self_funding.BudgetState{
        .total_income = tracker.phi_adjusted_revenue,
        .total_expenses = 0.0,
        .net_balance = tracker.phi_adjusted_revenue,
        .currency = "USD",
        .reserve_ratio = 0.0,
        .operating_reserve = tracker.phi_adjusted_revenue * 0.5,
        .investment_pool = tracker.phi_adjusted_revenue * 0.3,
        .emergency_fund = tracker.phi_adjusted_revenue * 0.2,
        .timestamp = now,
        .health_status = .healthy,
        .autonomy_score = 0.0,
        .phi_balance_score = 0.95,
    };

    // 5. Calculate φ fee example
    try stdout.print("\n5. φ-fee calculation example...\n", .{});
    const fee_structure = self_funding.PhiFeeStructure{
        .base_fee = 100.0,
        .phi_multiplier = self_funding.PHI,
        .volume_discount_threshold = 1000.0,
        .volume_discount_rate = 0.1,
        .loyalty_multiplier = 1.05,
        .dynamic_pricing = false,
    };

    const fee_calc = try self_funding.calculatePhiFee(
        allocator,
        100.0,
        fee_structure,
        500.0, // Below threshold, no discount
        6, // 6 months loyalty
    );

    try stdout.print("   - Base amount: ${d:.2}\n", .{fee_calc.base_amount});
    try stdout.print("   - Final amount: ${d:.2}\n", .{fee_calc.final_amount});
    try stdout.print("   - Fee breakdown: {s}\n", .{fee_calc.breakdown});

    // 6. Assess autonomy
    try stdout.print("\n6. Assessing financial autonomy...\n", .{});
    const income_history = [_]f64{ 25.0, 30.0, 28.0, 35.0, 40.0 };
    const expense_history = [_]f64{ 20.0, 22.0, 21.0, 25.0, 24.0 };

    const assessment = self_funding.assessAutonomy(
        budget,
        &income_history,
        &expense_history,
    );

    try stdout.print("   - Autonomy score: {d:.1}%\n", .{assessment.score * 100.0});
    try stdout.print("   - Status: {s}\n", .{if (assessment.is_autonomous) "AUTONOMOUS" else "NOT AUTONOMOUS"});
    try stdout.print("   - Roadmap: {s}\n", .{assessment.roadmap});

    // 7. Check auto-renewal
    try stdout.print("\n7. Checking auto-renewal eligibility...\n", .{});
    const renewal_config = self_funding.AutoRenewalConfig{
        .enabled = true,
        .balance_threshold = 50.0,
        .renewal_interval_days = 30,
        .max_auto_renewal_amount = 200.0,
        .require_confirmation = false,
        .notification_pref = .all,
    };

    const renewal_check = try self_funding.checkAutoRenewal(
        allocator,
        sources[0], // compute_rental_001
        budget.operating_reserve,
        renewal_config,
    );

    try stdout.print("   - Should renew: {s}\n", .{if (renewal_check.should_renew) "YES" else "NO"});
    try stdout.print("   - Message: {s}\n", .{renewal_check.message});

    try stdout.print("\n=== Demo Complete ===\n", .{});
}
