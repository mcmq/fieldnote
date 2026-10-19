import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config/firebase_env.dart';
import 'core/db/app_database.dart';
import 'core/platform/photo_store.dart';
import 'core/remote/remote_gateway.dart';
import 'core/sync/background_sync.dart';
import 'core/sync/sync_engine.dart';
import 'features/inspections/data/inspection_repository.dart';
import 'features/inspections/presentation/inspection_list_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadEnv();
  await Firebase.initializeApp(options: firebaseOptions());
  // SQLite is the source of truth; Firestore's own cache stays off.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );

  await PhotoStore.init();
  final repo = InspectionRepository(await AppDatabase.open());
  final engine = SyncEngine(repo, FirebaseRemoteGateway());
  try {
    await scheduleBackgroundSync();
  } catch (e) {
    debugPrint('Background sync unavailable: $e');
  }
  runApp(FieldNoteApp(repo: repo, engine: engine));
}

class FieldNoteApp extends StatefulWidget {
  const FieldNoteApp({super.key, required this.repo, required this.engine});

  final InspectionRepository repo;
  final SyncEngine engine;

  @override
  State<FieldNoteApp> createState() => _FieldNoteAppState();
}

class _FieldNoteAppState extends State<FieldNoteApp>
    with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Triggers: app start, offline -> online, after each local save, resume.
    widget.engine.syncNow();
    _sub = Connectivity().onConnectivityChanged.listen((r) {
      final offline = r.contains(ConnectivityResult.none);
      widget.engine.setOnline(!offline);
      if (!offline && _wasOffline) widget.engine.syncNow();
      _wasOffline = offline;
    });
    widget.repo.addListener(_onLocalChange);
  }

  void _onLocalChange() {
    if (!widget.engine.isSyncing) widget.engine.syncNow();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.engine.syncNow();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.repo.removeListener(_onLocalChange);
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.repo),
        ChangeNotifierProvider.value(value: widget.engine),
      ],
      child: MaterialApp(
        title: 'FieldNote',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F6F5C)),
          useMaterial3: true,
        ),
        home: const InspectionListScreen(),
      ),
    );
  }
}
