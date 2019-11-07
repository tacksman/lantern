import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:lantern/src/ast.dart' as ast;

class GeneratedCodeFile {
  final String filePath;
  final String content;

  const GeneratedCodeFile(this.filePath, this.content);
}

abstract class CodeGenerator {
  String get basePath;

  Iterable<GeneratedCodeFile> generate(ast.Schema schema);
}

class DartCodeGenerator implements CodeGenerator {
  final _formatter = DartFormatter();
  @override
  final String basePath;

  DartCodeGenerator(this.basePath);

  Iterable<Class> codeForCollection(List<ast.Collection> collections) {
    return collections.map((collection) {
      final name = "${collection.name}Collection";
      return [
        Class((b) => b..name = name),
        ...codeForDocument(collection.document, collection)
      ];
    }).expand((c) => c);
  }

  Reference _dartType(String firestoreType) {
    switch (firestoreType) {
      case "string":
        return refer("String");
      case "number":
        return refer("num");
      case "integer":
        return refer("int");
      case "boolean":
        return refer("bool");
      case "map":
        return refer("Map<String, dynamic>");
      case "array":
        return refer("List<dynamic>");
      case "timestamp":
        return refer("DateTime");
      case "geopoint":
        return TypeReference(((b) => b
          ..symbol = "Point"
          ..url = "dart:math"
          ..types.add(refer("double"))));
    }
  }

  Reference _futureRefer(String symbol, [String url]) {
    return TypeReference((b) => b
      ..symbol = "Future"
      ..types.add(refer(symbol, url)));
  }

  Iterable<Class> codeForDocument(
      ast.Document document, ast.Collection parent) {
    final name = document.name ?? "${parent.name}_nonamedocument_";
    final snapshotName = "${name}Snapshot";
    final documentRefClass = Class((b) => b
      ..name = "${name}Document"
      ..fields.addAll([
        Field((b) => b
          ..modifier = FieldModifier.final$
          ..type = refer("String")
          ..name = "id"),
      ])
      ..methods.addAll([
        Method((b) => b
          ..returns = refer("String")
          ..type = MethodType.getter
          ..name = "path"
          // TODO: How to get the path of this document
          ..body = Code("return /* TODO: どうやってパス取ってこよう… */id;")),
        Method((b) => b
          ..returns = refer("DocumentReference",
              "package:cloud_firestore/cloud_firestore.dart")
          ..type = MethodType.getter
          ..name = "_reference"
          ..body = Code("return _firestore.document(path);")),
        Method((b) => b
          ..returns = _futureRefer(snapshotName)
          ..name = "getSnapshot"
          ..body = Code.scope((allocate) => """
            return _reference.get().then((s) => ${snapshotName}.fromSnapshot(s));
          """)),
      ]));

    final documentSnapshotClass = Class((b) => b
      ..name = snapshotName
      ..fields.replace(document.fields.map((f) => Field((b) => b
        ..modifier = FieldModifier.final$
        ..type = _dartType(f.type)
        ..name = f.name)))
      ..constructors.addAll([
        Constructor((b) => b
          ..constant = true
          ..optionalParameters
              .replace(document.fields.map((f) => Parameter((b) => b
                ..named = true
                ..annotations.add(refer("required", "package:meta/meta.dart"))
                ..toThis = true
                ..name = f.name)))),
        Constructor((b) => b
          ..factory = true
          ..name = "fromSnapshot"
          ..requiredParameters.add((Parameter((b) => b
            ..type = refer("DocumentSnapshot",
                "package:cloud_firestore/cloud_firestore.dart")
            ..name = "documentSnapshot")))
          ..body = Code("""
            if (documentSnapshot.exists) {
              return ${snapshotName}(
                ${document.fields.map((f) => "${f.name}: documentSnapshot[\"${f.name}\"]").join(",\n")}
              );
            } else {
              return null;
            }
          """)),
      ]));
    return [
      documentRefClass,
      documentSnapshotClass,
      ...codeForCollection(document.collections),
    ];
  }

  Iterable<Spec> extraCodes() {
    final firestoreReference =
        refer("Firestore", "package:cloud_firestore/cloud_firestore.dart");
    return [
      Field((b) => b
        ..type = firestoreReference
        ..name = "_firestore"
        ..assignment = Code.scope(
            (allocate) => "${allocate(firestoreReference)}.instance")),
      Method.returnsVoid((b) => b
        ..name = "setFirestoreInstance"
        ..requiredParameters.add(Parameter((b) => b
          ..type = firestoreReference
          ..name = "instance"))
        ..body = Code("_firestore = instance;")),
    ];
  }

  @override
  Iterable<GeneratedCodeFile> generate(ast.Schema schema) {
    final classes = codeForCollection(schema.collections);
    final lib =
        Library((b) => b..body.addAll(extraCodes())..body.addAll(classes));
    return [
      GeneratedCodeFile(basePath + "firestore_scheme.g.dart",
          _formatter.format("${lib.accept(DartEmitter.scoped())}"))
    ];
  }
}

class SwiftCodeGenerator implements CodeGenerator {
  final String basePath;

  SwiftCodeGenerator(this.basePath);

  @override
  Iterable<GeneratedCodeFile> generate(ast.Schema schema) {
    // TODO: implement generate
    return null;
  }
}
