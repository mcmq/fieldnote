import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/sync/sync_engine.dart';
import '../data/inspection_repository.dart';
import '../domain/models.dart';

class SyncStatusScreen extends StatelessWidget {
  const SyncStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<InspectionRepository>();
    final engine = context.watch<SyncEngine>();
    return Scaffold(
      appBar: AppBar(title: const Text('Sync status')),
      body: FutureBuilder<List<OutboxEntry>>(
        future: repo.outbox(),
        builder: (context, snap) {
          final entries = snap.data ?? [];
          final failed = entries
              .where((e) => e.attempts >= InspectionRepository.maxAutoAttempts)
              .toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                leading: Icon(engine.online ? Icons.wifi : Icons.wifi_off),
                title: Text(engine.online ? 'Online' : 'Offline'),
              ),
              ListTile(
                leading: const Icon(Icons.cloud_upload_outlined),
                title: Text('${entries.length} change(s) waiting to sync'),
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: Text(
                  engine.lastSyncAt == null
                      ? 'Not synced this session'
                      : 'Last sync ${DateFormat.jm().format(engine.lastSyncAt!)}',
                ),
                subtitle: engine.lastError == null
                    ? null
                    : Text(engine.lastError!),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                icon: const Icon(Icons.sync),
                label: Text(engine.isSyncing ? 'Syncing…' : 'Sync now'),
                onPressed: engine.isSyncing
                    ? null
                    : () => engine.syncNow(retryFailed: true),
              ),
              if (failed.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Failed', style: Theme.of(context).textTheme.titleMedium),
                for (final e in failed)
                  ListTile(
                    leading: const Icon(Icons.error_outline, color: Colors.red),
                    title: Text('${e.op} ${e.inspectionId.substring(0, 8)}'),
                    subtitle: Text(e.lastError ?? ''),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
