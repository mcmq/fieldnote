enum InspectionCategory { building, equipment, facility }

enum OverallStatus { pass, fail, attention }

enum CheckResult { pass, fail, na }

enum SyncState { pending, synced, failed }

T enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

class ChecklistItem {
  ChecklistItem({
    required this.id,
    required this.label,
    this.result = CheckResult.na,
    this.note = '',
  });

  final String id;
  String label;
  CheckResult result;
  String note;
}

class Photo {
  Photo({
    required this.id,
    required this.localPath,
    this.remoteUrl,
    this.uploaded = false,
  });

  final String id;
  final String localPath;
  String? remoteUrl;
  bool uploaded;
}

class Inspection {
  Inspection({
    required this.id,
    this.title = '',
    this.siteName = '',
    this.category = InspectionCategory.building,
    this.overallStatus = OverallStatus.pass,
    this.notes = '',
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.capturedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
    this.syncState = SyncState.pending,
    List<ChecklistItem>? checklist,
    List<Photo>? photos,
  }) : checklist = checklist ?? [],
       photos = photos ?? [];

  final String id;
  String title;
  String siteName;
  InspectionCategory category;
  OverallStatus overallStatus;
  String notes;
  double? latitude;
  double? longitude;
  double? accuracyMeters;
  DateTime? capturedAt;
  final DateTime createdAt;
  DateTime updatedAt;
  bool deleted;
  SyncState syncState;
  final List<ChecklistItem> checklist;
  final List<Photo> photos;

  bool get hasLocation => latitude != null && longitude != null;

  /// Document shape stored in Firestore (see docs/data-model.md).
  Map<String, dynamic> toRemote() => {
    'title': title,
    'siteName': siteName,
    'category': category.name,
    'overallStatus': overallStatus.name,
    'notes': notes,
    'location': hasLocation
        ? {'lat': latitude, 'lng': longitude, 'accuracyM': accuracyMeters}
        : null,
    'capturedAt': capturedAt?.millisecondsSinceEpoch,
    'checklist': [
      for (final c in checklist)
        {'label': c.label, 'result': c.result.name, 'note': c.note},
    ],
    'photos': [
      for (final p in photos)
        if (p.remoteUrl != null) p.remoteUrl,
    ],
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
    'deleted': deleted,
  };
}

class OutboxEntry {
  OutboxEntry({
    required this.seq,
    required this.inspectionId,
    required this.op,
    required this.attempts,
    this.lastError,
  });

  final int seq;
  final String inspectionId;
  final String op; // upsert | delete
  final int attempts;
  final String? lastError;
}
