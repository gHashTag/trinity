// Wave 9 deployment script - 48 Railway services with S3 MultiObj config
// Usage: deploy-wave9

const std = @import("std");

const Allocator = std.mem.Allocator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Read environment variables
    const pid1 = std.process.getEnvVarOwned(allocator, "RAILWAY_PROJECT_ID") catch "";
    defer allocator.free(pid1);
    const eid1 = std.process.getEnvVarOwned(allocator, "RAILWAY_ENVIRONMENT_ID") catch "";
    defer allocator.free(eid1);
    const tok1 = std.process.getEnvVarOwned(allocator, "RAILWAY_API_TOKEN") catch "";
    defer allocator.free(tok1);

    const pid2 = std.process.getEnvVarOwned(allocator, "RAILWAY_PROJECT_ID_2") catch "";
    defer allocator.free(pid2);
    const eid2 = std.process.getEnvVarOwned(allocator, "RAILWAY_ENVIRONMENT_ID_2") catch "";
    defer allocator.free(eid2);
    const tok2 = std.process.getEnvVarOwned(allocator, "RAILWAY_API_TOKEN_2") catch "";
    defer allocator.free(tok2);

    const pid3 = std.process.getEnvVarOwned(allocator, "RAILWAY_PROJECT_ID_3") catch "";
    defer allocator.free(pid3);
    const eid3 = std.process.getEnvVarOwned(allocator, "RAILWAY_ENVIRONMENT_ID_3") catch "";
    defer allocator.free(eid3);
    const tok3 = std.process.getEnvVarOwned(allocator, "RAILWAY_API_TOKEN_3") catch "";
    defer allocator.free(tok3);

    const pid8 = std.process.getEnvVarOwned(allocator, "RAILWAY_PROJECT_ID_8") catch "";
    defer allocator.free(pid8);
    const eid8 = std.process.getEnvVarOwned(allocator, "RAILWAY_ENVIRONMENT_ID_8") catch "";
    defer allocator.free(eid8);
    const tok8 = std.process.getEnvVarOwned(allocator, "RAILWAY_API_TOKEN_8") catch "";
    defer allocator.free(tok8);

    const pid9 = std.process.getEnvVarOwned(allocator, "RAILWAY_PROJECT_ID_9") catch "";
    defer allocator.free(pid9);
    const eid9 = std.process.getEnvVarOwned(allocator, "RAILWAY_ENVIRONMENT_ID_9") catch "";
    defer allocator.free(eid9);
    const tok9 = std.process.getEnvVarOwned(allocator, "RAILWAY_API_TOKEN_9") catch "";
    defer allocator.free(tok9);

    const pid10 = std.process.getEnvVarOwned(allocator, "RAILWAY_PROJECT_ID_10") catch "";
    defer allocator.free(pid10);
    const eid10 = std.process.getEnvVarOwned(allocator, "RAILWAY_ENVIRONMENT_ID_10") catch "";
    defer allocator.free(eid10);
    const tok10 = std.process.getEnvVarOwned(allocator, "RAILWAY_API_TOKEN_10") catch "";
    defer allocator.free(tok10);

    const pid11 = std.process.getEnvVarOwned(allocator, "RAILWAY_PROJECT_ID_11") catch "";
    defer allocator.free(pid11);
    const eid11 = std.process.getEnvVarOwned(allocator, "RAILWAY_ENVIRONMENT_ID_11") catch "";
    defer allocator.free(eid11);
    const tok11 = std.process.getEnvVarOwned(allocator, "RAILWAY_API_TOKEN_11") catch "";
    defer allocator.free(tok11);

    const pid12 = std.process.getEnvVarOwned(allocator, "RAILWAY_PROJECT_ID_12") catch "";
    defer allocator.free(pid12);
    const eid12 = std.process.getEnvVarOwned(allocator, "RAILWAY_ENVIRONMENT_ID_12") catch "";
    defer allocator.free(eid12);
    const tok12 = std.process.getEnvVarOwned(allocator, "RAILWAY_API_TOKEN_12") catch "";
    defer allocator.free(tok12);

    std.debug.print("🚀 Wave 9 Deployment - 48 Services\n", .{});
    std.debug.print("===================================\n\n", .{});

    var created_count: usize = 0;
    var failed_count: usize = 0;

    const accounts = [_]struct { name: []const u8, pid: []const u8, eid: []const u8, token: []const u8 }{
        .{ .name = "1", .pid = pid1, .eid = eid1, .token = tok1 },
        .{ .name = "2", .pid = pid2, .eid = eid2, .token = tok2 },
        .{ .name = "3", .pid = pid3, .eid = eid3, .token = tok3 },
        .{ .name = "8", .pid = pid8, .eid = eid8, .token = tok8 },
        .{ .name = "9", .pid = pid9, .eid = eid9, .token = tok9 },
        .{ .name = "10", .pid = pid10, .eid = eid10, .token = tok10 },
        .{ .name = "11", .pid = pid11, .eid = eid11, .token = tok11 },
        .{ .name = "12", .pid = pid12, .eid = eid12, .token = tok12 },
    };

    // Create 6 services per account
    for (accounts) |account| {
        if (account.pid.len == 0 or account.token.len == 0) {
            std.debug.print("⚠️ Skipping FARM-{s} - missing credentials\n\n", .{account.name});
            continue;
        }

        std.debug.print("📦 Processing FARM-{s}\n", .{account.name});
        std.debug.print("   Project: {s}...\n", .{account.pid[0..8]});

        var i: u8 = 1;
        while (i <= 6) : (i += 1) {
            const service_name = std.fmt.allocPrint(allocator, "hslm-w9-{s}-{d:0>2}", .{ account.name, i }) catch break;
            defer allocator.free(service_name);

            std.debug.print("   Creating {s}...\n", .{service_name});

            // Create service
            const service_id_result = createService(allocator, service_name, account.pid, account.token);
            if (service_id_result) |sid| {
                std.debug.print("      ✅ Created: {s}\n", .{sid});

                // Set environment variables
                const vars_ok = setVariables(allocator, sid, account.pid, account.eid, account.token);
                if (vars_ok) {
                    std.debug.print("      ✅ Variables set\n", .{});
                    created_count += 1;
                } else {
                    std.debug.print("      ⚠️ Variables failed (service created)\n", .{});
                    failed_count += 1;
                }
            } else |err| {
                std.debug.print("      ❌ Failed: {}\n", .{err});
                failed_count += 1;
            }

            // Rate limiting: sleep 200ms between requests
            std.Thread.sleep(200 * std.time.ns_per_ms);
        }

        std.debug.print("\n", .{});
    }

    std.debug.print("===================================\n", .{});
    std.debug.print("📊 Wave 9 Deployment Summary:\n", .{});
    std.debug.print("   ✅ Created: {d} services\n", .{created_count});
    std.debug.print("   ❌ Failed: {d} services\n", .{failed_count});
    std.debug.print("===================================\n", .{});
}

fn createService(allocator: Allocator, name: []const u8, project_id: []const u8, token: []const u8) !?[]const u8 {
    const query = try std.fmt.allocPrint(allocator,
        \\{{
        \\  "query": "mutation($input: ServiceCreateInput!) {{ serviceCreate(input: $input) {{ id name }} }}",
        \\  "variables": {{
        \\    "input": {{
        \\      "projectId": "{s}",
        \\      "name": "{s}"
        \\    }}
        \\  }}
        \\}}
    , .{ project_id, name });
    defer allocator.free(query);

    const auth_header = try std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{token});
    defer allocator.free(auth_header);

    const result = try execCurl(allocator, auth_header, query);
    defer allocator.free(result);

    // Check for errors
    if (std.mem.indexOf(u8, result, "\"errors\"")) |_| {
        return error.ServiceCreateFailed;
    }

    // Extract service ID from JSON response
    const id_prefix = "\"id\":\"";
    if (std.mem.indexOf(u8, result, id_prefix)) |idx| {
        const start = idx + id_prefix.len;
        if (std.mem.indexOfScalar(u8, result[start..], '\"')) |end_idx| {
            const sid = try allocator.dupe(u8, result[start .. start + end_idx]);
            return sid;
        }
    }

    return error.ServiceIdNotFound;
}

fn setVariables(allocator: Allocator, service_id: []const u8, project_id: []const u8, env_id: []const u8, token: []const u8) bool {
    if (env_id.len == 0) return false;

    const query = std.fmt.allocPrint(allocator,
        \\{{
        \\  "query": "mutation($projectId: String!, $environmentId: String!, $serviceId: String!, $input: VariableCollectionUpsertInput!) {{ variableCollectionUpsert(projectId: $projectId, environmentId: $environmentId, serviceId: $serviceId, input: $input) {{ id }} }}",
        \\  "variables": {{
        \\    "projectId": "{s}",
        \\    "environmentId": "{s}",
        \\    "serviceId": "{s}",
        \\    "input": {{
        \\      "HSLM_PROFILE": "s3-multiobj",
        \\      "HSLM_CTX": "81",
        \\      "HSLM_NTP_WEIGHT": "0.50",
        \\      "HSLM_JEPA_WEIGHT": "0.25",
        \\      "HSLM_NCA_WEIGHT": "0.25",
        \\      "HSLM_CRASH_TOLERANCE": "0.05",
        \\      "HSLM_WAVE": "9"
        \\    }}
        \\  }}
        \\}}
    , .{ project_id, env_id, service_id }) catch return false;
    defer if (query.len > 0) allocator.free(query);

    const auth_header = std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{token}) catch return false;
    defer if (auth_header.len > 0) allocator.free(auth_header);

    const result = execCurl(allocator, auth_header, query) catch return false;
    defer allocator.free(result);

    return std.mem.indexOf(u8, result, "\"errors\"") == null;
}

fn execCurl(allocator: Allocator, auth_header: []const u8, query: []const u8) ![]u8 {
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "curl",
            "-s",
            "-X",
            "POST",
            "-H",
            auth_header,
            "-H",
            "Content-Type: application/json",
            "-d",
            query,
            "https://railway.com/graphql/v2",
        },
    });
    defer allocator.free(result.stderr);

    switch (result.term) {
        .Exited => |code| {
            if (code != 0) return error.CurlFailed;
        },
        else => return error.CurlFailed,
    }

    // Return a copy of stdout (caller must free)
    return try allocator.dupe(u8, result.stdout);
}
