import { Navigate } from 'react-router-dom'

export default function Playground() {
  // /play used to be a "Trinity HLS Compiler V5.0" that took Python, C++, Rust
  // or Zig and printed canned Verilog, SystemVerilog or VHDL with made-up logs.
  // t27c takes none of those languages as input and has never emitted VHDL or
  // SystemVerilog (corrected 2026-10-04). The Spec Explorer runs the real
  // compiler -- the same t27_compiler.wasm -- on source you can edit, and shows
  // every backend it has. The address stays, so links to /play keep working.
  return <Navigate to="/specs" replace />
}
