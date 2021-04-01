import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_shared_storage_writer/android_shared_storage_writer.dart';

void main() {
  const channel = MethodChannel('android_shared_storage_writer');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });
}
