//! ═══════════════════════════════════════════════════════════════════════════════
//! COMMON ERRORS — Unified Error Types for Trinity
//! ═══════════════════════════════════════════════════════════════════════════════
//!
//! This module provides canonical error definitions used throughout Trinity.
//! DO NOT duplicate these error sets elsewhere.
//!
//! IMPORT: const errors = @import("common").errors;
//! USAGE: errors.VSAError, errors.ProtocolError, etc.
//!
//! φ² + φ⁻² = 3 = TRINITY
//! ═══════════════════════════════════════════════════════════════════════════════

/// ═══════════════════════════════════════════════════════════════════════════════
/// VSA ERRORS — Vector Symbolic Architecture
/// ═══════════════════════════════════════════════════════════════════════════════
pub const VSAError = error{
    /// Dimension is zero or exceeds maximum
    InvalidDimension,
    /// Dimension is not a multiple of required alignment
    MisalignedDimension,
    /// Concept name not found in VSA memory
    ConceptNotFound,
    /// Concept already exists in VSA memory
    ConceptAlreadyExists,
    /// Invalid trit value (not -1, 0, or +1)
    InvalidTrit,
    /// Vector operation failed (bind/unbind/bundle)
    VectorOperationFailed,
    /// Insufficient vectors provided for operation
    InsufficientVectors,
    /// Vector length mismatch
    VectorLengthMismatch,
    /// Index exceeds vector dimension
    IndexOutOfBounds,
};

/// ═══════════════════════════════════════════════════════════════════════════════
/// PROTOCOL ERRORS — UART and Communication
/// ═══════════════════════════════════════════════════════════════════════════════
pub const ProtocolError = error{
    /// CRC checksum mismatch
    InvalidChecksum,
    /// Frame synchronization failed
    InvalidSync,
    /// Invalid command byte
    InvalidCommand,
    /// Frame exceeds maximum size
    FrameTooLarge,
    /// Incomplete frame received
    IncompleteFrame,
    /// Unknown command byte
    UnknownCommand,
    /// Unexpected response
    UnexpectedResponse,
};

/// ═══════════════════════════════════════════════════════════════════════════════
/// UART ERRORS — Serial Communication
/// ═══════════════════════════════════════════════════════════════════════════════
pub const UARTError = error{
    /// Operation timed out
    Timeout,
    /// Receive buffer overflow
    Overflow,
    /// Parity error detected
    ParityError,
    /// Framing error
    FramingError,
    /// Device not found or disconnected
    DeviceNotFound,
    /// Permission denied for port access
    AccessDenied,
    /// Invalid baud rate
    InvalidBaudRate,
    /// Port already in use
    PortInUse,
};

/// ═══════════════════════════════════════════════════════════════════════════════
/// FPGA ERRORS — Synthesis and Hardware
/// ═══════════════════════════════════════════════════════════════════════════════
pub const FPGAError = error{
    /// Placement algorithm failed to converge
    PlacementFailed,
    /// Routing failed to find valid path
    RoutingFailed,
    /// Timing violation detected
    TimingViolation,
    /// Invalid device type
    InvalidDevice,
    /// Unsupported primitive for device
    UnsupportedPrimitive,
    /// Bitstream generation failed
    BitstreamGenerationFailed,
    /// JTAG programming failed
    JTAGProgrammingFailed,
    /// Constraint file parse error
    ConstraintParseError,
    /// Netlist parsing failed
    NetlistParseError,
    /// Insufficient resources (LUTs, FFs, etc.)
    InsufficientResources,
};

/// ═══════════════════════════════════════════════════════════════════════════════
/// CONSCIOUSNESS ERRORS — Cognitive and Memory
/// ═══════════════════════════════════════════════════════════════════════════════
pub const ConsciousnessError = error{
    /// Consciousness level below threshold
    BelowThreshold,
    /// Memory retrieval failed
    MemoryRetrievalFailed,
    /// Association too weak
    WeakAssociation,
    /// Confidence below required threshold
    LowConfidence,
    /// Immortality threshold not met
    NotImmortal,
};

/// ═══════════════════════════════════════════════════════════════════════════════
/// COMMON ERRORS — General Purpose
/// ═══════════════════════════════════════════════════════════════════════════════
pub const CommonError = error{
    /// Memory allocation failed
    OutOfMemory,
    /// Invalid argument provided
    InvalidArgument,
    /// Resource not found
    NotFound,
    /// Operation not supported
    NotSupported,
    /// Operation not implemented yet
    NotImplemented,
    /// Operation already in progress
    AlreadyInProgress,
    /// Invalid state for operation
    InvalidState,
    /// Operation was interrupted
    Interrupted,
    /// I/O error occurred
    InputOutput,
};

/// ═══════════════════════════════════════════════════════════════════════════════
/// COMPOSITE ERROR SETS
/// ═══════════════════════════════════════════════════════════════════════════════
/// Combined error set for VSA operations with I/O
pub const VSAIOError = VSAError || UARTError || CommonError;

/// Combined error set for FPGA operations
pub const FPGASynthesisError = FPGAError || CommonError || ProtocolError;

/// Combined error set for consciousness operations
pub const ConsciousnessIOError = ConsciousnessError || VSAError || CommonError;

/// Combined error set for all Trinity operations
pub const TrinityError = VSAError || ProtocolError || UARTError || FPGAError || ConsciousnessError || CommonError;

/// ═══════════════════════════════════════════════════════════════════════════════
/// ERROR UTILITIES
/// ═══════════════════════════════════════════════════════════════════════════════
/// Check if error is recoverable (can retry)
pub fn isRecoverable(err: anyerror) bool {
    return switch (err) {
        ConsciousnessError.LowConfidence,
        UARTError.Timeout,
        UARTError.Overflow,
        => true,

        else => false,
    };
}

/// Get human-readable error description
pub fn getDescription(err: anyerror) []const u8 {
    return switch (err) {
        // VSA errors
        VSAError.InvalidDimension => "VSA dimension must be positive and within valid range",
        VSAError.IndexOutOfBounds => "Vector index exceeds dimension",
        VSAError.ConceptNotFound => "Concept not found in VSA memory",
        VSAError.InvalidTrit => "Trit value must be -1, 0, or +1",

        // Protocol errors
        ProtocolError.InvalidChecksum => "CRC checksum verification failed",
        ProtocolError.InvalidSync => "Frame sync byte not found",
        ProtocolError.UnknownCommand => "Unknown command byte received",

        // UART errors
        UARTError.Timeout => "UART operation timed out",
        UARTError.DeviceNotFound => "UART device not found or disconnected",

        // FPGA errors
        FPGAError.PlacementFailed => "FPGA placement algorithm failed to converge",
        FPGAError.RoutingFailed => "FPGA routing failed to find valid path",
        FPGAError.TimingViolation => "Timing constraint violation detected",

        // Consciousness errors
        ConsciousnessError.BelowThreshold => "Consciousness level below required threshold",
        ConsciousnessError.NotImmortal => "Immortality threshold (φ⁻¹) not met",

        // Common errors
        CommonError.OutOfMemory => "Memory allocation failed",
        CommonError.InvalidArgument => "Invalid argument provided",
        CommonError.NotFound => "Requested resource not found",

        else => "Unknown error",
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Errors: VSAError includes expected variants" {
    // VSAError should include InvalidTrit
    const err: VSAError = .InvalidTrit;
    _ = err;
}

test "Errors: ProtocolError includes expected variants" {
    // ProtocolError should include InvalidChecksum
    const err: ProtocolError = .InvalidChecksum;
    _ = err;
}

test "Errors: isRecoverable identifies timeout" {
    const testing = std.testing;

    try testing.expect(isRecoverable(UARTError.Timeout));
    try testing.expect(!isRecoverable(VSAError.InvalidDimension));
}

test "Errors: getDescription returns non-empty" {
    const testing = std.testing;

    const desc = getDescription(VSAError.InvalidTrit);
    try testing.expect(desc.len > 0);
}

const std = @import("std");
