import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> openOfflineDatabase({
  required String fileName,
  required int version,
  required OnDatabaseCreateFn onCreate,
}) async {
  final directory = await getApplicationSupportDirectory();
  final databasePath = p.join(directory.path, fileName);
  if (Platform.isLinux || Platform.isWindows) {
    sqfliteFfiInit();
    return databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(version: version, onCreate: onCreate),
    );
  }
  return openDatabase(databasePath, version: version, onCreate: onCreate);
}
