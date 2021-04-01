import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum SharedStorageDirectory {
  pictures,
  music,
  movies,
  alarms,
  dcim,
  downloads,
  notifications,
  podcasts,
  ringtones,
  documents,
  screenshots,
}

extension SharedStorageDirectoryExt on SharedStorageDirectory {
  static const names = {
    SharedStorageDirectory.pictures: 'Pictures',
    SharedStorageDirectory.music: 'Music',
    SharedStorageDirectory.movies: 'Movies',
    SharedStorageDirectory.alarms: 'Alarms',
    SharedStorageDirectory.dcim: 'DCIM',
    SharedStorageDirectory.downloads: 'Downloads',
    SharedStorageDirectory.notifications: 'Notifications',
    SharedStorageDirectory.podcasts: 'Podcasts',
    SharedStorageDirectory.ringtones: 'Ringtones',
    SharedStorageDirectory.documents: 'Documents',
    SharedStorageDirectory.screenshots: 'Screenshots',
  };

  String get name => names[this];
}

enum _Method {
  api_level,
  write_permission,
  request_write_permission,
  write,
}

extension _MethodExt on _Method {
  static const names = {
    _Method.api_level: 'api_level',
    _Method.write_permission: 'write_permission',
    _Method.request_write_permission: 'request_write_permission',
    _Method.write: 'write',
  };

  String get name => names[this];
}

extension _MethodChannelExt on MethodChannel {
  Future<T> invoke<T>(_Method method, [dynamic arguments]) async {
    T result;
    try {
      result = await invokeMethod(method.name, arguments);
    } catch (e) {
      rethrow;
    }
    return result;
  }
}

class AndroidSharedStorageWriter {
  static const _channel = MethodChannel('android_shared_storage_writer');

  static const _androidScopedStorageApiLevel = 29;

  /// Gets the android API level.
  static Future<int> get _androidApiLevel async =>
      Platform.isAndroid ? await _channel.invoke(_Method.api_level) : null;

  /// Checks if write permission to shared storage is granted.
  ///
  /// Always returns `true` for API level >= 29.
  static Future<bool> get writePermission async =>
      await _channel.invoke(_Method.write_permission);

  /// Requests write permission to external storage
  ///
  /// NB: Does not wait for user input and returns upon permissions dialog launch
  static Future<void> requestWritePermission() async =>
      await _channel.invoke(_Method.request_write_permission);

  /// Attempt to write file represented by [data] to the shared storage [directory].
  /// The file will be written under the optional [collection] name if specified.
  /// The eventual filename will be based on the extensionless [filename] provided -
  /// the file extension will be determined by examining the MimeType of the [data] provided.
  /// An parameter [overwriteExisting] may be specified to allow or disallow overwriting
  /// existing files of the same name (default - not allowed).
  ///
  /// Returns the path that the file was eventually written to.
  static Future<String> writeSharedFile({
    @required SharedStorageDirectory directory,
    String collection,
    @required String filename,
    @required Uint8List data,
    bool overwriteExisting = false,
  }) async {
    final androidApiLevel = await _androidApiLevel;
    if (androidApiLevel != null &&
        androidApiLevel < _androidScopedStorageApiLevel) {
      if (!(await _channel.invoke(_Method.write_permission))) {
        throw SharedStorageException(
            code: SharedStorageErrorCode.write_permission_required,
            message: 'External Storage Write Permission Required');
      }
    }
    String path;
    try {
      path = await _channel.invoke(_Method.write, {
        'directory': directory.name,
        'collection': collection,
        'filename': filename,
        'data': data,
        'overwrite_existing': overwriteExisting,
      });
    } on PlatformException catch (e) {
      final code = SharedStorageCodeExt.fromCode(e.code);
      if (code == null) {
        rethrow;
      }
      throw SharedStorageException(
          code: code, message: e.message, details: e.details);
    }
    return path;
  }
}

enum SharedStorageErrorCode {
  content_not_allowed,
  file_exists,
  invalid_collection,
  write_permission_required,
}

extension SharedStorageCodeExt on SharedStorageErrorCode {
  static const codes = {
    SharedStorageErrorCode.content_not_allowed: 'content_not_allowed',
    SharedStorageErrorCode.file_exists: 'file_exists',
    SharedStorageErrorCode.invalid_collection: 'invalid_collection',
    SharedStorageErrorCode.write_permission_required:
        'write_permission_required',
  };

  String get code => codes[this];

  static SharedStorageErrorCode fromCode(String value) => codes.entries
      .firstWhere((e) => e.value == value, orElse: () => null)
      ?.key;
}

class SharedStorageException implements Exception {
  final SharedStorageErrorCode code;
  final String message;
  final details;
  SharedStorageException({
    @required this.code,
    this.message,
    this.details,
  });

  @override
  String toString() => 'SharedStorageException($code, $message, $details)';
}
