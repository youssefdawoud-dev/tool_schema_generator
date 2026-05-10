## 0.3.0

* **Named Schema Getters:** The code generator now emits a private subclass of `ToolRegistry` that provides strongly-typed getters for each tool schema. You can now use `toolRegistry.myToolName` instead of manually importing the `<myToolName>ToolSchema` constant.
* Added `schemaFor(String name)` and `allSchemas` to `ToolRegistry`. You can now pass `toolRegistry.allSchemas` directly to your LLM framework.

## 0.2.0

### New: Tool Dispatcher — `ToolRegistry`, `ToolResult`, structured errors

This release adds a complete dispatcher layer so you can invoke tools by name
with the raw argument maps your LLM returns — with no boilerplate.

#### New public API

**`ToolRegistry`**
- `Future<ToolResult> call(String name, Map<String, dynamic> args)` — dispatch a tool call
- `Future<ToolResult>? callOrNull(String name, Map<String, dynamic> args)` — returns `null` for unknown tools instead of throwing
- `bool contains(String name)` — check if a tool is registered
- `Iterable<String> get toolNames` — enumerate registered tools

**`ToolResult`** (sealed class)
- `ToolSuccess(dynamic value)` — tool ran successfully
- `ToolError({String code, String message, String? field, dynamic expected, dynamic actual})` — structured, machine-readable failure

**Error codes emitted by `ToolError`:**
| Code | Trigger |
|---|---|
| `UNKNOWN_TOOL` | No tool with that name is registered (throws `UnknownToolException`) |
| `INVALID_ARGUMENT` | LLM sent a wrong type for a parameter |
| `MISSING_ARGUMENT` | A required parameter was absent |
| `INTERNAL_ERROR` | Unexpected exception inside the tool function |

**`ToolArgumentException`** — thrown internally by generated parsers; caught at registry boundary.

**`UnknownToolException`** — thrown by `ToolRegistry.call()` when the name is not registered. Includes `available` list.

#### Generator changes

The generator now emits, alongside each schema constant, a `final toolRegistry = ToolRegistry({...})` containing a handler closure per tool. Handlers:
- Cast every parameter safely with `as Type` (or `(num).toDouble()` for `double`)
- Respect nullable/optional params with `?? defaultValue` fallbacks
- Generate `_parseEnum<T>` helpers for enum-typed params (deduplicated)
- Generate `_parse<ClassName>` helpers for custom class params (user-defined only)
- Wrap all invocations in `Future.sync(...)` for uniform `Future<dynamic>` return type

#### Usage

```dart
final result = await toolRegistry.call(toolCall.name, toolCall.arguments);
switch (result) {
  case ToolSuccess(:final value): submitToModel(value.toString());
  case ToolError(:final code, :final message): print('$code: $message');
}
```

---

## 0.1.0

* **Initial Release:** First version of `tool_schema_generator`.


* **Initial Release:** First version of `tool_schema_generator`.
* Introduced `@Tool()` and `@Describe()` annotations for Dart functions.
* Full integration with `build_runner` and `source_gen:combining_builder` (works seamlessly alongside `json_serializable`).
* Support for primitive types, enums, nullables, lists, maps, and nested classes.
* Generates JSON Schema Draft 2020-12 compatible maps.
