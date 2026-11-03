import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme.dart';
import '../services/reports_api.dart';

Future<void> showReportSheet(
  BuildContext context,
  String place,
  double lat,
  double lon, {
  VoidCallback? onDone,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ReportSheet(
        host: context, place: place, lat: lat, lon: lon, onDone: onDone),
  );
}

class _ReportSheet extends StatefulWidget {
  final BuildContext host;
  final String place;
  final double lat, lon;
  final VoidCallback? onDone;
  const _ReportSheet({
    required this.host,
    required this.place,
    required this.lat,
    required this.lon,
    this.onDone,
  });

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _size;
  Uint8List? _photo;
  bool _sending = false;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource src) async {
    try {
      final x = await ImagePicker()
          .pickImage(source: src, maxWidth: 1080, imageQuality: 75);
      if (x == null) return;
      final b = await x.readAsBytes();
      if (mounted) setState(() => _photo = b);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No se pudo abrir la cámara o la galería.')));
      }
    }
  }

  Future<void> _send() async {
    final size = _size;
    if (size == null) return;
    setState(() => _sending = true);
    final msg = await ReportsApi.submit(
      place: widget.place,
      lat: widget.lat,
      lon: widget.lon,
      size: size,
      photo: _photo,
      note: _note.text,
    );
    widget.onDone?.call();
    if (mounted) Navigator.pop(context);
    if (widget.host.mounted) {
      ScaffoldMessenger.of(widget.host)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('¿Cae granizo?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Elegí el tamaño', style: TextStyle(color: context.muted)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in hailSizes.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _size == e.key,
                    onSelected: (_) => setState(() => _size = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            if (_photo == null)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pick(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Sacar foto'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Galería'),
                    ),
                  ),
                ],
              )
            else
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(_photo!,
                        height: 170, width: double.infinity, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: IconButton.filled(
                      onPressed: () => setState(() => _photo = null),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 14),
            TextField(
              controller: _note,
              maxLength: 140,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Detalle opcional (ej: no rompió nada duro)',
                border: OutlineInputBorder(),
              ),
            ),
            Text(
              'La foto se achica y se le borran los datos de ubicación. La ven los vecinos '
              'cercanos por 24 horas. No saques fotos de personas.',
              style: TextStyle(fontSize: 13, height: 1.4, color: context.muted),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: (_size == null || _sending) ? null : _send,
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54)),
              child: _sending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Text('Enviar reporte',
                      style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
