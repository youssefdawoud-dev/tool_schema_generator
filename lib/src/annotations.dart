/// Marks a top-level function as an LLM-callable tool.
///
/// The generator will produce a `const Map<String, dynamic>` representing
/// the tool schema in the standard OpenAI / Gemini function-calling format.
///
/// By default, the function's Dart name is used as the tool name and its
/// doc comment is used as the description. Both can be overridden via
/// the annotation parameters.
///
/// Example:
/// ```dart
/// /// Gets the current weather for a given city.
/// @Tool()
/// String getWeather(
///   @Describe('The city name') String city, {
///   @Describe('Temperature unit') String unit = 'celsius',
/// }) {
///   // ...
/// }
/// ```
class Tool {
  /// Optional override for the tool name.
  ///
  /// When `null`, the generator uses the annotated function's Dart name.
  final String? name;

  /// Optional override for the tool description.
  ///
  /// When `null`, the generator uses the function's doc comment
  /// (with `///` prefixes stripped).
  final String? description;

  /// Creates a [Tool] annotation.
  const Tool({this.name, this.description});
}

/// Annotates a function parameter with a human-readable description
/// that will appear in the generated JSON Schema.
///
/// This is optional — parameters without `@Describe` will still appear
/// in the schema, but without a `"description"` field.
///
/// Example:
/// ```dart
/// @Tool()
/// void search(
///   @Describe('The search query string') String query,
///   @Describe('Maximum number of results to return') int limit,
/// ) {}
/// ```
class Describe {
  /// The human-readable description for this parameter.
  final String description;

  /// Creates a [Describe] annotation.
  const Describe(this.description);
}

/// Marks a named tool parameter as runtime-injected.
///
/// Injected parameters are not included in the generated JSON Schema sent to
/// the LLM. They are still read from the `args` map passed to
/// `toolRegistry.call`, so application code can merge request/session values
/// into the tool call arguments before dispatch.
///
/// Injected parameters must be named and optional: either nullable or have a
/// Dart default value.
///
/// Example:
/// ```dart
/// @Tool()
/// void createTask(
///   String title, {
///   @Inject() String? userId,
///   @Inject() String locale = 'en',
/// }) {}
/// ```
class Inject {
  /// Creates an [Inject] annotation.
  const Inject();
}
