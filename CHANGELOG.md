## 0.0.3

- Breaking change
    - Now generated Dart codes depend on [flamingo](https://pub.dev/packages/flamingo)
    - Lantern generates classes for flamingo's Document and Model.
    - Generated files are separated into each collection.
- Supports `enum{}` and `struct{}`
    - `enum{}` will generate enum values.
    - `struct{}` will generate Codable/Model classes.

## 0.0.2

- Omit Firestore rule file generation.
- Supports `file` and `struct<>`
    - `file` expresses the file uploaded on Cloud Storage, based on [`File`](https://github.com/1amageek/Ballcap-iOS#file) of [Ballcap-iOS](https://github.com/1amageek/Ballcap-iOS).
    - `struct<>` expressed the struct of specified Document.
- Breaking changes of `DocumentSnapshot` returned from `DocumentReference` on generated Dart file.

## 0.0.1

- Initial version, dart/swift/rule generating
