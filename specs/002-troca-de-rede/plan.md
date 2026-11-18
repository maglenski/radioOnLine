# Plano técnico 002 — Troca de rede

Atende: [spec.md](spec.md)

## Diagnóstico (revisão do código da versão 1.0)
| # | Causa | Efeito observado | Arquivo |
|---|---|---|---|
| 1 | Na troca de rede a conexão não cai, só silencia; o app esperava 12 s para declarar a conexão morta | Engasgo longo | `audio/stream_relay.dart` |
| 2 | Ao reconectar, a rádio reenvia os últimos segundos que já foram ao ar e o app gravava esse reenvio depois do que já tinha: trecho repetido, e cada reconexão empurrava o ouvinte para trás | Engasgo "feio" e atraso que cresce | `audio/stream_relay.dart` |
| 3 | O app calculava o ponto de escuta pela posição informada pelo player. Quando o player dá erro (ficou mais de 8 s sem receber áudio), ele passa a informar posição zero; o app então reabria no começo da sessão de escuta | Programação volta vários minutos (15 min = tempo desde o play) | `audio/radio_audio_handler.dart` |
| 4 | No ao vivo, qualquer atraso era descontado da tela como "folga natural". Com o atraso do item 3 a tela continuava em AO VIVO, a barra ficava com tamanho zero e os botões desabilitados | Controles inoperantes, sem "ir para o ao vivo" | `audio/radio_audio_handler.dart` |
| 5 | Depois de um erro o player refaz o pedido ao servidor local pedindo "continue do byte N"; o servidor local ignorava e mandava do início | Risco de retomada no ponto errado em sessões longas | `audio/local_stream_server.dart` |
| 6 | Cinco erros seguidos do player encerravam as tentativas | Queda longa exigia novo play | `audio/radio_audio_handler.dart` |
| 7 | Toda tentativa de conexão falha contava para a troca de qualidade | Troca de rede podia rebaixar para o endereço reserva | `audio/stream_relay.dart` |

Os itens 1, 2, 5 e 7 foram reproduzidos em teste automatizado com rádio simulada.
Os itens 3, 4 e 6 dependem do player do Android e foram identificados por
leitura do código; a confirmação é a validação no aparelho.

## Solução
- **Emendador (`StreamSplicer`)** — RF-018/019: na reconexão ao mesmo endereço,
  segura os primeiros bytes (no máximo 2,5 s ou 768 KB), procura neles os
  últimos 2 KB já gravados e grava só o que vem depois. Achou: continuidade
  perfeita. Não achou: grava tudo e avisa a posição da quebra; quem está no
  ao vivo é reaberto nessa posição.
- **Relay** — RF-021/026: silêncio de 5 s = conexão morta; primeira tentativa
  imediata, depois 0,5 s, 1 s, 2 s, 4 s, 5 s; só queda de stream ativo ou
  resposta de erro do servidor conta para o endereço reserva.
- **Controlador** — RF-020/022/023/024/025: posição só é aceita depois que a
  fonte abriu e nunca retrocede; erro no ao vivo retoma no ao vivo; retentativa
  sem limite enquanto a rádio reconecta; folga de 8 s ao ir para o ao vivo;
  vigia de 45 s; pausa sai do ao vivo.
- **Servidor local** — item 5: respeita o cabeçalho `Range`.

## Alternativas descartadas
- **Buffer de partida de 30 s (como o TuneIn):** resolveria o engasgo, mas
  atrasa todo play. Recusado pelo autor.
- **Detectar a troca de rede pelo sistema (pacote connectivity_plus):** reagiria
  mais rápido que os 5 s, mas acrescenta dependência nativa. Fica como evolução
  se a validação mostrar que 5 s ainda é muito.

## Arquivos alterados
`lib/audio/stream_relay.dart`, `lib/audio/radio_audio_handler.dart`,
`lib/audio/local_stream_server.dart`, `lib/audio/timeshift_buffer.dart`,
novo `test/network_change_test.dart`. Nenhuma tela muda.
