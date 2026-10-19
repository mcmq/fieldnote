import 'package:flutter/material.dart';

import '../domain/models.dart';

class SyncBadge extends StatelessWidget {
  const SyncBadge(this.state, {super.key});
  final SyncState state;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (state) {
      SyncState.synced => (Icons.cloud_done, 'Synced', Colors.green),
      SyncState.pending => (
        Icons.cloud_upload_outlined,
        'Pending',
        Colors.orange,
      ),
      SyncState.failed => (Icons.error_outline, 'Failed', Colors.red),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}

String statusLabel(OverallStatus s) => switch (s) {
  OverallStatus.pass => 'Pass',
  OverallStatus.fail => 'Fail',
  OverallStatus.attention => 'Needs attention',
};

Color statusColor(OverallStatus s) => switch (s) {
  OverallStatus.pass => Colors.green,
  OverallStatus.fail => Colors.red,
  OverallStatus.attention => Colors.orange,
};
