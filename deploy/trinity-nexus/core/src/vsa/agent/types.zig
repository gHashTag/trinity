// 🤖 TRINITY v0.11.0: Suborbital Order
// Base types for Agentic layer

const std = @import("std");

pub const MAX_INPUT_SIZE: usize = 512;
pub const MAX_OUTPUT_SIZE: usize = 512;
pub const MAX_MODALITIES: usize = 5;

pub const JobPriority = enum(u8) {
    low = 0,
    normal = 1,
    high = 2,
    critical = 3,
};

pub const Modality = enum(u8) {
    text = 0,
    vision = 1,
    voice = 2,
    code = 3,
    tool = 4,

    pub fn name(self: Modality) []const u8 {
        return switch (self) {
            .text => "text",
            .vision => "vision",
            .voice => "voice",
            .code => "code",
            .tool => "tool",
        };
    }
};

pub const AgentRole = enum(u8) {
    coordinator,
    coder,
    researcher,
    planner,
    reviewer,
    writer,
    pub fn roleName(self: AgentRole) []const u8 {
        return @tagName(self);
    }
};

pub const GoalStatus = enum(u8) {
    pending,
    planning,
    executing,
    reviewing,
    completed,
    failed,
    pub fn isTerminal(self: GoalStatus) bool {
        return self == .completed or self == .failed;
    }
    pub fn name(self: GoalStatus) []const u8 {
        return @tagName(self);
    }
};

pub const SystemCapability = enum(u8) {
    vision_analyze,
    code_execute,
    text_process,
    orchestrate,
    memory_recall,
    reflect_learn,
    pub fn primaryModality(self: SystemCapability) Modality {
        return switch (self) {
            .vision_analyze => .vision,
            .code_execute => .code,
            else => .text,
        };
    }
    pub fn primaryRole(self: SystemCapability) AgentRole {
        return switch (self) {
            .vision_analyze => .researcher,
            .code_execute => .coder,
            else => .coordinator,
        };
    }
    pub fn name(self: SystemCapability) []const u8 {
        return @tagName(self);
    }
};

// φ² + 1/φ² = 3 | TRINITY
