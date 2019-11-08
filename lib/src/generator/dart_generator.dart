part of './generator.dart';

class DartCodeGenerator implements CodeGenerator {
  final _formatter = DartFormatter();
  @override
  final String basePath;

  DartCodeGenerator(this.basePath);

  Reference _dartType(ast.FieldType firestoreType) {
    switch (firestoreType.name) {
      case "string":
        return refer("String");
      case "url":
        return refer("Uri");
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
      case "file":
        return refer("FileReference");
    }
  }

  Reference _referFirestore(String symbol) =>
      refer(symbol, "package:cloud_firestore/cloud_firestore.dart");

  Reference _referStorage(String symbol) =>
      refer(symbol, "package:firebase_storage/firebase_storage.dart");

  Reference _futureRefer(String symbol, [String url]) {
    return TypeReference((b) => b
      ..symbol = "Future"
      ..types.add(refer(symbol, url)));
  }

  Reference _referStreamOf(String symbol, [String url]) {
    return TypeReference((b) => b
      ..symbol = "Stream"
      ..types.add(refer(symbol, url)));
  }

  Code _assertNotNull(String symbol) => Code("assert(${symbol} != null)");

  String _documentClassName(ast.Collection collection) =>
      collection.document.name ?? "${collection.name}__nonamedocument__";

  Iterable<Spec> extraCodes() {
    final firestoreReference = _referFirestore("Firestore");
    final storageReference = _referStorage("FirebaseStorage");
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
      Field((b) => b
        ..type = storageReference
        ..name = "_storage"
        ..assignment =
            Code.scope((allocate) => "${allocate(storageReference)}.instance")),
      Method.returnsVoid((b) => b
        ..name = "setFirebaseStorageInstance"
        ..requiredParameters.add(Parameter((b) => b
          ..type = storageReference
          ..name = "instance"))
        ..body = Code("_storage = instance;")),
      Code("\ntypedef DartTypeConverter<T, U> = T Function(U);\n"),
      Method((b) => b
        ..returns = refer("T")
        ..name = "_idConverter"
        ..types.add(refer("T"))
        ..requiredParameters.add(Parameter((b) => b
          ..type = refer(("T"))
          ..name = "v"))
        ..body = Code("return v;")),
      Method((b) => b
        ..returns = refer("DateTime")
        ..name = "_timestampToDateTimeConverter"
        ..requiredParameters.add(Parameter((b) => b
          ..type = refer("dynamic")
          ..name = "v"))
        ..body = Code("return v?.toDate();")),
      Method((b) => b
        ..returns = refer("Uri")
        ..name = "_stringUrlToUriConverter"
        ..requiredParameters.add(Parameter((b) => b
          ..type = refer("dynamic")
          ..name = "v"))
        ..body = Code("return (v != null) ? Uri.parse(v) : null;")),
      Method((b) => b
        ..returns = refer("int")
        ..name = "_numToIntConverter"
        ..requiredParameters.add(Parameter((b) => b
          ..type = refer("dynamic")
          ..name = "v"))
        ..body = Code("return v?.toInt();")),
      Method((b) => b
        ..returns = refer("FileReference")
        ..name = "_fileMapToFileReferenceConverter"
        ..requiredParameters.add(Parameter((b) => b
          ..type = refer("dynamic")
          ..name = "v"))
        ..body = Code("return (v != null) ? _RemoteFile._(v) : null;")),
      Field((b) => b
        ..type = TypeReference((b) => b
          ..symbol = "Map"
          ..types.addAll([refer("Type"), refer("DartTypeConverter")]))
        ..name = "_dartTypeConverterMap"
        // TODO: Converter for Geopoint
        ..assignment = Code.scope((allocate) => """
          {
            DateTime: _timestampToDateTimeConverter,
            Uri: _stringUrlToUriConverter,
            int: _numToIntConverter,
            FileReference: _fileMapToFileReferenceConverter,
            // TODO: Converter for Geopoint
          }
        """)),
      Method((b) => b
        ..returns = refer("T")
        ..name = "_convertDartType"
        ..types.add(refer("T"))
        ..requiredParameters.add(Parameter((b) => b
          ..type = refer("dynamic")
          ..name = "v"))
        ..body = Code("""
            return (_dartTypeConverterMap[T] ?? _idConverter).call(v);
        """)),
      Code(
          "\ntypedef FirestoreStructureConverter<T, U> = Future<T> Function(U, String);\n"),
      Method((b) => b
        ..returns = _futureRefer("T")
        ..name = "_delayedIdConverter"
        ..types.add(refer("T"))
        ..requiredParameters.addAll([
          Parameter((b) => b
            ..type = refer(("T"))
            ..name = "v"),
          Parameter((b) => b
            ..type = refer("String")
            ..name = "documentPath"),
        ])
        ..modifier = MethodModifier.async
        ..body = Code("return v;")),
      Method((b) => b
        ..returns = _futureRefer("Map<String, dynamic>")
        ..name = "_fileReferenceToFileMapConverter"
        ..requiredParameters.addAll([
          Parameter((b) => b
            ..type = refer("dynamic")
            ..name = "v"),
          Parameter((b) => b
            ..type = refer("String")
            ..name = "documentPath"),
        ])
        ..modifier = MethodModifier.async
        ..body = Code.scope((allocate) => """
          if (v is _LocalFile) {
            final magic = await v._file.openRead(0, 1).first;
            final mimeType = ${allocate(refer("lookupMimeType", "package:mime/mime.dart"))}(v._file.path, headerBytes: magic);
            final ref = _storage.path(documentPath);
            await ref.putFile(v._file, ${allocate(_referStorage("StorageMetadata"))}(contentType: mimeType)).onComplete;
            return {
              "additionlData": <String, dynamic>{},
              "mimeType": mimeType,
              "path": documentPath,
              "url": await ref.getDownloadURL(),
            };
          } else {
            return (v as _RemoteFile)._fileStructure;
          }
        """)),
      Field((b) => b
        ..type = TypeReference((b) => b
          ..symbol = "Map"
          ..types.addAll([refer("Type"), refer("FirestoreStructureConverter")]))
        ..name = "_firestoreStructureConverterMap"
        ..assignment = Code.scope((allocate) => """
          {
            FileReference: _fileReferenceToFileMapConverter,
          }
        """)),
      Method((b) => b
        ..returns = _futureRefer("dynamic")
        ..name = "_convertFirestoreStructure"
        ..types.add(refer("T"))
        ..requiredParameters.addAll([
          Parameter((b) => b
            ..type = refer("T")
            ..name = "v"),
          Parameter((b) => b
            ..type = refer("String")
            ..name = "documentPath"),
        ])
        ..body = Code("""
            return (_firestoreStructureConverterMap[T] ?? _delayedIdConverter).call(v, documentPath);
        """)),
      Class((b) => b
        ..abstract = true
        ..name = "FileReference"
        ..constructors.addAll([
          Constructor((b) => b
            ..factory = true
            ..name = "local"
            ..requiredParameters.add(Parameter((b) => b
              ..type = refer("File", "dart:io")
              ..name = "file"))
            ..body = Code("return _LocalFile._(file);")),
        ])
        ..methods.addAll([
          Method((b) => b
            ..returns = refer("Uri")
            ..type = MethodType.getter
            ..name = "uri"),
        ])),
      Class((b) => b
        ..name = "_LocalFile"
        ..implements.add(refer("FileReference"))
        ..fields.add(Field((b) => b
          ..modifier = FieldModifier.final$
          ..type = refer("File", "dart:io")
          ..name = "_file"))
        ..constructors.add(Constructor((b) => b
          ..name = "_"
          ..requiredParameters.add(Parameter((b) => b
            ..toThis = true
            ..name = "_file"))
          ..initializers.add(_assertNotNull("_file"))))
        ..methods.addAll([
          Method((b) => b
            ..annotations.add(refer("override"))
            ..returns = refer("Uri")
            ..type = MethodType.getter
            ..name = "uri"
            ..body = Code("return _file.uri;")),
        ])),
      Class((b) => b
        ..name = "_RemoteFile"
        ..implements.add(refer("FileReference"))
        ..fields.add(Field((b) => b
          ..modifier = FieldModifier.final$
          ..type = refer("Map<String, dynamic>")
          ..name = "_fileStructure"))
        ..constructors.add(Constructor((b) => b
          ..name = "_"
          ..requiredParameters.add(Parameter((b) => b
            ..toThis = true
            ..name = "_fileStructure"))
          ..initializers.add(_assertNotNull("_fileStructure"))))
        ..methods.addAll([
          Method((b) => b
            ..annotations.add(refer("override"))
            ..returns = refer("Uri")
            ..type = MethodType.getter
            ..name = "uri"
            ..body = Code("return Uri.parse(_fileStructure[\"url\"]);")),
        ])),
    ];
  }

  Iterable<Class> codeForCollection(List<ast.Collection> collections) {
    return collections.map((collection) {
      final name = "${collection.name}Collection";
      return [
        Class((b) => b
          ..name = name
          ..fields.add(Field((b) => b
            ..modifier = FieldModifier.final$
            ..type = _referFirestore("CollectionReference")
            ..name = "reference"))
          ..constructors.addAll([
            Constructor((b) => b
              ..requiredParameters.add(Parameter((b) => b
                ..toThis = true
                ..name = "reference"))
              ..initializers.add(Code("assert(reference != null)"))),
            Constructor((b) => b
              ..factory = true
              ..name = "fromPath"
              ..requiredParameters.add(Parameter((b) => b
                ..type = refer("String")
                ..name = "path"))
              ..body = Code("return ${name}(_firestore.collection(path));")),
          ])
          ..methods.addAll([
            Method((b) => b
              ..returns = refer("${_documentClassName(collection)}Document")
              ..name = "documentById"
              ..requiredParameters.add(Parameter((b) => b
                ..type = refer("String")
                ..name = "id"))
              ..body = Code(
                  "return ${_documentClassName(collection)}Document(reference.document(id));")),
          ])),
        ...codeForDocument(collection.document, collection)
      ];
    }).expand((c) => c);
  }

  Iterable<Class> codeForDocument(
      ast.Document document, ast.Collection parent) {
    final name = _documentClassName(parent);
    final snapshotName = "${name}Snapshot";
    final referenceName = "${name}Document";
    final documentRefClass = Class((b) => b
      ..name = referenceName
      ..fields.addAll([
        Field((b) => b
          ..modifier = FieldModifier.final$
          ..type = _referFirestore("DocumentReference")
          ..name = "reference"),
      ])
      ..constructors.addAll([
        Constructor((b) => b
          ..requiredParameters.add(Parameter((b) => b
            ..toThis = true
            ..name = "reference"))
          ..initializers.add(Code("assert(reference != null)"))),
        Constructor((b) => b
          ..factory = true
          ..name = "fromPath"
          ..requiredParameters.add(Parameter((b) => b
            ..type = refer("String")
            ..name = "path"))
          ..body = Code("return ${referenceName}(_firestore.document(path));")),
      ])
      ..methods.addAll([
        Method((b) => b
          ..returns = _futureRefer(snapshotName)
          ..name = "getSnapshot"
          ..body = Code.scope((allocate) => """
            return reference.get().then((s) => ${snapshotName}.fromSnapshot(s));
          """)),
        Method((b) => b
          ..returns = _referStreamOf(snapshotName)
          ..name = "snapshotUpdates"
          ..optionalParameters.add(Parameter((b) => b
            ..named = true
            ..type = refer("bool")
            ..name = "includeMetadataChanges"
            ..defaultTo = Code("false")))
          ..body = Code("""
            return reference
                .snapshots(includeMetadataChanges: includeMetadataChanges)
                .map((s) => ${snapshotName}.fromSnapshot(s));
          """)),
        Method((b) => b
          ..returns = _futureRefer("void")
          ..name = "delete"
          ..body = Code("return reference.delete();")),
        Method((b) => b
          ..returns = _futureRefer(snapshotName)
          ..name = "create"
          ..optionalParameters
              .addAll(document.fields.map((f) => Parameter((b) => b
                ..named = true
                ..annotations.add(refer("required", "package:meta/meta.dart"))
                ..name = f.name
                ..type = _dartType(f.type))))
          ..body = Code("""
            final data = <String, Future<dynamic>>{
              ${document.fields.map((f) => "\"${f.name}\": _convertFirestoreStructure(${f.name}, reference.path)").join(",")}
            };
            return Future
                .wait(data.values)
                .then((values) => Map.fromIterables(data.keys, values))
                .then((data) => reference.setData(data))
                .then((_) => ${snapshotName}(${document.fields.map((f) => "${f.name}: ${f.name}").join(",")}));
          """)),
        Method((b) => b
          ..returns = _futureRefer(snapshotName)
          ..name = "update"
          ..optionalParameters
              .addAll(document.fields.map((f) => Parameter((b) => b
                ..named = true
                ..name = f.name
                ..type = _dartType(f.type))))
          ..body = Code("""
            return reference
                .updateData({
                  ${document.fields.map((f) => "\"${f.name}\": ${f.name}").join(",")}
                })
                .then((_) => getSnapshot());
          """)),
        ...document.collections.map((c) => Method((b) => b
          ..returns = refer("${c.name}Collection")
          ..type = MethodType.getter
          ..name = c.name
          ..body = Code("""
            return ${c.name}Collection(reference.collection("${c.name}"));
          """))),
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
            ..type = _referFirestore("DocumentSnapshot")
            ..name = "documentSnapshot")))
          ..body = Code("""
            if (documentSnapshot.exists) {
              return ${snapshotName}(
                ${document.fields.map((f) => "${f.name}: _convertDartType(documentSnapshot[\"${f.name}\"])").join(",\n")}
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