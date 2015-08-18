@TestOn('vm')
library dart_dev.test.integration.init_test;

import 'dart:async';
import 'dart:io';

import 'package:dart_dev/util.dart' show TaskProcess;
import 'package:test/test.dart';

const String initializedProject = 'test/fixtures/init/initialized';
const String uninitializedProject = 'test/fixtures/init/uninitialized';

Future init(String projectPath) async {
  await Process.run('pub', ['get'], workingDirectory: projectPath);

  TaskProcess process = new TaskProcess('pub', ['run', 'dart_dev', 'init'],
      workingDirectory: projectPath);
  await process.done;
}

void main() {
  group('Init Task', () {
    test('should not overwrite tool/dev.dart if it already exists', () async {
      File dartDev = new File('$initializedProject/tool/dev.dart');
      String contentsBefore = dartDev.readAsStringSync();
      await init(initializedProject);
      String contentsAfter = dartDev.readAsStringSync();
      expect(contentsBefore, equals(contentsAfter));
    });

    test('should generate a tool/dev.dart', () async {
      File dartDev = new File('$uninitializedProject/tool/dev.dart');
      expect(dartDev.existsSync(), isFalse);
      await init(uninitializedProject);
      expect(dartDev.existsSync(), isTrue);
      dartDev.deleteSync();
    });
  });
}
