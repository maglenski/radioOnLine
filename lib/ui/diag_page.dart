import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/services/diag_log.dart';
import 'app.dart';

/// Mostra o diário de bordo do motor de áudio e copia para enviar.
class DiagPage extends StatelessWidget {
  const DiagPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DiagPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnóstico', style: TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            tooltip: 'Limpar',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: DiagLog.clear,
          ),
          IconButton(
            tooltip: 'Copiar tudo',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: DiagLog.dump()));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Diagnóstico copiado')),
                );
              }
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: DiagLog.revision,
        builder: (context, _, _) {
          final entries = DiagLog.entries.reversed.toList();
          if (entries.isEmpty) {
            return const Center(
              child: Text('Nenhum evento ainda', style: TextStyle(color: AppColors.textMuted)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: entries.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                entries[i],
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          );
        },
      ),
    );
  }
}
