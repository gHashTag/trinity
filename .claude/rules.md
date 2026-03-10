# NEEDLE Operations — MCP-ONLY

For structural code editing, use ONLY MCP needle tools (not raw CLI):
- needle_search, needle_structural_replace, needle_quality_gates
- needle_preview, needle_batch_edit, needle_autonomous_refactor

For build/test/format, prefer slash commands:
- /trinity-test, /fpga-synth, /vibee-gen, /vsa-verify

Generated files (trinity/output/, generated/) are READ-ONLY.
Edit the .tri spec and regenerate with /vibee-gen.
