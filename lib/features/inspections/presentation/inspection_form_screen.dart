import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/platform/photo_compressor.dart';
import '../../../core/platform/photo_store.dart';
import '../data/inspection_repository.dart';
import '../domain/models.dart';

const _uuid = Uuid();

class InspectionFormScreen extends StatefulWidget {
  const InspectionFormScreen({super.key, this.existing});
  final Inspection? existing;

  @override
  State<InspectionFormScreen> createState() => _InspectionFormScreenState();
}

class _InspectionFormScreenState extends State<InspectionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Inspection _i;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _i =
        widget.existing ??
        Inspection(
          id: _uuid.v4(),
          createdAt: now,
          updatedAt: now,
          checklist: [
            for (final l in [
              'Structure / casing',
              'Safety signage',
              'Cleanliness',
              'Operation',
            ])
              ChecklistItem(id: _uuid.v4(), label: l),
          ],
        );
  }

  Future<void> _addPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
    );
    if (picked == null) return;
    final id = _uuid.v4();
    final saved = await compressPhoto(
      File(picked.path),
      p.join(PhotoStore.directory.path, '$id.jpg'),
    );
    setState(
      () => _i.photos.add(Photo(id: id, localPath: p.basename(saved.path))),
    );
  }

  Future<void> _captureLocation() async {
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw 'Location permission denied';
      }
      // GPS works without internet.
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _i.latitude = pos.latitude;
        _i.longitude = pos.longitude;
        _i.accuracyMeters = pos.accuracy;
        _i.capturedAt = DateTime.now();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not get location: $e')));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    await context.read<InspectionRepository>().save(_i);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'New inspection' : 'Edit inspection',
        ),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              initialValue: _i.title,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
              onSaved: (v) => _i.title = v!.trim(),
            ),
            TextFormField(
              initialValue: _i.siteName,
              decoration: const InputDecoration(labelText: 'Site'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
              onSaved: (v) => _i.siteName = v!.trim(),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<InspectionCategory>(
              initialValue: _i.category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final c in InspectionCategory.values)
                  DropdownMenuItem(value: c, child: Text(c.name)),
              ],
              onChanged: (v) => _i.category = v!,
            ),
            const SizedBox(height: 16),
            Text(
              'Overall status',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            SegmentedButton<OverallStatus>(
              segments: const [
                ButtonSegment(value: OverallStatus.pass, label: Text('Pass')),
                ButtonSegment(
                  value: OverallStatus.attention,
                  label: Text('Attention'),
                ),
                ButtonSegment(value: OverallStatus.fail, label: Text('Fail')),
              ],
              selected: {_i.overallStatus},
              onSelectionChanged: (s) =>
                  setState(() => _i.overallStatus = s.first),
            ),
            const SizedBox(height: 24),
            Text('Checklist', style: Theme.of(context).textTheme.titleMedium),
            for (final item in _i.checklist) _checklistRow(item),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add item'),
              onPressed: () => setState(
                () => _i.checklist.add(
                  ChecklistItem(id: _uuid.v4(), label: 'New item'),
                ),
              ),
            ),
            TextFormField(
              initialValue: _i.notes,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 4,
              onSaved: (v) => _i.notes = v ?? '',
            ),
            const SizedBox(height: 24),
            Text('Photos', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final ph in _i.photos)
                  Stack(
                    children: [
                      Image.file(
                        PhotoStore.resolve(ph.localPath),
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        right: 0,
                        child: InkWell(
                          onTap: () => setState(() => _i.photos.remove(ph)),
                          child: const Icon(Icons.cancel, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Camera'),
                  onPressed: () => _addPhoto(ImageSource.camera),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                  onPressed: () => _addPhoto(ImageSource.gallery),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Location', style: Theme.of(context).textTheme.titleMedium),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.my_location),
              title: Text(
                _i.hasLocation
                    ? '${_i.latitude!.toStringAsFixed(5)}, ${_i.longitude!.toStringAsFixed(5)}'
                    : 'Not captured',
              ),
              subtitle: _i.accuracyMeters == null
                  ? null
                  : Text('±${_i.accuracyMeters!.round()} m'),
              trailing: _locating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(
                      onPressed: _captureLocation,
                      child: const Text('Capture GPS'),
                    ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _checklistRow(ChecklistItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: item.label,
                  onChanged: (v) => item.label = v,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => setState(() => _i.checklist.remove(item)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SegmentedButton<CheckResult>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: CheckResult.pass, label: Text('Pass')),
              ButtonSegment(value: CheckResult.fail, label: Text('Fail')),
              ButtonSegment(value: CheckResult.na, label: Text('N/A')),
            ],
            selected: {item.result},
            onSelectionChanged: (s) => setState(() => item.result = s.first),
          ),
        ],
      ),
    );
  }
}
