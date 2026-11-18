# Especificação 003 — Ligação e pausa sem perder o ponto da música

**Status:** decisão do autor em 14/11/2026 · implementada, aguardando validação no aparelho

## Contexto
Em 14/11/2026, depois de uma ligação de WhatsApp, a programação voltou no tempo,
atrasava de novo após "ir para o ao vivo" e o áudio ficou picotado até em outra
rádio. Antes da ligação estava tudo normal.

## Decisão do autor
Ao terminar a ligação, a rádio **continua de onde parou**, sozinha — não pula
para o ao vivo. Motivo: não perder a música que estava tocando por causa de uma
ligação de spam. Retomar com play manual é aceitável quando a retomada
automática não for possível.

## Histórias de usuário

### História 1 — Ligação pausa e depois continua (prioridade 1)
**Aceite:**
1. Ao entrar uma ligação (ou outro app tomar o áudio), a música pausa e a
   gravação continua.
2. Ao terminar, a música continua sozinha do ponto exato em que parou.
3. A tela mostra o atraso e o botão "ir para o ao vivo".
4. Se outro app ficar com o áudio de vez (ex.: abrir um vídeo), a rádio fica
   pausada e o play manual continua de onde parou.
5. Aviso sonoro curto de outro app (notificação, GPS) só abaixa o volume.

### História 2 — Pausado, o app continua inteiro (prioridade 1)
**Aceite:**
1. Durante a pausa o Android não reduz a rede nem o processamento do app.
2. Depois de qualquer pausa o áudio volta contínuo, sem picotar.

### História 3 — Pausa esquecida não gasta dados (prioridade 2)
**Aceite:** pausado por mais de 30 minutos (o limite da gravação), o app para de
gravar. O próximo play começa no ao vivo.

## Requisitos funcionais (RF)
| Código | Requisito | História |
|---|---|---|
| RF-027 | Interrupção de áudio é tratada como pausa do app, com retomada automática do mesmo ponto | 1 |
| RF-028 | Perda definitiva do áudio para outro app aguarda play manual | 1 |
| RF-029 | Aviso curto de outro app abaixa o volume em vez de pausar | 1 |
| RF-030 | O app permanece como serviço em primeiro plano enquanto pausado | 2 |
| RF-031 | Pausa acima de 30 minutos encerra a gravação | 3 |

## Critérios de sucesso (validação no aparelho)
- Receber uma ligação de WhatsApp no meio de uma música: ao desligar, a música
  continua do mesmo ponto, sem picotar, e "ir para o ao vivo" funciona.
- Pausar por 5 minutos com a tela apagada e dar play: continua do mesmo ponto.
