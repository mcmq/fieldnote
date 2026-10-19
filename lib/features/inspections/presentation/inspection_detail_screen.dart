
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/platform/photo_store.dart';
import '../data/inspection_repository.dart';
import '../domain/models.dart';
import 'inspection_form_screen.dart';
import 'widgets.dart';

class InspectionDetailScreen extends StatelessWidget {
  const InspectionDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<InspectionRepository>();
    return FutureBuilder<Inspection?>(
      future: repo.get(id),
      builder: (context, snap) {
        final i = snap.data;
        if (i == null || i.deleted) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: snap.connectionState == ConnectionState.done
                  ? const Text('Inspection not found')
                  : const CircularProgressIndicator(),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(i.title),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InspectionFormScreen(existing: i),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final nav = Navigator.of(context);
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Delete inspection?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await repo.delete(i.id);
                    nav.pop();
                  }
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Chip(
                    label: Text(statusLabel(i.overallStatus)),
                    backgroundColor: statusColor(
                      i.overallStatus,
                    ).withValues(alpha: .15),
                  ),
                  const Spacer(),
                  SyncBadge(i.syncState),
                ],
              ),
              Text(
                '${i.siteName} · ${i.category.name}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                'Updated ${DateFormat.yMMMd().add_jm().format(i.updatedAt)}',
              ),
              const SizedBox(height: 16),
              if (i.hasLocation)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.place),
                  title: Text(
                    '${i.latitude!.toStringAsFixed(5)}, ${i.longitude!.toStringAsFixed(5)}',
                  ),
                  subtitle: Text('±${i.accuracyMeters?.round() ?? '?'} m'),
                ),
              Text('Checklist', style: Theme.of(context).textTheme.titleMedium),
              for (final c in i.checklist)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(c.label),
                  trailing: Text(c.result.name.toUpperCase()),
                ),
              if (i.notes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Notes', style: Theme.of(context).textTheme.titleMedium),
                Text(i.notes),
              ],
              if (i.photos.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Photos', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in i.photos)
                      Image.file(
                        PhotoStore.resolve(p.localPath),
                        width: 110,
                        height: 110,
                        fit: BoxFit.cover,
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
