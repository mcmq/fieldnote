import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Photos live in `<documents>/photos`. The database stores only the file
/// name: on iOS the app container path changes between installs/updates, so
/// absolute paths would break.
class PhotoStore {
  static late Directory _dir;

  static Future<void> init() async {
    _dir = Directory(
      p.join((await getApplicationDocumentsDirectory()).path, 'photos'),
    );
    await _dir.create(recursive: true);
  }

  static Directory get directory => _dir;

  /// Accepts a bare file name or a legacy absolute path.
  static File resolve(String stored) =>
      File(p.join(_dir.path, p.basename(stored)));
}
