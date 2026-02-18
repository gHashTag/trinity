// 🤖 TRINITY v0.11.0: Suborbital Order
// Multi-modal Agent and Memory layer for VSA (Facade)

const std = @import("std");

pub const types = @import("agent/types.zig");
pub const memory = @import("agent/memory.zig");
pub const unified = @import("agent/unified.zig");
pub const autonomous = @import("agent/autonomous.zig");
pub const system = @import("agent/system.zig");

// Re-exports from types
pub const MAX_INPUT_SIZE = types.MAX_INPUT_SIZE;
pub const MAX_OUTPUT_SIZE = types.MAX_OUTPUT_SIZE;
pub const MAX_MODALITIES = types.MAX_MODALITIES;
pub const JobPriority = types.JobPriority;
pub const Modality = types.Modality;
pub const AgentRole = types.AgentRole;
pub const GoalStatus = types.GoalStatus;
pub const SystemCapability = types.SystemCapability;

// Re-exports from memory
pub const MemoryEntry = memory.MemoryEntry;
pub const ContextWindow = memory.ContextWindow;
pub const AgentMemory = memory.AgentMemory;

// Re-exports from unified
pub const ModalInput = unified.ModalInput;
pub const ModalResult = unified.ModalResult;
pub const MultiModalToolStats = unified.MultiModalToolStats;
pub const MultiModalToolUse = unified.MultiModalToolUse;
pub const Orchestrator = unified.Orchestrator;
pub const UnifiedAgent = unified.UnifiedAgent;
pub const ModalityRouter = unified.ModalityRouter;

// Re-exports from autonomous
pub const SubGoal = autonomous.SubGoal;
pub const AutonomousPlan = autonomous.AutonomousPlan;
pub const AutonomousAgent = autonomous.AutonomousAgent;
pub const AutonomousResult = autonomous.AutonomousResult;
pub const AutonomousStats = autonomous.AutonomousStats;

// Re-exports from system
pub const ReflectionType = system.ReflectionType;
pub const ReflectorStats = system.ReflectorStats;
pub const SelfReflector = system.SelfReflector;
pub const ImprovementResult = system.ImprovementResult;
pub const ImprovementLoopStats = system.ImprovementLoopStats;
pub const ImprovementLoop = system.ImprovementLoop;
pub const UnifiedRequest = system.UnifiedRequest;
pub const UnifiedResponse = system.UnifiedResponse;
pub const UnifiedAutonomousSystem = system.UnifiedAutonomousSystem;

// Instance accessors
pub fn getUnifiedAgent() *UnifiedAgent {
    const S = struct {
        var instance = UnifiedAgent.init();
    };
    return &S.instance;
}

pub fn getAutonomousAgent() *AutonomousAgent {
    const S = struct {
        var instance = AutonomousAgent.init();
    };
    return &S.instance;
}

pub fn getImprovementLoop() *ImprovementLoop {
    const S = struct {
        var instance = ImprovementLoop.init();
    };
    return &S.instance;
}

pub fn getUnifiedSystem() *UnifiedAutonomousSystem {
    const S = struct {
        var instance = UnifiedAutonomousSystem.init();
    };
    return &S.instance;
}

pub fn getAgentMemory() *AgentMemory {
    const S = struct {
        var instance = AgentMemory.init();
    };
    return &S.instance;
}

// Utility stubs
pub fn shutdownUnifiedAgent() void {}
pub fn shutdownAutonomousAgent() void {}
pub fn shutdownUnifiedSystem() void {}
pub fn hasUnifiedAgent() bool {
    return true;
}
pub fn hasAutonomousAgent() bool {
    return true;
}
pub fn hasUnifiedSystem() bool {
    return true;
}

// φ² + 1/φ² = 3 | TRINITY
