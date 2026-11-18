# Plano técnico 004

Atende: [spec.md](spec.md)

## Diagnóstico
**Confirmado por leitura do código:** o atraso mostrado era "horário do último
pedaço de áudio recebido − horário do que está tocando". No 4G/5G (e logo ao
conectar) o áudio chega em rajadas com intervalos de segundos; a cada intervalo
o atraso calculado encolhia e a cada rajada pulava de volta. No ao vivo isso é
escondido (o atraso é fixado em zero). Fora do ao vivo — depois de qualquer
pausa seguida de play — a barra ia e vinha e o aviso alternava entre AO VIVO e
"ir para o ao vivo" quando o valor cruzava 5 segundos. Bate com os dois
relatos: aparece depois de um play que não é "play numa rádio" e some com
stop + play (que recomeça no ao vivo).

**Não confirmado:** se, além da tela, o áudio também saltava. O diário de
eventos (RF-033) existe para responder isso na próxima ocorrência.

## Solução
- `radio_audio_handler.dart`: atraso = agora − horário do que está tocando.
- `core/services/diag_log.dart` (novo): lista em memória com horário.
- `stream_relay.dart` e `radio_audio_handler.dart`: registram os eventos; cada
  chamada que reposiciona o player informa o motivo.
- `ui/diag_page.dart` (novo) e ícone no topo de `ui/player_page.dart`.
- `ui/widgets/timeshift_slider.dart` (novo): desenho próprio da canaleta e do botão.
