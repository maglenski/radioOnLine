# Plano técnico 001 — Player de rádio online com volta no tempo

Atende: [spec.md](spec.md) · Princípios: [constituição](../../.specify/memory/constitution.md)

## Tecnologia
| Item | Escolha | Por quê |
|---|---|---|
| Linguagem / UI | Flutter + Dart | Um código para Android e iOS |
| Player | `just_audio` (ExoPlayer no Android) | Maduro, aceita stream sem fim |
| Segundo plano | `audio_service` | Notificação, tela de bloqueio, botões do fone |
| Sessão de áudio | `audio_session` | Pausa com fone desconectado, ligações |
| Estado | `provider` + `ValueNotifier` | Suficiente para o tamanho do app (princípio 7) |
| Persistência | `shared_preferences` (JSON) | Só favoritas e última rádio |
| Catálogo | API Radio Browser | Aberto, sem chave (princípio 3) |
| Capas | iTunes Search API | Pública, sem chave |

## Arquitetura

```
 Rádio (Icecast/SHOUTcast)
        │ HTTP + Icy-MetaData
        ▼
 ┌──────────────┐  título  ┌──────────────────┐
 │ StreamRelay  │─────────▶│ RadioAudioHandler│──▶ notificação / tela de bloqueio
 │ reconecta,   │          │ (audio_service)  │──▶ interface (PlaybackSnapshot)
 │ troca reserva│          └───────┬──────────┘
 └──────┬───────┘                  │ setAudioSource(127.0.0.1:porta/stream?from=N)
        │ áudio limpo              ▼
        ▼                    ┌──────────────┐
 ┌──────────────┐  bytes     │  just_audio  │
 │TimeshiftBuffer│◀──────────│  (ExoPlayer) │
 │ 30 min, disco │  ┌────────┴──────────────┘
 └──────┬───────┘  │ HTTP local
        └─────────▶│ LocalStreamServer
                   └────────────────────────
```

**Ideia central:** o player nunca fala com a rádio. O `StreamRelay` recebe o
áudio, tira os metadados e grava no `TimeshiftBuffer`; o `LocalStreamServer`
entrega ao player o áudio a partir de qualquer posição. Consequências:

1. **Queda de rede não chega ao player** (RF-004, RF-005): o relay reconecta
   enquanto o player toca o que já está gravado. Esse é o defeito do app oficial
   da rádio que motivou o projeto.
2. **Volta no tempo é só mudar a posição de leitura** (RF-009): voltar 10 minutos
   = abrir `stream?from=<posição de 10 min atrás>`.
3. **Pausa grava** (RF-010): ao pausar, o relay continua recebendo; ao tocar,
   o player reabre na posição exata em que parou.
4. **Troca para o reserva sem parar** (RF-014): o relay troca de endereço e
   continua escrevendo no mesmo buffer. Se o formato mudar (MP3 ↔ AAC), o buffer
   é zerado e o player reabre.

### Componentes (`lib/`)
| Arquivo | Responsabilidade | Requisitos |
|---|---|---|
| `audio/icy_demuxer.dart` | Separa áudio e título do stream ICY | RF-002 |
| `audio/timeshift_buffer.dart` | Buffer em segmentos de 256 KB no disco; posição ↔ horário | RF-008 |
| `audio/stream_relay.dart` | Conexão, reconexão com espera crescente, travamento, reserva, playlists, detecção de HLS | RF-004, 005, 011, 013, 014 |
| `audio/local_stream_server.dart` | HTTP em 127.0.0.1 que serve o buffer a partir de uma posição | RF-009, 010 |
| `audio/radio_audio_handler.dart` | Junta tudo; controles do sistema; timer; capa | RF-003, 006, 007, 009, 010, 015, 017 |
| `core/services/radio_browser_client.dart` | Busca com servidores espelho e troca automática | RF-001, 016 |
| `core/services/artwork_service.dart` | Capa pelo título | RF-003 |
| `core/services/station_repository.dart` | Favoritas e última rádio | RF-012 |
| `ui/…` | Telas: favoritas, busca, player, mini player, cadastro | todos |

### Decisões e alternativas descartadas
- **Gravação própria em vez de cache do player:** o cache do `just_audio`
  (`LockCachingAudioSource`) foi feito para arquivos com tamanho conhecido, não
  para stream infinito, e não permite voltar no tempo de forma controlada.
- **Servidor HTTP local em vez de `StreamAudioSource`:** o servidor local é o
  caminho mais estável no ExoPlayer para stream sem fim e funciona igual no iOS.
- **Formato:** o buffer guarda os bytes como vieram (MP3 ou AAC/ADTS). Os dois
  formatos são sequências de quadros independentes, então o player se
  ressincroniza depois de uma emenda de reconexão.
- **HLS** (`.m3u8`) é dividido em pedaços com playlist própria; gravar exigiria
  outra arquitetura. Nesta versão toca direto, sem volta no tempo (RF-011).
- **`package:flutter/material.dart`** mesmo marcado como obsoleto no Flutter
  3.47+, para o projeto compilar também em instalações do Flutter um pouco
  mais antigas. Migrar para `material_ui` quando todas estiverem atualizadas.

## Riscos
| Risco | Mitigação |
|---|---|
| Emenda de reconexão gera um estalo curto | Aceitável; o player ressincroniza no quadro seguinte |
| Android mata o app em segundo plano | Serviço em primeiro plano do `audio_service` |
| Servidor SHOUTcast v1 responde `ICY 200 OK` (não é HTTP válido) | Detectado → toca direto (RF-011) |
| Catálogo fora do ar | Lista de espelhos com troca automática; cadastro manual continua funcionando |
| Alta qualidade da Spoon corta no WiFi de casa | Reserva automática (RF-014); ver [research.md](research.md) |
