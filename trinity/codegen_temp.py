#!/usr/bin/env python3
"""
Временный кодогенератор .vibee → .zig
Используется пока vibeec компилятор не обновлён под Zig 0.15
"""

import yaml
import sys
from pathlib import Path
from typing import Dict, List, Any, Optional

class VibeeToZig:
    def __init__(self):
        self.indent = "    "
        
    def parse_vibee(self, content: str) -> Dict:
        """Парсит YAML-like .vibee спецификацию"""
        return yaml.safe_load(content)
    
    def generate_zig(self, spec: Dict) -> str:
        """Генерирует Zig код из спецификации"""
        lines = []
        
        # Header
        lines.append(f"// Generated from {spec.get('name', 'unknown')}.vibee")
        lines.append(f"// Module: {spec.get('module', 'unknown')}")
        lines.append(f"// φ² + 1/φ² = 3")
        lines.append("")
        lines.append("const std = @import(\"std\");")
        lines.append("")
        
        # Types
        if 'types' in spec:
            lines.extend(self._generate_types(spec['types']))
        
        # Constants
        if 'constants' in spec:
            lines.extend(self._generate_constants(spec['constants']))
        
        # Main struct
        struct_name = spec.get('name', 'Module').title().replace('_', '')
        lines.append(f"pub const {struct_name} = struct {{")
        lines.append("")
        
        # Fields from state
        if 'types' in spec:
            for type_name, type_def in spec['types'].items():
                if 'State' in type_name:
                    lines.extend(self._generate_state_fields(type_def))
        
        # Behaviors as methods
        if 'behaviors' in spec:
            for behavior in spec['behaviors']:
                lines.extend(self._generate_behavior(behavior))
        
        lines.append("};")
        lines.append("")
        
        # Tests
        lines.extend(self._generate_tests(spec))
        
        return "\n".join(lines)
    
    def _generate_types(self, types: Dict) -> List[str]:
        lines = []
        for name, definition in types.items():
            if 'fields' in definition:
                lines.append(f"pub const {name} = struct {{")
                for field_name, field_type in definition['fields'].items():
                    zig_type = self._map_type(field_type)
                    lines.append(f"    {field_name}: {zig_type},")
                lines.append("}};")
                lines.append("")
        return lines
    
    def _generate_constants(self, constants: Dict) -> List[str]:
        lines = []
        for name, value in constants.items():
            if isinstance(value, str):
                lines.append(f'pub const {name} = "{value}";')
            elif isinstance(value, int):
                lines.append(f'pub const {name}: i32 = {value};')
            elif isinstance(value, float):
                lines.append(f'pub const {name}: f64 = {value};')
        lines.append("")
        return lines
    
    def _generate_state_fields(self, type_def: Dict) -> List[str]:
        lines = []
        if 'fields' in type_def:
            for field_name, field_type in type_def['fields'].items():
                zig_type = self._map_type(field_type)
                lines.append(f"    {field_name}: {zig_type},")
        return lines
    
    def _generate_behavior(self, behavior: Dict) -> List[str]:
        lines = []
        name = behavior.get('name', 'unknown')
        lines.append(f"    pub fn {name}(self: *@This()") 
        
        # Parameters from 'given'
        if 'given' in behavior:
            given = behavior['given']
            if isinstance(given, dict):
                for param_name, param_type in given.items():
                    zig_type = self._map_type(param_type)
                    lines[-1] += f", {param_name}: {zig_type}"
            elif isinstance(given, list):
                for param in given:
                    if isinstance(param, dict):
                        for param_name, param_type in param.items():
                            zig_type = self._map_type(param_type)
                            lines[-1] += f", {param_name}: {zig_type}"
        
        lines[-1] += ") !void {"
        lines.append(f"        // {behavior.get('description', '')}")
        lines.append("        _ = self;")
        
        # Implementation stub
        if 'then' in behavior:
            if isinstance(behavior['then'], list):
                for step in behavior['then']:
                    if isinstance(step, dict):
                        action = step.get('action', 'unknown')
                        lines.append(f"        // TODO: {action}")
        
        lines.append("    }")
        lines.append("")
        return lines
    
    def _generate_tests(self, spec: Dict) -> List[str]:
        lines = []
        struct_name = spec.get('name', 'Module').title().replace('_', '')
        lines.append("test \"basic functionality\" {")
        lines.append(f"    var instance = {struct_name}{{}};")
        lines.append("    _ = instance;")
        lines.append("}")
        return lines
    
    def _map_type(self, vibee_type: str) -> str:
        """Маппинг VIBEE типов в Zig типы"""
        mapping = {
            'String': '[]const u8',
            'Int': 'i64',
            'Float': 'f64',
            'Bool': 'bool',
        }
        return mapping.get(vibee_type, vibee_type)

def main():
    if len(sys.argv) < 2:
        print("Usage: python codegen_temp.py <file.vibee>")
        sys.exit(1)
    
    vibee_file = Path(sys.argv[1])
    if not vibee_file.exists():
        print(f"Error: {vibee_file} not found")
        sys.exit(1)
    
    # Parse and generate
    codegen = VibeeToZig()
    content = vibee_file.read_text()
    spec = codegen.parse_vibee(content)
    zig_code = codegen.generate_zig(spec)
    
    # Write output
    output_dir = Path("trinity/output")
    output_dir.mkdir(parents=True, exist_ok=True)
    
    output_file = output_dir / f"{vibee_file.stem}.zig"
    output_file.write_text(zig_code)
    
    print(f"✓ Generated: {output_file}")

if __name__ == "__main__":
    main()