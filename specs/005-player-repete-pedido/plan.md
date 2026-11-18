# Plano técnico 005

Atende: [spec.md](spec.md)

## Causa (confirmada no código-fonte do player do Android, Media3/ExoPlayer)
1. A rádio ficou muda por ~9 s (09:48:55 a 09:49:04). Nesse tempo o servidor
   local também não tinha nada para entregar ao player.
2. O player do Android desiste de uma conexão sem dados depois de 8 s.
3. Numa rádio ao vivo (tamanho desconhecido), o `ProgressiveMediaPeriod` do
   Media3 trata esse erro com "retentativa adiada": toca o que já tem e então
   **pede o mesmo endereço desde o byte zero**, sem cabeçalho `Range`, e zera a
   contagem de posição.
4. O servidor local entregava a partir do ponto em que o player foi aberto
   (09:40:02) → a música voltou 9 minutos. Em 13/11, sem relógio protegido, o
   app achou que estava 15 minutos atrás.
5. Desde a especificação 002 a posição só podia crescer; com a contagem do
   player zerada, o momento ouvido congelou, o atraso cresceu 1 s por segundo e
   o vigia de 45 s puxou para o ao vivo às 09:49:51.

A correção de `Range` da especificação 002 não cobria isto: o player não manda
`Range` nesse caminho.

## Solução
- `local_stream_server.dart`: guarda até onde cada endereço foi entregue;
  pedido repetido sem `Range` continua dali. Passa a escrever em conexão crua
  para perceber quando o player larga a conexão.
- `listening_clock.dart` (novo): relógio do momento ouvido que soma só avanços
  entre 0 e 60 s; saltos não pedidos são ignorados.
- `radio_audio_handler.dart`: usa o relógio novo.

## Testes
- `listening_clock_test.dart` (novo): reproduz o registro (9 min tocando,
  contagem zerada, 50 s depois) — falha com o código anterior.
- `network_change_test.dart`: imita o player do Android lendo até travar e
  repetindo o pedido sem `Range` — sem a correção, recebe o áudio desde o
  início (35 000 bytes em vez de 5 000).

## Limite
O player do Android continua desistindo da conexão após 8 s sem dados (não é
configurável pelo just_audio). Agora isso só causa um engasgo curto, sem
voltar no tempo.
