import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

/// Maps Dart types to JSON Schema Draft 2020-12 compatible type representations.
///
/// Returns a Dart source string that represents a `Map<String, dynamic>` literal
/// suitable for embedding in generated code.
class TypeMapper {
  /// Set of class types already being processed, used to prevent infinite
  /// recursion when a class references itself.
  final Set<String> _processingStack = {};

  /// Converts a [DartType] to a JSON Schema map literal string.
  ///
  /// Handles:
  /// - Primitive types (`String`, `int`, `double`, `num`, `bool`)
  /// - `List<T>` → `{"type": "array", "items": <T schema>}`
  /// - `Map<String, T>` → `{"type": "object"}`
  /// - Enum types → `{"type": "string", "enum": [...]}`
  /// - Custom classes → recursive `{"type": "object", "properties": {...}}`
  /// - Nullable types → adds `"nullable": true`
  String mapType(DartType type) {
    final isNullable = type.nullabilitySuffix == NullabilitySuffix.question;
    final coreSchema = _mapCoreType(type);

    if (isNullable && !coreSchema.contains("'nullable': true")) {
      // Insert nullable flag into the schema map
      return coreSchema.replaceFirst(
        '<String, dynamic>{',
        "<String, dynamic>{'nullable': true, ",
      );
    }

    return coreSchema;
  }

  String _mapCoreType(DartType type) {
    // Unwrap nullable for matching
    final element = type.element;

    // Check for void / dynamic
    if (type is VoidType || type is DynamicType) {
      return "<String, dynamic>{'type': 'string'}";
    }

    // Check primitive types by name
    final typeName = type.getDisplayString();
    final baseTypeName = typeName.endsWith('?')
        ? typeName.substring(0, typeName.length - 1)
        : typeName;

    switch (baseTypeName) {
      case 'String':
        return "<String, dynamic>{'type': 'string'}";
      case 'int':
        return "<String, dynamic>{'type': 'integer'}";
      case 'double':
        return "<String, dynamic>{'type': 'number'}";
      case 'num':
        return "<String, dynamic>{'type': 'number'}";
      case 'bool':
        return "<String, dynamic>{'type': 'boolean'}";
    }

    // Check for List<T>
    if (type.isDartCoreList && type is InterfaceType) {
      final typeArgs = type.typeArguments;
      if (typeArgs.isNotEmpty) {
        final itemsSchema = mapType(typeArgs.first);
        return "<String, dynamic>{'type': 'array', 'items': $itemsSchema}";
      }
      return "<String, dynamic>{'type': 'array'}";
    }

    // Check for Map<String, T>
    if (type.isDartCoreMap) {
      return "<String, dynamic>{'type': 'object'}";
    }

    // Check for enum types
    if (element is EnumElement) {
      final enumValues = element.fields
          .where((field) => field.isEnumConstant)
          .map((field) => "'${field.name}'")
          .join(', ');
      return "<String, dynamic>{'type': 'string', 'enum': <String>[$enumValues]}";
    }

    // Check for custom class types (nested objects)
    if (element is ClassElement && type is InterfaceType) {
      return _mapClassType(element);
    }

    // Fallback
    return "<String, dynamic>{'type': 'string'}";
  }

  /// Maps a [ClassElement] to a JSON Schema "object" type with properties
  /// derived from the class's constructor parameters.
  String _mapClassType(ClassElement classElement) {
    final className = classElement.name;

    // Prevent infinite recursion for self-referencing types
    if (className == null || _processingStack.contains(className)) {
      return "<String, dynamic>{'type': 'object', 'description': '${className ?? 'unknown'} (circular reference)'}";
    }

    _processingStack.add(className);

    try {
      // Find the unnamed constructor or the first constructor
      final constructor =
          classElement.unnamedConstructor ??
          classElement.constructors.firstOrNull;

      if (constructor == null) {
        return "<String, dynamic>{'type': 'object'}";
      }

      final propertiesBuffer = StringBuffer();
      final requiredParams = <String>[];
      var isFirstProperty = true;

      for (final param in constructor.formalParameters) {
        if (!isFirstProperty) {
          propertiesBuffer.write(', ');
        }
        isFirstProperty = false;

        final paramName = param.name;
        final paramSchema = mapType(param.type);
        propertiesBuffer.write("'$paramName': $paramSchema");

        if (param.isRequired) {
          requiredParams.add("'$paramName'");
        }
      }

      final requiredPart = requiredParams.isNotEmpty
          ? ", 'required': <String>[${requiredParams.join(', ')}]"
          : '';

      return "<String, dynamic>{'type': 'object', 'properties': <String, dynamic>{$propertiesBuffer}$requiredPart}";
    } finally {
      _processingStack.remove(className);
    }
  }

  // ---------------------------------------------------------------------------
  // Dispatcher code generation
  // ---------------------------------------------------------------------------

  /// Generates a Dart expression that safely extracts and casts the value for
  /// [fieldName] from an `args` map, for use in the generated dispatcher.
  ///
  /// [defaultCode] is the raw source string of the parameter's default value
  /// (e.g. `'celsius'` or `true`) as reported by the analyzer. When provided,
  /// a `?? defaultCode` fallback is appended for nullable/optional params.
  String generateArgParser(
    DartType type,
    String fieldName, {
    String? defaultCode,
  }) {
    final isNullable = type.nullabilitySuffix == NullabilitySuffix.question;
    final hasDefault = defaultCode != null && defaultCode.isNotEmpty;
    final rawAccess = "args['$fieldName']";

    String withDefault(String expr) {
      if (hasDefault) {
        return '($expr) ?? $defaultCode';
      }
      return expr;
    }

    if (type is VoidType || type is DynamicType) {
      return withDefault('$rawAccess as dynamic');
    }

    final typeName = type.getDisplayString();
    final baseTypeName = typeName.endsWith('?')
        ? typeName.substring(0, typeName.length - 1)
        : typeName;
    final nullableSuffix = (isNullable || hasDefault) ? '?' : '';

    switch (baseTypeName) {
      case 'String':
        return withDefault('$rawAccess as String$nullableSuffix');
      case 'int':
        return withDefault('$rawAccess as int$nullableSuffix');
      case 'bool':
        return withDefault('$rawAccess as bool$nullableSuffix');
      case 'num':
        return withDefault('$rawAccess as num$nullableSuffix');
      case 'double':
        if (isNullable || hasDefault) {
          return withDefault('($rawAccess as num?)?.toDouble()');
        }
        return withDefault('($rawAccess as num).toDouble()');
    }

    final element = type.element;

    if (type.isDartCoreList && type is InterfaceType) {
      final typeArgs = type.typeArguments;
      if (typeArgs.isNotEmpty) {
        final itemType = typeArgs.first.getDisplayString();
        if (isNullable || hasDefault) {
          return withDefault('($rawAccess as List?)?.cast<$itemType>()');
        }
        return withDefault('($rawAccess as List).cast<$itemType>()');
      }
      return withDefault('$rawAccess as List$nullableSuffix');
    }

    if (type.isDartCoreMap) {
      return withDefault('$rawAccess as Map<String, dynamic>$nullableSuffix');
    }

    if (element is EnumElement) {
      final enumName = element.name;
      if (enumName == null) return withDefault('$rawAccess as dynamic');

      final castType = (isNullable || hasDefault) ? 'String?' : 'String';

      return withDefault(
        '_parseEnum($enumName.values, $rawAccess as $castType)',
      );
    }

    if (element is ClassElement) {
      final className = element.name;
      if (className == null) return withDefault('$rawAccess as dynamic');
      final cap = className[0].toUpperCase() + className.substring(1);
      final helperName = '_parse$cap';
      if (isNullable || hasDefault) {
        return withDefault(
          '$rawAccess != null ? $helperName($rawAccess as Map<String, dynamic>) : null',
        );
      }
      return withDefault('$helperName($rawAccess as Map<String, dynamic>)');
    }

    return withDefault('$rawAccess as dynamic');
  }

  /// Generates the source for a `_parse<ClassName>` top-level helper that
  /// reconstructs a class from a raw `Map<String, dynamic>`.
  ///
  /// Returns `null` if the class has no usable constructor.
  String? generateClassParser(ClassElement classElement) {
    final className = classElement.name;
    if (className == null) return null;

    final constructor =
        classElement.unnamedConstructor ??
        classElement.constructors.firstOrNull;
    if (constructor == null) return null;

    final cap = className[0].toUpperCase() + className.substring(1);
    final helperName = '_parse$cap';
    final buffer = StringBuffer();
    buffer.writeln('$className $helperName(Map<String, dynamic> m) =>');
    buffer.write('    $className(');

    var first = true;
    for (final param in constructor.formalParameters) {
      if (!first) buffer.write(', ');
      first = false;
      final paramName = param.name ?? '';
      // Reuse generateArgParser but with map variable `m` instead of `args`
      final expr = generateArgParser(
        param.type,
        paramName,
        defaultCode: param.defaultValueCode,
      ).replaceAll("args['", "m['");
      if (param.isNamed) {
        buffer.write('$paramName: $expr');
      } else {
        buffer.write(expr);
      }
    }
    buffer.writeln(');');
    return buffer.toString();
  }
}
