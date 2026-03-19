// @origin(manual) @regen(manual-impl)
// Temp patch file for governance.zig deinit fix

pub fn deinit(self: *GovernanceManager) void {
    var iter = self.appeals.iterator();
    while (iter.next()) |entry| {
        const appeal = entry.value_ptr;
        self.allocator.free(appeal.appeal_id);
        // Don't free original_violation - it's a copy of duped_violation (deep copy by HashMap)
        // The actual string is freed when appeals hashmap deinits
        // self.allocator.free(appeal.original_violation);
        self.allocator.free(appeal.appeal_reason);
        for (appeal.evidence_urls.items) |*url| {
            self.allocator.free(url.*);
        }
        appeal.evidence_urls.deinit(self.allocator);
    }
    self.appeals.deinit(self.allocator);
}
