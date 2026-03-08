#!/usr/bin/env python3
"""
MCP Security Policy Gateway — P0.1
Pre-tool execution policy layer with approval, allowlists, audit trail.
"""

import json
import os
from datetime import datetime
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional
from dataclasses import dataclass, asdict
from enum import Enum


class PolicyResult(Enum):
    """Policy decision result"""
    ALLOW = "allow"
    DENY = "deny"
    REQUIRE_APPROVAL = "require_approval"


@dataclass
class AuditEntry:
    """Audit log entry for policy decisions"""
    timestamp: str
    tool: str
    decision: str
    reason: str
    params: Dict[str, Any]
    user: str = "unknown"
    metadata: Dict[str, Any] = None

    def __post_init__(self):
        if self.metadata is None:
            self.metadata = {}


class SecurityPolicy:
    """Security policy configuration"""

    # Dangerous tools that require approval
    DANGEROUS_TOOLS = {
        "tri_release_cosmic",
        "tri_release_absolute",
        "tri_omega_evolve",
    }

    # Tools that modify the filesystem
    FILESYSTEM_TOOLS = {
        "tri_gen",
        "tri_convert",
        "tri_fpga",
    }

    # Allowed filesystem paths (deny-by-default for dangerous)
    ALLOWED_PATHS = {
        "tri_gen": [".vibee", ".tri", "specs/"],
        "tri_convert": ["-"],  # stdin only
        "tri_fpga": ["fpga/", "-"],
    }

    def __init__(self, audit_log_path: str = ".trinity/audit.log"):
        self.audit_log_path = Path(audit_log_path)
        self.audit_log_path.parent.mkdir(parents=True, exist_ok=True)

    def check_tool(self, tool_name: str, params: Dict[str, Any]) -> tuple[PolicyResult, str]:
        """
        Check if a tool call should be allowed.

        Returns (PolicyResult, reason)
        """
        # Check dangerous tools
        if tool_name in self.DANGEROUS_TOOLS:
            return (
                PolicyResult.REQUIRE_APPROVAL,
                f"Tool '{tool_name}' requires explicit approval due to system-wide impact"
            )

        # Check filesystem tools
        if tool_name in self.FILESYSTEM_TOOLS:
            return self._check_filesystem_access(tool_name, params)

        # Default: allow
        return (PolicyResult.ALLOW, "Tool is safe to execute")

    def _check_filesystem_access(self, tool_name: str, params: Dict[str, Any]) -> tuple[PolicyResult, str]:
        """Check filesystem access for tools that write files."""
        allowed = self.ALLOWED_PATHS.get(tool_name, [])

        # If no allowlist configured, require approval
        if not allowed:
            return (
                PolicyResult.REQUIRE_APPROVAL,
                f"Tool '{tool_name}' has no configured allowlist"
            )

        # Check input/output parameters against allowlist
        for key in ["input", "output", "file", "spec"]:
            if key in params:
                path = params[key]
                if not self._is_path_allowed(path, allowed):
                    return (
                        PolicyResult.DENY,
                        f"Path '{path}' not in allowlist for '{tool_name}': {allowed}"
                    )

        return (PolicyResult.ALLOW, "Filesystem access approved")

    def _is_path_allowed(self, path: str, allowed_paths: List[str]) -> bool:
        """Check if a path is in the allowlist."""
        # Allow stdin/stdout
        if path == "-" or path in allowed_paths:
            return True

        # Check if path starts with any allowed prefix
        for prefix in allowed_paths:
            if path.startswith(prefix):
                return True

        return False

    def log_decision(self, entry: AuditEntry) -> None:
        """Write audit entry to log file."""
        with open(self.audit_log_path, "a") as f:
            f.write(json.dumps(asdict(entry)) + "\n")


# Global security policy instance
_policy: Optional[SecurityPolicy] = None


def get_policy() -> SecurityPolicy:
    """Get the global security policy instance."""
    global _policy
    if _policy is None:
        _policy = SecurityPolicy()
    return _policy


class PolicyMiddleware:
    """Middleware for enforcing security policies"""

    def __init__(self, policy: Optional[SecurityPolicy] = None):
        self.policy = policy or get_policy()

    async def check_call(
        self,
        tool_name: str,
        params: Dict[str, Any],
        user: str = "unknown"
    ) -> tuple[bool, str]:
        """
        Check if a tool call should be allowed.

        Returns (allowed, reason)
        """
        decision, reason = self.policy.check_tool(tool_name, params)

        # Log the decision
        entry = AuditEntry(
            timestamp=datetime.utcnow().isoformat(),
            tool=tool_name,
            decision=decision.value,
            reason=reason,
            params=params,
            user=user
        )
        self.policy.log_decision(entry)

        # Return result
        if decision == PolicyResult.ALLOW:
            return (True, reason)
        elif decision == PolicyResult.DENY:
            return (False, f"Denied: {reason}")
        else:  # REQUIRE_APPROVAL
            return (False, f"Requires approval: {reason}")

    def get_audit_log(self, limit: int = 100) -> List[AuditEntry]:
        """Get recent audit log entries."""
        if not self.policy.audit_log_path.exists():
            return []

        entries = []
        with open(self.policy.audit_log_path, "r") as f:
            for line in f:
                if not line.strip():
                    continue
                data = json.loads(line)
                entries.append(AuditEntry(**data))
                if len(entries) >= limit:
                    break

        return list(reversed(entries))  # Most recent first


def create_security_gateway() -> PolicyMiddleware:
    """Factory function to create security gateway."""
    return PolicyMiddleware()


# For backward compatibility with server.py
class PolicyDecision:
    """Deprecated: Use PolicyResult instead"""
    ALLOW = PolicyResult.ALLOW
    DENY = PolicyResult.DENY
    REQUIRE_APPROVAL = PolicyResult.REQUIRE_APPROVAL
