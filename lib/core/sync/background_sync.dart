import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../../features/inspections/data/inspection_repository.dart';
import '../config/firebase_env.dart';
import '../db/app_database.dart';
import '../platform/photo_store.dart';
import '../remote/remote_gateway.dart';
import 'sync_engine.dart';

const _periodicTask = 'fieldnote.periodicSync';

/// Entry point for the background isolate.
@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((task, input) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await loadEnv();
      await Firebase.initializeApp(options: firebaseOptions());
      await PhotoStore.init();
      final db = await AppDatabase.open();
      final engine = SyncEngine(
        InspectionRepository(db),
        FirebaseRemoteGateway(),
      );
      await engine.syncNow();
      await db.close();
      return engine.lastError == null;
    } catch (_) {
      return false; // ask the OS to retry later
    }
  });
}

Future<void> scheduleBackgroundSync() async {
  await Workmanager().initialize(backgroundDispatcher);
  await Workmanager().registerPeriodicTask(
    _periodicTask,
    _periodicTask,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}
