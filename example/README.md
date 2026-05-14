# Example usage of `tool_schema_generator`

This example demonstrates how to use the `tool_schema_generator` package to automatically generate JSON Schema definitions for your Dart functions.

## Setup

1. Add `tool_schema_generator` to your `dependencies`.
2. Add `build_runner` to your `dev_dependencies`.

```yaml
dependencies:
  tool_schema_generator: ^0.3.0

dev_dependencies:
  build_runner: ^2.4.0
```

## Running the generator

After adding your `@Tool()` annotations, run the build runner to generate the `.g.dart` file:

```bash
dart run build_runner build -d
```

Check out `lib/tools.dart` in this example to see how the annotations are used!
