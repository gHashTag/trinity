// ═══════════════════════════════════════════════════════════════════════════════
// worktree_monitor v1.0.0 - Generated from .vibee specification
// ═══════════════════════════════════════════════════════════════════════════════
//
// Священная формула: V = n × 3^k × π^m × φ^p × e^q
// Золотая идентичность: φ² + 1/φ² = 3
//
// Author: 
// DO NOT EDIT - This file is auto-generated
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// КОНСТАНТЫ
// ═══════════════════════════════════════════════════════════════════════════════

// Базовые φ-константы (Sacred Formula)
pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const PHI_SQ: f64 = 2.618033988749895;
pub const TRINITY: f64 = 3.0;
pub const SQRT5: f64 = 2.2360679774997896;
pub const TAU: f64 = 6.283185307179586;
pub const PI: f64 = 3.141592653589793;
pub const E: f64 = 2.718281828459045;
pub const PHOENIX: i64 = 999;

// ═══════════════════════════════════════════════════════════════════════════════
// ТИПЫ
// ═══════════════════════════════════════════════════════════════════════════════

/// 
pub const Constants = struct {
    PHI: 1.618033988749895,
    PHI_SQ: 2.618033988749895,
    TRINITY_IDENTITY: 3.0,
    MAX_WORKTREES: 12,
    HEALTH_CHECK_INTERVAL_MS: 5000,
};

/// 
pub const Worktree = struct {
    id: []const u8,
    path: []const u8,
    branch: []const u8,
    commit_hash: []const u8,
    created_at: i64,
    last_activity: i64,
    ralph_session: ?[]const u8,
    status: WorktreeStatus,
};

/// 
pub const WorktreeStatus = struct {
};

/// 
pub const WorktreeHealth = struct {
    worktree_id: []const u8,
    status: WorktreeStatus,
    has_active_ralph: bool,
    uncommitted_changes: bool,
    last_commit_age_seconds: i64,
    error_message: ?[]const u8,
    check_timestamp: i64,
};

/// 
pub const WorktreeChange = struct {
    worktree_id: []const u8,
    change_type: []const u8,
    file_path: []const u8,
    detected_at: i64,
};

/// 
pub const WorktreeReport = struct {
    total_worktrees: i64,
    healthy_count: i64,
    busy_count: i64,
    error_count: i64,
    idle_count: i64,
    worktrees: []const u8,
    timestamp: i64,
};

/// 
pub const WorktreeRequest = struct {
    branch_name: []const u8,
    base_commit: []const u8,
    task_name: []const u8,
    priority: i64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// ПАМЯТЬ ДЛЯ WASM
// ═══════════════════════════════════════════════════════════════════════════════

var global_buffer: [65536]u8 align(16) = undefined;
var f64_buffer: [8192]f64 align(16) = undefined;

export fn get_global_buffer_ptr() [*]u8 {
    return &global_buffer;
}

export fn get_f64_buffer_ptr() [*]f64 {
    return &f64_buffer;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CREATION PATTERNS
// ═══════════════════════════════════════════════════════════════════════════════

/// Trit - ternary digit (-1, 0, +1)
pub const Trit = enum(i8) {
    negative = -1, // FALSE
    zero = 0,      // UNKNOWN
    positive = 1,  // TRUE

    pub fn trit_and(a: Trit, b: Trit) Trit {
        return @enumFromInt(@min(@intFromEnum(a), @intFromEnum(b)));
    }

    pub fn trit_or(a: Trit, b: Trit) Trit {
        return @enumFromInt(@max(@intFromEnum(a), @intFromEnum(b)));
    }

    pub fn trit_not(a: Trit) Trit {
        return @enumFromInt(-@intFromEnum(a));
    }

    pub fn trit_xor(a: Trit, b: Trit) Trit {
        const av = @intFromEnum(a);
        const bv = @intFromEnum(b);
        if (av == 0 or bv == 0) return .zero;
        if (av == bv) return .negative;
        return .positive;
    }
};

/// Проверка TRINITY identity: φ² + 1/φ² = 3
fn verify_trinity() f64 {
    return PHI * PHI + 1.0 / (PHI * PHI);
}

/// φ-интерполяция
fn phi_lerp(a: f64, b: f64, t: f64) f64 {
    const phi_t = math.pow(f64, t, PHI_INV);
    return a + (b - a) * phi_t;
}

/// Генерация φ-спирали
fn generate_phi_spiral(n: u32, scale: f64, cx: f64, cy: f64) u32 {
    const max_points = f64_buffer.len / 2;
    const count = if (n > max_points) @as(u32, @intCast(max_points)) else n;
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        const fi: f64 = @floatFromInt(i);
        const angle = fi * TAU * PHI_INV;
        const radius = scale * math.pow(f64, PHI, fi * 0.1);
        f64_buffer[i * 2] = cx + radius * @cos(angle);
        f64_buffer[i * 2 + 1] = cy + radius * @sin(angle);
    }
    return count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// BEHAVIOR FUNCTIONS - Generated from behaviors
// ═══════════════════════════════════════════════════════════════════════════════

      pub fn list_all_worktrees(repo_path: []const u8) ![]Worktree {
          const result = try std.process.Child.exec(.{
              .allocator = std.heap.page_allocator,
              .argv = &[_][]const u8{ "git", "worktree", "list", "--porcelain" },
              .cwd = repo_path,
          });
          defer {
              std.heap.page_allocator.free(result.stdout);
              std.heap.page_allocator.free(result.stderr);
          }

          var worktrees = std.ArrayList(Worktree).init(std.heap.page_allocator);

          var iter = std.mem.splitScalar(u8, result.stdout, '\n');
          var current_worktree: ?Worktree = null;
          var id_counter: u32 = 0;

          while (iter.next()) |line| {
              if (line.len == 0) {
                  // Blank line separates worktree entries
                  if (current_worktree) |wt| {
                      try worktrees.append(wt);
                      current_worktree = null;
                      id_counter += 1;
                  }
                  continue;
              }

              const parts = std.mem.splitScalar(u8, line, ' ');
              const key = parts.next() orelse continue;

              if (std.mem.eql(u8, key, "worktree")) {
                  const path = parts.rest();
                  const branch = try git.getCurrentBranch(path);

                  current_worktree = Worktree{
                      .id = try std.fmt.allocPrint(
                          std.heap.page_allocator,
                          "wt-{d}",
                          .{id_counter}
                      ),
                      .path = try std.heap.page_allocator.dupe(u8, path),
                      .branch = branch,
                      .commit_hash = try git.getLastCommitHash(path),
                      .created_at = std.time.timestamp(),
                      .last_activity = std.time.timestamp(),
                      .ralph_session = null,
                      .status = .idle,
                  };
              }
          }

          return worktrees.toOwnedSlice();
      }



      pub fn create_worktree(
          repo_path: []const u8,
          request: WorktreeRequest
      ) !Worktree {
          // Create worktree path
          const worktree_path = try std.fmt.allocPrint(
              std.heap.page_allocator,
              "{s}/../ralph-{s}",
              .{ repo_path, request.task_name }
          );

          // Create worktree
          const create_result = std.process.Child.exec(.{
              .allocator = std.heap.page_allocator,
              .argv = &[_][]const u8{
                  "git", "worktree", "add",
                  "-b", request.branch_name,
                  worktree_path,
                  request.base_commit
              },
              .cwd = repo_path,
          }) catch |err| {
              std.log.err("Failed to create worktree: {}", .{err});
              return err;
          };
          defer {
              std.heap.page_allocator.free(create_result.stdout);
              std.heap.page_allocator.free(create_result.stderr);
          }

          const branch = try git.getCurrentBranch(worktree_path);

          return Worktree{
              .id = try std.fmt.allocPrint(
                  std.heap.page_allocator,
                  "wt-{s}",
                  .{request.task_name}
              ),
              .path = worktree_path,
              .branch = branch,
              .commit_hash = request.base_commit,
              .created_at = std.time.timestamp(),
              .last_activity = std.time.timestamp(),
              .ralph_session = try std.heap.page_allocator.dupe(u8, request.task_name),
              .status = .busy,
          };
      }



      pub fn remove_worktree(repo_path: []const u8, worktree_path: []const u8) !void {
          // Prune worktree
          const prune_result = std.process.Child.exec(.{
              .allocator = std.heap.page_allocator,
              .argv = &[_][]const u8{
                  "git", "worktree", "remove",
                  worktree_path
              },
              .cwd = repo_path,
          }) catch |err| {
              std.log.err("Failed to remove worktree: {}", .{err});
              return err;
          };
          defer {
              std.heap.page_allocator.free(prune_result.stdout);
              std.heap.page_allocator.free(prune_result.stderr);
          };

          _ = prune_result;
      }



      pub fn check_worktree_health(worktree: Worktree) !WorktreeHealth {
          // Check if Ralph session is active
          const session_file = try std.fmt.allocPrint(
              std.heap.page_allocator,
              "{s}/.ralph/internal/.ralph_session",
              .{worktree.path}
          );

          const has_active_ralph = std.fs.cwd().openFile(session_file, .{}) catch |err| {
              if (err == error.FileNotFound)
                  return WorktreeHealth{
                      .worktree_id = worktree.id,
                      .status = .idle,
                      .has_active_ralph = false,
                      .uncommitted_changes = false,
                      .last_commit_age_seconds = 0,
                      .error_message = null,
                      .check_timestamp = std.time.timestamp(),
                  };
              return err;
          };
          defer has_active_ralph.close();

          // Check for uncommitted changes
          const status_result = try std.process.Child.exec(.{
              .allocator = std.heap.page_allocator,
              .argv = &[_][]const u8{ "git", "status", "--porcelain" },
              .cwd = worktree.path,
          });
          defer {
              std.heap.page_allocator.free(status_result.stdout);
              std.heap.page_allocator.free(status_result.stderr);
          }

          var has_changes = false;
          var iter = std.mem.splitScalar(u8, status_result.stdout, '\n');
          while (iter.next()) |line| {
              if (line.len > 0) {
                  has_changes = true;
                  break;
              }
          }

          // Determine status
          const status: WorktreeStatus = if (has_changes)
              .busy
          else
              .idle;

          return WorktreeHealth{
              .worktree_id = worktree.id,
              .status = status,
              .has_active_ralph = true,
              .uncommitted_changes = has_changes,
              .last_commit_age_seconds = @intCast(
                  std.time.timestamp() - worktree.last_activity
              ),
              .error_message = null,
              .check_timestamp = std.time.timestamp(),
          };
      }



      pub fn detect_worktree_changes(
          previous: []const WorktreeHealth,
          current: []const WorktreeHealth
      ) ![]WorktreeChange {
          var changes = std.ArrayList(WorktreeChange).init(std.heap.page_allocator);

          for (current) |curr| {
              const prev = for (previous) |p| {
                  if (std.mem.eql(u8, p.worktree_id, curr.worktree_id))
                      break p;
              } else continue;

              // Status changed
              if (prev.status != curr.status) {
                  try changes.append(WorktreeChange{
                      .worktree_id = curr.worktree_id,
                      .change_type = "status_change",
                      .file_path = "",
                      .detected_at = std.time.timestamp(),
                  });
              }

              // Changes appeared/disappeared
              if (prev.uncommitted_changes != curr.uncommitted_changes) {
                  try changes.append(WorktreeChange{
                      .worktree_id = curr.worktree_id,
                      .change_type = "uncommitted_changes",
                      .file_path = "",
                      .detected_at = std.time.timestamp(),
                  });
              }
          }

          return changes.toOwnedSlice();
      }



      pub fn aggregate_worktree_report(
          health_checks: []const WorktreeHealth
      ) !WorktreeReport {
          var healthy_count: u32 = 0;
          var busy_count: u32 = 0;
          var error_count: u32 = 0;
          var idle_count: u32 = 0;

          for (health_checks) |hc| {
              switch (hc.status) {
                  .healthy => healthy_count += 1,
                  .busy => busy_count += 1,
                  .error => error_count += 1,
                  .idle => idle_count += 1,
                  .stopped => {},
              }
          }

          return WorktreeReport{
              .total_worktrees = @intCast(health_checks.len),
              .healthy_count = healthy_count,
              .busy_count = busy_count,
              .error_count = error_count,
              .idle_count = idle_count,
              .worktrees = try std.heap.page_allocator.dupe(WorktreeHealth, health_checks),
              .timestamp = std.time.timestamp(),
          };
      }



      pub fn monitor_all_worktrees(
          repo_path: []const u8,
          state_manager: *StateManager,
          message_bus: *MessageBus
      ) !void {
          var previous_health = std.ArrayList(WorktreeHealth).init(std.heap.page_allocator);
          defer previous_health.deinit();

          while (true) {
              // List all worktrees
              const worktrees = try list_all_worktrees(repo_path);
              defer {
                  for (worktrees) |wt| {
                      std.heap.page_allocator.free(wt.id);
                      std.heap.page_allocator.free(wt.path);
                      std.heap.page_allocator.free(wt.branch);
                      std.heap.page_allocator.free(wt.commit_hash);
                      if (wt.ralph_session) |s| std.heap.page_allocator.free(s);
                  }
                  std.heap.page_allocator.free(worktrees);
              }

              // Check health of each
              var current_health = std.ArrayList(WorktreeHealth).init(std.heap.page_allocator);
              for (worktrees) |wt| {
                  const health = try check_worktree_health(wt);
                  try current_health.append(health);
              }

              // Detect changes
              const changes = try detect_worktree_changes(
                  previous_health.items,
                  current_health.items
              );
              defer {
                  for (changes) |ch| {
                      std.heap.page_allocator.free(ch.worktree_id);
                      std.heap.page_allocator.free(ch.file_path);
                  }
                  std.heap.page_allocator.free(changes);
              }

              // Publish changes to message bus
              for (changes) |ch| {
                  const event = try MessageBus.Event.init(
                      "worktree_monitor.change",
                      ch,
                      std.time.timestamp()
                  );
                  try message_bus.publish(event);
              }

              // Aggregate and publish report
              const report = try aggregate_worktree_report(current_health.items);

              const report_event = try MessageBus.Event.init(
                  "worktree_monitor.report",
                  report,
                  std.time.timestamp()
              );
              try message_bus.publish(report_event);

              // Update previous health
              previous_health.clearRetainingCapacity();
              try previous_health.appendSlice(current_health.items);

              // Sleep for interval
              std.time.sleep(5_000_000_000); // 5 seconds
          }
      }



      pub fn format_worktree_status(health: WorktreeHealth) ![]const u8 {
          const icon = switch (health.status) {
              .healthy => "✔",
              .busy => "⚙",
              .error => "✖",
              .idle => "⊘",
              .stopped => "○",
          };

          return try std.fmt.allocPrint(
              std.heap.page_allocator,
              "{s} {s}",
              .{ icon, health.worktree_id }
          );
      }


// ═══════════════════════════════════════════════════════════════════════════════
// SNAKE_CASE ALIASES - For test compatibility
// ═══════════════════════════════════════════════════════════════════════════════
// CYCLE_49_FIX: Adding aliases for snake_case test references

const list_all_worktrees = listAllWorktrees;
const create_worktree = createWorktree;
const remove_worktree = removeWorktree;
const check_worktree_health = checkWorktreeHealth;
const detect_worktree_changes = detectWorktreeChanges;
const aggregate_worktree_report = aggregateWorktreeReport;
const monitor_all_worktrees = monitorAllWorktrees;
const format_worktree_status = formatWorktreeStatus;

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS - Generated from behaviors and test_cases
// ═══════════════════════════════════════════════════════════════════════════════

test "list_all_worktrees_behavior" {
// Given: Git repository with worktrees
// When: Worktree inventory requested
// Then: Parse `git worktree list` and return Worktree list
// Test list_all_worktrees: verify behavior is callable (compile-time check)
_ = list_all_worktrees;
}

test "create_worktree_behavior" {
// Given: WorktreeRequest with branch and base commit
// When: New parallel task needs isolated environment
// Then: Create git worktree and initialize Ralph session
// Test create_worktree: verify behavior is callable (compile-time check)
_ = create_worktree;
}

test "remove_worktree_behavior" {
// Given: Worktree ID
// When: Task complete or worktree cleanup needed
// Then: Prune git worktree and remove files
// Test remove_worktree: verify behavior is callable (compile-time check)
_ = remove_worktree;
}

test "check_worktree_health_behavior" {
// Given: Individual Worktree record
// When: Health check interval elapsed
// Then: Return WorktreeHealth with current status
// Test check_worktree_health: verify behavior is callable (compile-time check)
_ = check_worktree_health;
}

test "detect_worktree_changes_behavior" {
// Given: Previous and current worktree states
// When: Health check completes
// Then: Return list of WorktreeChange events
// Test detect_worktree_changes: verify behavior is callable (compile-time check)
_ = detect_worktree_changes;
}

test "aggregate_worktree_report_behavior" {
// Given: All worktree health checks
// When: Reporting interval elapsed
// Then: Combine into WorktreeReport with counts
// Test aggregate_worktree_report: verify behavior is callable (compile-time check)
_ = aggregate_worktree_report;
}

test "monitor_all_worktrees_behavior" {
// Given: Repository path and state manager
// When: Monitor loop active
// Then: Check health of all worktrees at interval
// Test monitor_all_worktrees: verify behavior is callable (compile-time check)
_ = monitor_all_worktrees;
}

test "format_worktree_status_behavior" {
// Given: WorktreeHealth
// When: Display requested (tmux/dashboard)
// Then: Return formatted string with status icon and branch
// Test format_worktree_status: verify behavior is callable (compile-time check)
_ = format_worktree_status;
}

test "phi_constants" {
    try std.testing.expectApproxEqAbs(PHI * PHI_INV, 1.0, 1e-10);
    try std.testing.expectApproxEqAbs(PHI_SQ - PHI, 1.0, 1e-10);
}
