import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/sync/sync_engine.dart';
import '../data/inspection_repository.dart';
import '../domain/models.dart';
import 'inspection_detail_screen.dart';
import 'inspection_form_screen.dart';
import 'sync_status_screen.dart';
import 'widgets.dart';

class InspectionListScreen extends StatelessWidget {
  const InspectionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<InspectionRepository>();
    final engine = context.watch<SyncEngine>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('FieldNote'),
        actions: [
          if (engine.isSyncing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync status',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SyncStatusScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!engine.online)
            Container(
              width: double.infinity,
              color: Colors.orange.shade100,
              padding: const EdgeInsets.all(8),
              child: const Text(
                'Offline — changes are saved on this device and will sync later.',
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: FutureBuilder<List<Inspection>>(
              future: repo.list(),
              builder: (context, snap) {
                final items = snap.data;
                if (items == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (items.isEmpty) {
                  return const Center(
                    child: Text('No inspections yet. Tap + to add one.'),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => engine.syncNow(retryFailed: true),
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, n) => _Tile(items[n]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New inspection'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InspectionFormScreen()),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.i);
  final Inspection i;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(i.title.isEmpty ? '(untitled)' : i.title),
      subtitle: Text(
        '${i.siteName} · ${DateFormat.yMMMd().add_jm().format(i.updatedAt)}',
      ),
      leading: Icon(
        Icons.assignment_turned_in,
        color: statusColor(i.overallStatus),
      ),
      trailing: SyncBadge(i.syncState),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => InspectionDetailScreen(id: i.id)),
      ),
    );
  }
}
