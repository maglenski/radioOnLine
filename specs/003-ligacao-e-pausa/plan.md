# Plano técnico 003 — Ligação e pausa

Atende: [spec.md](spec.md)

## Diagnóstico (hipóteses por leitura do código; não reproduzível fora do aparelho)
| # | Causa provável | Efeito observado | Arquivo |
|---|---|---|---|
| 1 | Ao pausar, o app saía do modo "serviço em primeiro plano" (`androidStopForegroundOnPause: true`). Depois da ligação o Android podia continuar tratando o app como app de fundo, com rede e processamento reduzidos | Áudio picotado em qualquer rádio | `lib/main.dart` |
| 2 | A pausa da ligação era feita pelo player, por fora do app. A música voltava atrasada, mas o app ainda se considerava no ao vivo, e a correção automática de atraso (especificação 002) disparava repetidamente | Programação "voltando" e atrasando de novo | `lib/audio/radio_audio_handler.dart` |

## Solução
- `main.dart`: `androidStopForegroundOnPause: false` (e `androidNotificationOngoing: false`, exigido pela biblioteca nessa combinação).
- `radio_audio_handler.dart`: o player deixa de tratar interrupções
  (`handleInterruptions: false`); o app escuta `interruptionEventStream` do
  `audio_session` e usa os próprios `pause()` e `play()`, que já saem do ao vivo
  e reabrem no ponto exato. Temporizador de 30 minutos na pausa chama `stop()`.

## Risco
Se a validação mostrar que o picotado continua depois de uma ligação, a causa 1
não era a única; o próximo passo é coletar o registro do Android (logcat) durante
uma ligação.
