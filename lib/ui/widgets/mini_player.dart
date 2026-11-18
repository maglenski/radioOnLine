import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../audio/radio_audio_handler.dart';
import '../app.dart';
import '../player_page.dart';
import 'station_art.dart';

/// Barra fixa acima do menu com a rádio atual.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final handler = context.read<RadioAudioHandler>();
    return ValueListenableBuilder<PlaybackSnapshot>(
      valueListenable: handler.state,
      builder: (context, s, _) {
        final station = s.station;
        if (station == null) return const SizedBox.shrink();
        return Material(
          color: AppColors.surfaceHigh,
          child: InkWell(
            onTap: () => PlayerPage.open(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: [
                  StationArt(url: s.artUrl ?? station.faviconUrl, size: 44, radius: 8),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.songTitle ?? station.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          _statusLine(s),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (s.loading)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  else
                    IconButton(
                      iconSize: 36,
                      color: AppColors.accent,
                      icon: Icon(s.playing ? Icons.pause_circle_filled : Icons.play_circle_fill),
                      onPressed: s.playing ? handler.pause : handler.play,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _statusLine(PlaybackSnapshot s) {
    if (s.error != null) return s.error!;
    if (s.reconnecting) return 'Reconectando…';
    final name = s.songTitle != null ? s.station!.name : '';
    final where = s.direct || s.isLive ? 'Ao vivo' : '-${formatDuration(s.delay)}';
    return [if (name.isNotEmpty) name, where].join(' · ');
  }
}

String formatDuration(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
