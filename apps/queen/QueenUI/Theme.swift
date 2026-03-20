//
// Theme Compatibility Shim
//
// This file provides backward compatibility during the migration to Cortex/Visual/v1_theme.swift
// All new code should import V1Theme directly from the Cortex module
//
// φ² + 1/φ² = 3 = TRINITY
//

import SwiftUI

// MARK: - TrinityTheme Alias

/// TrinityTheme is now an alias to V1Theme from Cortex/Visual/v1_theme.swift
/// Use V1Theme directly in new code
public typealias TrinityTheme = V1Theme
