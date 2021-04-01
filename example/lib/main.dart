import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:android_shared_storage_writer/android_shared_storage_writer.dart';

void main() {
  runApp(MaterialApp(home: MyApp()));
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  initState() {
    super.initState();
  }

  @override
  dispose() {
    _collectionController.dispose();
    super.dispose();
  }

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _overwriteExisting = false;

  final _collectionController = TextEditingController();
  final _filenameController = TextEditingController(text: 'sample');

  var _directory = SharedStorageDirectory.pictures;

  @override
  build(context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Shared Storage Example App'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          Image.asset('assets/sample.png'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: DropdownButtonFormField<SharedStorageDirectory>(
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'Directory',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                border: OutlineInputBorder(),
              ),
              isExpanded: true,
              value: _directory,
              onChanged: (_) => setState(() => _directory = _),
              items: SharedStorageDirectory.values
                  .map((e) => DropdownMenuItem(
                        child: Text(e.name),
                        value: e,
                      ))
                  .toList(),
            ),
          ),
          textField(controller: _collectionController, label: 'Collection'),
          textField(controller: _filenameController, label: 'Filename'),
          CheckboxListTile(
            title: const Text('Overwrite Existing?'),
            value: _overwriteExisting,
            onChanged: (_) => setState(() => _overwriteExisting = _),
          ),
          ElevatedButton(
            child: const Text('Export to Gallery'),
            onPressed: () async {
              showDialog(
                barrierDismissible: false,
                context: context,
                builder: (context) => WillPopScope(
                  onWillPop: () async => false,
                  child: Center(
                    child: const CircularProgressIndicator(),
                  ),
                ),
              );
              String res;
              try {
                final data = await DefaultAssetBundle.of(context)
                    .load('assets/sample.png');
                res = await AndroidSharedStorageWriter.writeSharedFile(
                  directory: _directory,
                  collection: _collectionController.text,
                  filename: _filenameController.text,
                  data: Uint8List.sublistView(data),
                  overwriteExisting: _overwriteExisting,
                );
              } on SharedStorageException catch (e) {
                String title;
                String content;
                var needPermission = false;
                switch (e.code) {
                  case SharedStorageErrorCode.content_not_allowed:
                    title = 'Content not Allowed';
                    content = e.message ??
                        'File type not allowed in this Shared Storage directory';
                    break;
                  case SharedStorageErrorCode.file_exists:
                    title = 'Unable to Write File';
                    content = e.message ?? 'Cannot overwrite existing file.';
                    break;
                  case SharedStorageErrorCode.invalid_collection:
                    title = 'Invalid Collection';
                    content =
                        e.message ?? 'Unexpected Shared Storage Location Type';
                    break;
                  case SharedStorageErrorCode.write_permission_required:
                    title = 'Access Denied';
                    content = e.message ??
                        'External Storage Write Permission Required.';
                    needPermission = true;
                    break;
                  default:
                    throw UnsupportedError;
                }
                await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(title),
                    content: Text(content),
                  ),
                );
                if (needPermission) {
                  await AndroidSharedStorageWriter.requestWritePermission();
                }
                return;
              } on PlatformException catch (e) {
                await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: SingleChildScrollView(
                      child: const Text('Platform Exception'),
                    ),
                    content: SingleChildScrollView(
                      child: Text('$e'),
                    ),
                  ),
                );
                return;
              } finally {
                Navigator.of(context).pop();
              }
              _scaffoldKey.currentState.showSnackBar(
                SnackBar(
                  content: Text('File saved successfully to \'$res\''),
                ),
              );
            },
          )
        ],
      ),
    );
  }

  Widget textField({TextEditingController controller, String label}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: TextField(
          controller: controller,
          autocorrect: false,
          decoration: InputDecoration(
              isDense: true, border: OutlineInputBorder(), labelText: label),
        ),
      );
}
