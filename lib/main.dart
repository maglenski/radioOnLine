import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'audio/radio_audio_handler.dart';
import 'core/services/radio_browser_client.dart';
import 'core/services/station_repository.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final radio = await RadioAudioHandler.create();
  final handler = await AudioService.init(
    builder: () => radio,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'dev.glenski.radio_online.playback',
      androidNotificationChannelName: 'Reprodução',
      // Pausado, o app continua em primeiro plano: a gravação segue e o Android
      // não corta a rede dele (ligação, pausa longa).
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: false,
      androidNotificationIcon: 'drawable/ic_stat_radio',
    ),
  );

  final repository = StationRepository();
  await repository.load();

  runApp(
    MultiProvider(
      providers: [
        Provider<RadioAudioHandler>.value(value: handler),
        ChangeNotifierProvider<StationRepository>.value(value: repository),
        Provider<RadioBrowserClient>(create: (_) => RadioBrowserClient()),
      ],
      child: const RadioApp(),
    ),
  );
}
