# Cell Template Library

Built-in templates for `tri cell init --template <name>`.

## Variables

Templates support variable substitution:
- `{{CELL_ID}}` — Cell ID (e.g., `trinity.myagent`)
- `{{NAME}}` — Short name (e.g., `myagent`)
- `{{PATH}}` — Filesystem path (e.g., `src/myagent`)
- `{{DESCRIPTION}}` — Description text
- `{{PARENT}}` — Parent cell ID (for virtual-sub)
- `{{CAPABILITIES}}` — JSON array of capabilities
- `{{DEFINITION}}` — Agent definition file path

## Built-in Templates

### `agent`
Autonomous agent with tools, context, and isolation.

### `tool`
CLI utility with commands and exports.

### `library`
Reusable library with exports and tests.

### `virtual`
Virtual sub-cell for modular organization.

## Custom Templates

Place custom `.tri` templates in `~/.tri/templates/`:

```bash
mkdir -p ~/.tri/templates
cp mytemplate.tri ~/.tri/templates/
tri cell init mycell --template mytemplate
```

## Example

```bash
tri cell init my-agent --template agent
tri cell init my-tool --template tool
tri cell init my-lib --template library
```
