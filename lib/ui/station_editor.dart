import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/station.dart';
import '../core/services/station_repository.dart';

/// Diálogo para cadastrar uma rádio pelo endereço ou editar os endereços de uma favorita.
class StationEditor extends StatefulWidget {
  const StationEditor({super.key, this.station});

  final Station? station;

  static Future<void> show(BuildContext context, {Station? station}) {
    return showDialog(context: context, builder: (_) => StationEditor(station: station));
  }

  @override
  State<StationEditor> createState() => _StationEditorState();
}

class _StationEditorState extends State<StationEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.station?.name);
  late final _url = TextEditingController(text: widget.station?.streamUrl);
  late final _fallback = TextEditingController(text: widget.station?.fallbackUrl);

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _fallback.dispose();
    super.dispose();
  }

  String? _validateUrl(String? v, {bool required = true}) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return required ? 'Informe o endereço' : null;
    final uri = Uri.tryParse(s);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) {
      return 'Endereço precisa começar com http:// ou https://';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final fallback = _fallback.text.trim();
    final old = widget.station;
    final station = old == null
        ? Station(
            id: 'manual-${DateTime.now().millisecondsSinceEpoch}',
            name: _name.text.trim(),
            streamUrl: _url.text.trim(),
            fallbackUrl: fallback.isEmpty ? null : fallback,
            manual: true,
          )
        : old.copyWith(
            name: _name.text.trim(),
            streamUrl: _url.text.trim(),
            fallbackUrl: fallback.isEmpty ? null : fallback,
            clearFallback: fallback.isEmpty,
          );
    await context.read<StationRepository>().save(station);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.station == null ? 'Adicionar rádio' : 'Editar rádio'),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (v) => (v?.trim().isEmpty ?? true) ? 'Informe o nome' : null,
              ),
              TextFormField(
                controller: _url,
                decoration: const InputDecoration(labelText: 'Endereço do stream'),
                keyboardType: TextInputType.url,
                validator: _validateUrl,
              ),
              TextFormField(
                controller: _fallback,
                decoration: const InputDecoration(
                  labelText: 'Endereço reserva (opcional)',
                  helperText: 'Qualidade menor. O app troca sozinho\nse o principal ficar cortando.',
                  helperMaxLines: 2,
                ),
                keyboardType: TextInputType.url,
                validator: (v) => _validateUrl(v, required: false),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _save, child: const Text('Salvar')),
      ],
    );
  }
}
