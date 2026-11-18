import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../audio/radio_audio_handler.dart';
import '../core/services/station_repository.dart';
import 'app.dart';
import 'diag_page.dart';
import 'station_actions.dart';
import 'widgets/mini_player.dart' show formatDuration;
import 'widgets/station_art.dart';
import 'widgets/timeshift_slider.dart';

/// Tela cheia do player, com a barra de volta no tempo (até 30 minutos).
class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PlayerPage()));
  }

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  /// Valor da barra enquanto o dedo está arrastando (segundos atrás do ao vivo).
  double? _dragDelay;

  @override
  Widget build(BuildContext context) {
    final handler = context.read<RadioAudioHandler>();
    final repo = context.watch<StationRepository>();

    return ValueListenableBuilder<PlaybackSnapshot>(
      valueListenable: handler.state,
      builder: (context, s, _) {
        final station = s.station;
        if (station == null) return const Scaffold();
        final fav = repo.favoriteById(station.id);
        final hasFallback = (fav ?? station).fallbackUrl != null;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(station.name, style: const TextStyle(fontSize: 16)),
            actions: [
              IconButton(
                tooltip: 'Diagnóstico',
                icon: const Icon(Icons.monitor_heart_outlined),
                onPressed: () => DiagPage.open(context),
              ),
            ],
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, box) {
                // Altura que os textos e controles ocupam; a capa fica com o que sobrar.
                final reserved = s.direct ? 300.0 : 380.0;
                final artSize = (box.maxHeight - reserved).clamp(
                  96.0,
                  (box.maxWidth - 48).clamp(96.0, 340.0),
                );
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const Spacer(),
                      StationArt(
                        url: s.artUrl ?? station.faviconUrl,
                        size: artSize,
                        radius: 20,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        s.songTitle ?? station.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _subtitle(s),
                        style: TextStyle(
                          color: s.error != null
                              ? AppColors.live
                              : AppColors.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Spacer(),
                      if (!s.direct) _timeshiftBar(handler, s),
                      const SizedBox(height: 12),
                      _controls(handler, s),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _SleepButton(
                            handler: handler,
                            remaining: s.sleepRemaining,
                          ),
                          IconButton(
                            tooltip: fav != null
                                ? 'Remover das favoritas'
                                : 'Favoritar',
                            icon: Icon(
                              fav != null
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: fav != null ? AppColors.accent : null,
                            ),
                            onPressed: () =>
                                StationActions.toggleFavorite(context, station),
                          ),
                          if (hasFallback)
                            _QualityButton(
                              usingFallback: s.usingFallback,
                              onChanged: handler.setFallback,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  String _subtitle(PlaybackSnapshot s) {
    if (s.error != null) return s.error!;
    if (s.reconnecting) {
      return 'Conexão caiu, reconectando… (a música segue do que já foi gravado)';
    }
    if (s.loading) return 'Conectando…';
    final parts = <String>[
      if (s.songTitle != null) s.station!.name,
      if (s.direct) 'sem gravação nesta rádio',
      if (s.usingFallback) 'qualidade reserva',
    ];
    return parts.join(' · ');
  }

  Widget _timeshiftBar(RadioAudioHandler handler, PlaybackSnapshot s) {
    final max = s.buffered.inSeconds.toDouble();
    final delay = (_dragDelay ?? s.delay.inSeconds.toDouble()).clamp(0.0, max);
    return Column(
      children: [
        TimeshiftSliderTheme(
          child: Slider(
            // A barra vai de "mais antigo gravado" (esquerda) até "ao vivo" (direita).
            min: max <= 0 ? -1.0 : -max,
            max: 0.0,
            value: -delay,
            onChanged: max <= 0 ? null : (v) => setState(() => _dragDelay = -v),
            onChangeEnd: (v) {
              setState(() => _dragDelay = null);
              handler.seekToDelay(Duration(seconds: (-v).round()));
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                '-${formatDuration(Duration(seconds: max.round()))}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              s.isLive && _dragDelay == null
                  ? const _LiveBadge()
                  : TextButton.icon(
                      onPressed: handler.goLive,
                      icon: const Icon(
                        Icons.fiber_manual_record,
                        size: 12,
                        color: AppColors.live,
                      ),
                      label: Text(
                        '-${formatDuration(Duration(seconds: delay.round()))}  ·  ir para o ao vivo',
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _controls(RadioAudioHandler handler, PlaybackSnapshot s) {
    final canShift = !s.direct && s.buffered > Duration.zero;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          iconSize: 40,
          tooltip: 'Voltar 30 segundos',
          icon: const Icon(Icons.replay_30_rounded),
          onPressed: canShift
              ? () => handler.jumpBack(RadioAudioHandler.rewindStep)
              : null,
        ),
        SizedBox(
          width: 84,
          height: 84,
          child: s.loading
              ? const Padding(
                  padding: EdgeInsets.all(18),
                  child: CircularProgressIndicator(strokeWidth: 4),
                )
              : IconButton.filled(
                  iconSize: 48,
                  icon: Icon(
                    s.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                  onPressed: s.playing ? handler.pause : handler.play,
                ),
        ),
        IconButton(
          iconSize: 40,
          tooltip: 'Avançar 30 segundos',
          icon: const Icon(Icons.forward_30_rounded),
          onPressed: canShift && !s.isLive
              ? () => handler.jumpForward(RadioAudioHandler.rewindStep)
              : null,
        ),
      ],
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.live.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fiber_manual_record, size: 10, color: AppColors.live),
          SizedBox(width: 6),
          Text(
            'AO VIVO',
            style: TextStyle(
              color: AppColors.live,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _QualityButton extends StatelessWidget {
  const _QualityButton({required this.usingFallback, required this.onChanged});

  final bool usingFallback;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => onChanged(!usingFallback),
      icon: Icon(
        usingFallback
            ? Icons.signal_cellular_alt_1_bar_rounded
            : Icons.high_quality_rounded,
      ),
      label: Text(usingFallback ? 'Reserva' : 'Alta'),
    );
  }
}

class _SleepButton extends StatelessWidget {
  const _SleepButton({required this.handler, required this.remaining});

  final RadioAudioHandler handler;
  final Duration? remaining;

  static const _options = [15, 30, 45, 60, 90];

  @override
  Widget build(BuildContext context) {
    final active = remaining != null;
    return TextButton.icon(
      icon: Icon(
        Icons.bedtime_rounded,
        color: active ? AppColors.accent : null,
      ),
      label: Text(active ? formatDuration(remaining!) : 'Timer'),
      onPressed: () => showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.surface,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Desligar em',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              for (final m in _options)
                ListTile(
                  title: Text('$m minutos'),
                  onTap: () {
                    handler.setSleepTimer(Duration(minutes: m));
                    Navigator.pop(ctx);
                  },
                ),
              if (active)
                ListTile(
                  title: const Text(
                    'Cancelar timer',
                    style: TextStyle(color: AppColors.live),
                  ),
                  onTap: () {
                    handler.setSleepTimer(null);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
