// Railway bulk rename utility — renames hslm-* services to trinity-train-{N}
// Usage: railway-rename [--dry-run]

const std = @import("std");

const Allocator = std.mem.Allocator;

const RAILWAY_GQL_HOST = "backboard.railway.com";
const RAILWAY_GQL_PATH = "/graphql/v2";

const RESET = "\x1b[0m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const GRAY = "\x1b[90m";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len > 1 and std.mem.eql(u8, args[1], "--help")) {
        std.debug.print(
            \\Railway Bulk Rename — rename hslm-* services to trinity-train-{{N}}
            \\
            \\Usage: railway-rename [--dry-run] [--help]
            \\
            \\Options:
            \\  --dry-run    Show changes without applying them
            \\  --help       Show this help message
            \\
            \\Environment (from .env):
            \\  RAILWAY_API_TOKEN     Railway API token
            \\  RAILWAY_PROJECT_ID    Project ID
            \\
            \\Example:
            \\  export $(cat .env | xargs)  # or set -a && source .env && set +a
            \\  railway-rename --dry-run    # Preview changes
            \\  railway-rename              # Apply changes
            \\
        , .{});
        return;
    }

    const dry_run = if (args.len > 1 and std.mem.eql(u8, args[1], "--dry-run")) true else false;

    // Load RAILWAY_TOKEN from .env
    const token = std.process.getEnvVarOwned(allocator, "RAILWAY_API_TOKEN") catch {
        std.debug.print("{s}Error{s}: RAILWAY_API_TOKEN not found in environment\n", .{ YELLOW, RESET });
        std.debug.print("{s}Hint{s}: Run 'export $(cat .env | xargs)' or 'set -a && source .env && set +a'\n", .{ GRAY, RESET });
        std.debug.print("Or run with --help for more info.\n", .{});
        std.process.exit(1);
    };
    defer allocator.free(token);

    const project_id = std.process.getEnvVarOwned(allocator, "RAILWAY_PROJECT_ID") catch {
        std.debug.print("{s}Error{s}: RAILWAY_PROJECT_ID not found in environment\n", .{ YELLOW, RESET });
        std.debug.print("{s}Hint{s}: Run 'export $(cat .env | xargs)' or 'set -a && source .env && set +a'\n", .{ GRAY, RESET });
        std.process.exit(1);
    };
    defer allocator.free(project_id);

    std.debug.print("{s}Scanning project {s} for hslm-* services...{s}\n\n", .{ GRAY, project_id, RESET });

    // Fetch all services in the project
    var services = try fetchServices(allocator, token, project_id);
    defer {
        for (services.items) |s| {
            allocator.free(s.id);
            allocator.free(s.name);
        }
        services.deinit(allocator);
    }

    // Filter and rename hslm-* services
    var rename_count: usize = 0;
    for (services.items) |service| {
        if (std.mem.startsWith(u8, service.name, "hslm-")) {
            // Extract number from hslm-XXX pattern (e.g., hslm-v11 -> 11)
            const num_str = extractNumber(service.name) orelse continue;
            const new_name = try std.fmt.allocPrint(allocator, "trinity-train-{s}", .{num_str});
            defer allocator.free(new_name);

            std.debug.print("{s}{s}{s} -> {s}{s}{s}\n", .{ CYAN, service.name, RESET, GREEN, new_name, RESET });

            if (!dry_run) {
                const result = renameService(allocator, token, service.id, new_name) catch |err| {
                    std.debug.print("  {s}Error: {}{s}\n", .{ YELLOW, err, RESET });
                    continue;
                };
                defer allocator.free(result);
                std.debug.print("  {s}Renamed!{s}\n", .{ GREEN, RESET });
            } else {
                std.debug.print("  {s}[DRY RUN]{s}\n", .{ YELLOW, RESET });
            }
            rename_count += 1;
        }
    }

    std.debug.print("\n{s}Found {d} service(s) to rename{s}\n", .{ GREEN, rename_count, RESET });
    if (dry_run) {
        std.debug.print("{s}Run without --dry-run to apply changes{s}\n", .{ YELLOW, RESET });
    }
}

const Service = struct {
    id: []const u8,
    name: []const u8,
};

fn fetchServices(allocator: Allocator, token: []const u8, project_id: []const u8) !std.ArrayListUnmanaged(Service) {
    const gql =
        \\query($projectId: String!) {
        \\  project(projectId: $projectId) {
        \\    services {
        \\      edges {
        \\        node {
        \\          id
        \\          name
        \\        }
        \\      }
        \\    }
        \\  }
        \\}
    ;

    const vars = try std.fmt.allocPrint(allocator, "{{\"projectId\":\"{s}\"}}", .{project_id});
    defer allocator.free(vars);

    const response = try executeGraphql(allocator, token, gql, vars);

    // Parse JSON response manually (simplified)
    var services = std.ArrayListUnmanaged(Service){};
    try services.ensureTotalCapacity(allocator, 32);

    var it = std.mem.splitScalar(u8, response, '"');
    var state: enum { Start, Id, Name } = .Start;
    var current_id: ?[]const u8 = null;
    var current_name: ?[]const u8 = null;

    while (it.next()) |part| {
        if (state == .Start and std.mem.eql(u8, part, "id")) {
            state = .Id;
        } else if (state == .Id) {
            current_id = try allocator.dupe(u8, part);
            state = .Name;
        } else if (state == .Name) {
            if (std.mem.eql(u8, part, "name") or std.mem.eql(u8, part, "id")) {
                // Found "name" or "id" again, save previous
                if (current_id) |id| {
                    if (current_name) |name| {
                        try services.append(allocator, .{ .id = id, .name = name });
                        current_name = null;
                    }
                    current_id = null;
                    if (std.mem.eql(u8, part, "name")) {
                        state = .Id;
                    } else {
                        state = .Start;
                    }
                }
            } else {
                current_name = try allocator.dupe(u8, part);
                state = .Start;
            }
        }
    }

    // Handle last service
    if (current_id) |id| {
        if (current_name) |name| {
            try services.append(allocator, .{ .id = id, .name = name });
        }
    }

    allocator.free(response);
    return services;
}

fn extractNumber(name: []const u8) ?[]const u8 {
    // hslm-v11 -> v11, hslm-r5 -> r5
    if (std.mem.indexOf(u8, name, "-")) |idx| {
        return name[idx + 1 ..];
    }
    return null;
}

fn renameService(allocator: Allocator, token: []const u8, service_id: []const u8, new_name: []const u8) ![]const u8 {
    const gql =
        \\mutation($id: String!, $input: ServiceUpdateInput!) {
        \\  serviceUpdate(id: $id, input: $input) {
        \\    id
        \\    name
        \\  }
        \\}
    ;

    const vars = try std.fmt.allocPrint(allocator,
        \\{{"id":"{s}","input":{{"name":"{s}"}}}}
    , .{ service_id, new_name });
    defer allocator.free(vars);

    return executeGraphql(allocator, token, gql, vars);
}

fn executeGraphql(allocator: Allocator, token: []const u8, gql: []const u8, vars: []const u8) ![]const u8 {
    // Use curl via std.process.Child (same as other railway CLI tools)
    const body = try std.fmt.allocPrint(allocator,
        \\{{"query":"{s}","variables":{s}}}
    , .{ gql, vars });
    defer allocator.free(body);

    const auth_header = try std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{token});
    defer allocator.free(auth_header);

    const url = try std.fmt.allocPrint(allocator, "https://{s}{s}", .{ RAILWAY_GQL_HOST, RAILWAY_GQL_PATH });
    defer allocator.free(url);

    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "curl", "-s",        "-X", "POST",
            "-H",   auth_header, "-H", "Content-Type: application/json",
            "-d",   body,        url,
        },
    });
    defer {
        allocator.free(result.stderr);
        allocator.free(result.stdout);
    }

    if (result.term.Exited != 0) return error.RequestFailed;

    // Check for errors
    if (std.mem.indexOf(u8, result.stdout, "\"errors\"")) |_| {
        std.debug.print("GraphQL error: {s}\n", .{result.stdout});
        return error.ApiError;
    }

    return allocator.dupe(u8, result.stdout);
}
