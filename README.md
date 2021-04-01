# android_shared_storage_writer

A Flutter plugin for writing files to public shared storage on Android devices.

## Getting Started

Add this plugin under `dependencies` to `pubspec.yaml`:
```` yaml
dependencies:
  android_shared_storage_writer:
    git:
      url: git://github.com/brian-quah/android_shared_storage_writer.git
      ref: 0.0.1+1
````

To support devices with Android versions older than Android Q, add the `WRITE_EXTERNAL_STORAGE` permission to your app's `AndroidManifest.xml` file as follows:

``` xml
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28" />
```


### Usage Example

To check if app has write permission:
``` dart
await AndroidSharedStorageWriter.writePermission;
```

To show write permission popup to user:
``` dart
AndroidSharedStorageWriter.requestWritePermission();
```

To write a file to shared storage:
``` dart
Future<void> write({File file}) async {
    final data = await file.readAsBytes();
    try {
        // Attempt to write file
        final path = await AndroidSharedStorageWriter.writeSharedFile(
            directory: SharedStorageDirectory.pictures,
            collection: 'subdirectory',
            filename: 'foo',
            data: data,
            overwriteExisting: true,
        );
    } on SharedStorageException catch (e) {
        switch (e.code) {
            // Handle error feedback to user
            case SharedStorageErrorCode.write_permission_required:
                // TODO: Inform user that write permission is needed
                break;
            case SharedStorageErrorCode.file_exists:
                // TODO: Inform user that file already exists and can't be overwritten
                break;
            case SharedStorageErrorCode.invalid_collection:
                // TODO: Inform user that specified shared directory is unavailable (i.e. with older Android versions)
                break;
            case SharedStorageErrorCode.content_not_allowed:
                // TODO: Inform user that specified shared directory cannot contain file type given
                break;
        }
    }
}
```

See example app for a more detailed usage example.