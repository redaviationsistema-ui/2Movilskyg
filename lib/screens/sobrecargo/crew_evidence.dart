import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/cliente_api.dart';
import '../shared/widgets/crew_ui_tokens.dart';

const crewEvidenceLabels = {
  'catering_received': 'Catering',
  'baggage_secured': 'Equipaje',
  'cabin_condition': 'Cabina final',
};

List<Map<String, dynamic>> evidenceMaps(dynamic value) =>
    value is List
        ? value
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : [];

class CrewEvidenceSlot {
  CrewEvidenceSlot(this.type, this.item);
  final String type;
  final Map<String, dynamic> item;
  String get code => '${item['code']}';
  String get id => '${item['id'] ?? ''}';
  List<Map<String, dynamic>> get files => evidenceMaps(item['evidence_files']);
  bool get persisted => files.any(
    (file) =>
        '${file['file_path'] ?? ''}'.trim().isNotEmpty &&
        '${file['storage_disk'] ?? ''}'.trim().isNotEmpty,
  );
}

List<CrewEvidenceSlot> crewEvidenceSlots(Map<String, dynamic> workflow) {
  final checklists = evidenceMaps(workflow['checklists'])..sort(
    (a, b) => (int.tryParse('${b['id']}') ?? 0).compareTo(
      int.tryParse('${a['id']}') ?? 0,
    ),
  );
  return [
    for (final code in crewEvidenceLabels.keys)
      ...() {
        final type = code == 'cabin_condition' ? 'postflight' : 'preflight';
        final groups = checklists.where((group) => group['type'] == type);
        if (groups.isEmpty) return <CrewEvidenceSlot>[];
        final items = evidenceMaps(
          groups.first['items'],
        ).where((item) => item['code'] == code);
        return [if (items.isNotEmpty) CrewEvidenceSlot(type, items.first)];
      }(),
  ];
}

int crewEvidenceCount(Map<String, dynamic> workflow) =>
    crewEvidenceSlots(workflow).where((slot) => slot.persisted).length;

bool crewEvidenceEditable(
  Map<String, dynamic> workflow,
  CrewEvidenceSlot slot,
) =>
    slot.id.isNotEmpty &&
    (workflow['editable_evidence'] is List &&
        (workflow['editable_evidence'] as List).contains(slot.code));

/// Local selections never enter the canonical workflow or its persisted count.
class CrewEvidencePanel extends StatefulWidget {
  const CrewEvidencePanel({
    super.key,
    required this.workflow,
    required this.operationId,
    required this.api,
    required this.reload,
    this.pickImage,
    this.busy = false,
    this.onBusyChanged,
  });
  final Map<String, dynamic> workflow;
  final String operationId;
  final ApiClient api;
  final Future<Map<String, dynamic>> Function() reload;
  final Future<XFile?> Function(ImageSource)? pickImage;
  final bool busy;
  final ValueChanged<bool>? onBusyChanged;

  @override
  State<CrewEvidencePanel> createState() => _CrewEvidencePanelState();
}

class _CrewEvidencePanelState extends State<CrewEvidencePanel> {
  final Map<String, File> _pending = {};
  final Map<String, int> _pendingSizes = {};
  bool _busy = false;
  String _message = '';

  Future<void> _refresh() async {
    if (_busy || widget.busy) return;
    setState(() {
      _busy = true;
      _message = '';
    });
    widget.onBusyChanged?.call(true);
    try {
      await widget.reload();
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _message =
                  'No se pudieron actualizar las evidencias. Intenta nuevamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      widget.onBusyChanged?.call(false);
    }
  }

  Future<void> _select(CrewEvidenceSlot slot, ImageSource source) async {
    if (_busy || widget.busy) return;
    try {
      final image =
          await (widget.pickImage?.call(source) ??
              ImagePicker().pickImage(source: source, imageQuality: 88));
      if (image == null || !mounted) return;
      final file = File(image.path);
      setState(() {
        _pending[slot.id] = file;
        _pendingSizes.remove(slot.id);
        _message = '';
      });
      final size = await file.length();
      if (!mounted || _pending[slot.id]?.path != file.path) return;
      setState(() => _pendingSizes[slot.id] = size);
    } catch (error, stackTrace) {
      debugPrint('Error de evidencia: $error\n$stackTrace');
      if (mounted) {
        setState(
          () =>
              _message = 'No se pudo seleccionar la foto. Intenta nuevamente.',
        );
      }
    }
  }

  Future<void> _upload(CrewEvidenceSlot slot) async {
    final file = _pending[slot.id];
    if (file == null ||
        _busy ||
        widget.busy ||
        !crewEvidenceEditable(widget.workflow, slot)) {
      return;
    }
    setState(() {
      _busy = true;
      _message = '';
    });
    widget.onBusyChanged?.call(true);
    bool uploaded = false;
    try {
      await widget.api.uploadCrewChecklistEvidence(
        operationId: widget.operationId,
        checklistType: slot.type,
        itemId: slot.id,
        file: file,
      );
      uploaded = true;
      final workflow = await widget.reload();
      final confirmed = crewEvidenceSlots(workflow).any(
        (value) =>
            value.type == slot.type &&
            value.id == slot.id &&
            value.persisted &&
            (!slot.persisted ||
                value.files.any(
                  (file) =>
                      !slot.files.any(
                        (old) =>
                            old['file_path'] == file['file_path'] &&
                            old['storage_disk'] == file['storage_disk'],
                      ),
                )),
      );
      if (!confirmed) {
        throw StateError('El workflow todavía no devuelve la evidencia.');
      }
      if (!mounted) return;
      setState(() {
        _pending.remove(slot.id);
        _pendingSizes.remove(slot.id);
        _message = 'Evidencia registrada';
      });
    } catch (error, stackTrace) {
      debugPrint('Error de evidencia: $error\n$stackTrace');
      if (mounted) {
        setState(
          () =>
              _message =
                  uploaded
                      ? 'Archivo enviado; no se pudo confirmar la evidencia. Actualiza el vuelo.'
                      : 'No fue posible subir la evidencia. Intenta nuevamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      widget.onBusyChanged?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slots = crewEvidenceSlots(widget.workflow);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(
              child: Text(
                'Evidencias para el cierre',
                style: TextStyle(
                  color: CrewColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              '${crewEvidenceCount(widget.workflow)}/3',
              style: const TextStyle(
                color: CrewColors.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        TextButton.icon(
          onPressed: _busy || widget.busy ? null : _refresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Actualizar evidencias'),
        ),
        const SizedBox(height: 16),
        if (_message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(_message, key: const ValueKey('evidence-message')),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1200 ? 2 : 1;
            return GridView.builder(
              key: const ValueKey('evidence-grid'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                mainAxisExtent: 560,
              ),
              itemCount: slots.length,
              itemBuilder: (context, index) => _card(slots[index]),
            );
          },
        ),
        for (final code in crewEvidenceLabels.keys)
          if (!slots.any((slot) => slot.code == code))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('${crewEvidenceLabels[code]}: no disponible'),
            ),
      ],
    );
  }

  Widget _badge(String label, {required bool pending}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (pending ? CrewColors.warning : CrewColors.success).withValues(
          alpha: .12,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: pending ? CrewColors.warning : CrewColors.success,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _fileName(File file) => file.path.split(RegExp(r'[/\\]')).last;

  String _fileSize(int? bytes) {
    if (bytes == null) return 'Tamaño no disponible';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _preview({required String key, required Widget child}) {
    return KeyedSubtree(
      key: ValueKey(key),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(width: double.infinity, height: 150, child: child),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required VoidCallback? onPressed,
    required bool primary,
    IconData? icon,
  }) {
    final child =
        icon == null
            ? Text(label)
            : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Text(label),
              ],
            );
    return primary
        ? FilledButton(onPressed: onPressed, child: child)
        : OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: CrewColors.textPrimary,
            side: const BorderSide(color: CrewColors.textPrimary),
          ),
          child: child,
        );
  }

  Widget _card(CrewEvidenceSlot slot) {
    final local = _pending[slot.id];
    final editable =
        !_busy && !widget.busy && crewEvidenceEditable(widget.workflow, slot);
    final hasLocal = local != null;
    final status =
        hasLocal
            ? 'Pendiente de subir'
            : slot.persisted
            ? 'Completado'
            : 'Pendiente';

    return Card(
      key: ValueKey('evidence-card-${slot.code}'),
      color: Colors.white,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    crewEvidenceLabels[slot.code]!,
                    softWrap: true,
                    style: const TextStyle(
                      color: CrewColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _badge(status, pending: hasLocal || !slot.persisted),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _evidenceDescription(slot.code),
              style: const TextStyle(
                color: CrewColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            if (slot.persisted)
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final file in slot.files) _savedFile(slot, file),
                    ],
                  ),
                ),
              ),
            if (local != null) ...[
              _preview(
                key: 'pending-${slot.id}',
                child: Image.file(
                  local,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, _, _) => const Text('Vista previa no disponible.'),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _fileName(local),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: CrewColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _fileSize(_pendingSizes[slot.id]),
                style: const TextStyle(color: CrewColors.textSecondary),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder:
                    (context, constraints) =>
                        constraints.maxWidth < 430
                            ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _actionButton(
                                  label: 'Cambiar foto',
                                  onPressed:
                                      editable
                                          ? () =>
                                              _select(slot, ImageSource.gallery)
                                          : null,
                                  primary: false,
                                ),
                                _actionButton(
                                  label: 'Eliminar',
                                  onPressed:
                                      editable
                                          ? () => setState(() {
                                            _pending.remove(slot.id);
                                            _pendingSizes.remove(slot.id);
                                          })
                                          : null,
                                  primary: false,
                                ),
                                _actionButton(
                                  label: 'Subir evidencia',
                                  icon: Icons.cloud_upload_outlined,
                                  onPressed:
                                      editable ? () => _upload(slot) : null,
                                  primary: true,
                                ),
                              ],
                            )
                            : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _actionButton(
                                  label: 'Cambiar foto',
                                  onPressed:
                                      editable
                                          ? () =>
                                              _select(slot, ImageSource.gallery)
                                          : null,
                                  primary: false,
                                ),
                                _actionButton(
                                  label: 'Eliminar',
                                  onPressed:
                                      editable
                                          ? () => setState(() {
                                            _pending.remove(slot.id);
                                            _pendingSizes.remove(slot.id);
                                          })
                                          : null,
                                  primary: false,
                                ),
                                _actionButton(
                                  label: 'Subir evidencia',
                                  icon: Icons.cloud_upload_outlined,
                                  onPressed:
                                      editable ? () => _upload(slot) : null,
                                  primary: true,
                                ),
                              ],
                            ),
              ),
            ],
            if (!hasLocal && !slot.persisted) ...[
              const SizedBox(height: 8),
              const Text(
                'Agrega una fotografía para completar este requisito.',
                style: TextStyle(color: CrewColors.textSecondary),
              ),
            ],
            if (!hasLocal) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _actionButton(
                    label: 'Cámara',
                    onPressed:
                        editable
                            ? () => _select(slot, ImageSource.camera)
                            : null,
                    primary: false,
                  ),
                  _actionButton(
                    label: 'Galería',
                    onPressed:
                        editable
                            ? () => _select(slot, ImageSource.gallery)
                            : null,
                    primary: false,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _savedFile(CrewEvidenceSlot slot, Map<String, dynamic> file) {
    final rawUrl = '${file['file_url'] ?? file['url'] ?? ''}'.trim();
    final uri = Uri.tryParse(rawUrl);
    final url =
        uri != null &&
                (uri.scheme == 'https' || uri.scheme == 'http') &&
                uri.host.isNotEmpty
            ? rawUrl
            : '';
    final name =
        '${file['original_name'] ?? file['filename'] ?? '${file['file_path'] ?? ''}'.split('/').last}';
    final mime =
        '${file['file_type'] ?? file['mime_type'] ?? ''}'.toLowerCase();
    final isImage =
        mime.startsWith('image/') ||
        (mime.isEmpty &&
            RegExp(
              r'\.(jpe?g|png|webp|gif)$',
              caseSensitive: false,
            ).hasMatch(name));
    Widget photo() =>
        url.isEmpty || !isImage
            ? const Center(child: Text('Vista previa no disponible'))
            : Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder:
                  (context, child, progress) =>
                      progress == null
                          ? child
                          : const Center(child: CircularProgressIndicator()),
              errorBuilder:
                  (_, _, _) => const Center(
                    child: Text(
                      'No se pudo cargar la evidencia. Actualiza el vuelo para renovar su enlace.',
                    ),
                  ),
            );
    void open() {
      showDialog<void>(
        context: context,
        builder:
            (context) => Dialog(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .8,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('${crewEvidenceLabels[slot.code]} — $name'),
                    ),
                    Expanded(child: InteractiveViewer(child: photo())),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              ),
            ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _preview(key: 'saved-${slot.id}-${file['file_path']}', child: photo()),
        Text(
          name.isEmpty ? 'Evidencia' : name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: CrewColors.textPrimary),
        ),
        TextButton(
          onPressed: url.isEmpty ? null : open,
          style: TextButton.styleFrom(foregroundColor: CrewColors.gold),
          child: const Text('Ver evidencia'),
        ),
      ],
    );
  }

  String _evidenceDescription(String code) {
    switch (code) {
      case 'catering_received':
        return 'Toma o sube foto del catering recibido.';
      case 'baggage_secured':
        return 'Toma o sube foto del equipaje asegurado.';
      case 'cabin_condition':
        return 'Toma o sube foto del estado final de cabina.';
      default:
        return 'Agrega una evidencia fotográfica para el cierre.';
    }
  }
}
