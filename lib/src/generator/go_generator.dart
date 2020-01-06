part of './generator.dart';

class GoGenerator implements CodeGenerator {

  @override
  final String basePath;


  GoGenerator(this.basePath);

  @override
  Iterable<GeneratedCodeFile> generate(ast.Schema schema, AnalyzingResult analyzed) {
    // TODO: implement generate
    return null;
  }

  String _goTypeName(ast.DeclaredType type) {
    switch(type) {
      case ast.DeclaredType.string:
        return "string";
        break;
      case ast.DeclaredType.url:
        return "url.URL";
        break;
      case ast.DeclaredType.number:
        return "float64";
        break;
      case ast.DeclaredType.integer:
        return "int";
        break;
      case ast.DeclaredType.boolean:
        return "bool";
        break;
      case ast.DeclaredType.map:
        return "map[string]interface";
        break;
      case ast.DeclaredType.timestamp:
        return "*time.Time";
        break;
      case ast.DeclaredType.geopoint:
        return "*latlng.LatLng";
        break;
      case ast.DeclaredType.file:
        return "*File";
        break;
      default:
        if (type is ast.TypedType && type.name == "array") {
          return "[]${_goTypeName(type.typeParameter)}";
        }  else if (type is ast.TypedType && type.name == "reference") {
          return "*firestore.DocumentRef";
        }
        break;
    }
  }

  String _goDefaultValue(ast.DeclaredType type) {
    switch(type) {
      case ast.DeclaredType.string:
        return "\"\"";
      case ast.DeclaredType.url:
        return "&url.URL{}";
      case ast.DeclaredType.number:
        return "0.0";
      case ast.DeclaredType.integer:
        return "0";
      case ast.DeclaredType.boolean:
        return "false";
      case ast.DeclaredType.map:
        return "map[string]interface{}";
      case ast.DeclaredType.timestamp:
        return "&time.Time{}";
      case ast.DeclaredType.geopoint:
        return "*latlng.LatLng{}";
      case ast.DeclaredType.file:
        return "*File{}";
      default:
    }

  }

}