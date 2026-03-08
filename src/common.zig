//! ═══════════════════════════════════════════════════════════════════════════════
//! COMMON MODULE — Single Source of Truth for Trinity Shared Definitions
//! ═══════════════════════════════════════════════════════════════════════════════
//!
//! This module provides unified access to all shared constants, protocols,
//! and error types used throughout Trinity.
//!
//! IMPORT: const common = @import("common");
//! USAGE: common.constants.PHI, common.protocol.Trit, common.errors.VSAError
//!
//! φ² + φ⁻² = 3 = TRINITY
//! ═══════════════════════════════════════════════════════════════════════════════

/// Sacred mathematical constants (PHI, GAMMA, TRINITY, etc.)
pub const constants = @import("common/constants.zig");

/// Protocol definitions (Trit, CRC, UART commands, VSA commands)
pub const protocol = @import("common/protocol.zig");

/// Unified error types (VSAError, ProtocolError, FPGAError, etc.)
pub const errors = @import("common/errors.zig");

// Re-export commonly used items for convenience
pub const PHI = constants.PHI;
pub const PHI_INV = constants.PHI_INV;
pub const PHI_SQ = constants.PHI_SQ;
pub const GAMMA = constants.GAMMA;
pub const TRINITY = constants.TRINITY;

// Core trit types
pub const Trit = protocol.Trit;
pub const PackedTrit = protocol.PackedTrit;
pub const InvalidTritError = protocol.InvalidTritError;

// Command types
pub const VSACmd = protocol.VSACmd;
pub const UARTCommand = protocol.UARTCommand;
pub const TrinityV1Command = protocol.TrinityV1Command;
pub const TrinityV1Response = protocol.TrinityV1Response;
pub const LedMode = protocol.LedMode;

// Utility functions
pub const crc16Ccitt = protocol.crc16Ccitt;
pub const packedTritValue = protocol.packedTritValue;

// Error types
pub const VSAError = errors.VSAError;
pub const ProtocolError = errors.ProtocolError;
pub const UARTError = errors.UARTError;
pub const FPGAError = errors.FPGAError;
pub const CommonError = errors.CommonError;
