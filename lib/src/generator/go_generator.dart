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
        return "URL";
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
        return "time.Time";
        break;
      case ast.DeclaredType.geopoint:
        return "*latlng.LatLng";
        break;
      case ast.DeclaredType.file:
        return "*File";
        break;
      default:
        break;
    }
  }

}