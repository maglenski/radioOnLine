# Especificação 002 — Troca de rede sem atraso e sem travar os controles

**Status:** aprovada pelo autor em 14/11/2026 · implementada, aguardando validação no aparelho · **Data:** 14/11/2026

## Contexto
Em uso real (13 e 14/11/2026) a versão 1.0 mostrou três defeitos, todos ligados a
troca de rede: de um repetidor WiFi para outro dentro de casa e do WiFi para o 5G.

1. A música engasga feio na troca de rede.
2. Depois do engasgo a programação fica atrasada sozinha (de alguns minutos até
   15 minutos), sem o ouvinte ter voltado no tempo.
3. Às vezes, depois do engasgo, os botões de voltar/avançar e a barra ficam
   inoperantes e não há como retornar ao ao vivo sem reiniciar o app.

Restrição do autor: resolver sem acrescentar espera na partida (nada de "carregar
30 segundos antes de tocar").

## Histórias de usuário

### História 1 — Trocar de rede sem perder o ao vivo (prioridade 1)
Como ouvinte no ao vivo, quero que uma troca de rede não me deixe ouvindo a
programação atrasada.

**Aceite:**
1. Queda curta (a rádio ainda reenvia o trecho perdido): a música continua do
   ponto exato, sem repetir e sem pular trecho.
2. Queda longa (o trecho perdido não volta mais): a música retoma no ao vivo.
   O trecho que foi ao ar durante a queda é perdido — é ao vivo.
3. Em nenhum dos casos o atraso em relação ao ao vivo cresce sem o ouvinte pedir.
4. Se mesmo assim o atraso no ao vivo passar de 45 segundos, o app corrige sozinho.

### História 2 — Engasgo menor (prioridade 1)
**Aceite:**
1. O app percebe a conexão morta em até 5 segundos (antes: 12) e tenta
   reconectar na hora.
2. Trocas de rede que se resolvem em poucos segundos não são ouvidas: a folga
   de áudio já recebido cobre o intervalo.
3. Nenhuma espera é acrescentada ao dar play numa rádio.

### História 3 — Controles sempre funcionam (prioridade 1)
**Aceite:**
1. Depois de qualquer queda, voltar, avançar, a barra e "ir para o ao vivo"
   continuam funcionando.
2. A tela só mostra AO VIVO quando o ouvinte está de fato no ao vivo.
3. Numa queda longa (elevador, garagem) o app continua tentando até a rede
   voltar, sem exigir novo play.

### História 4 — Quem voltou no tempo não é incomodado (prioridade 2)
**Aceite:** se o ouvinte está ouvindo algo de minutos atrás, uma troca de rede
não muda o ponto em que ele está.

### História 5 — Troca de rede não rebaixa a qualidade (prioridade 2)
**Aceite:** tentativas de conexão que falham por falta de rede não contam para
a troca automática para o endereço reserva; só conta queda de um stream que
estava chegando ou recusa do servidor.

## Requisitos funcionais (RF)
| Código | Requisito | História |
|---|---|---|
| RF-018 | Emendar o áudio da reconexão no áudio já gravado, descartando a repetição | 1 |
| RF-019 | Sem emenda possível, quem está no ao vivo retoma a partir do áudio novo | 1 |
| RF-020 | Correção automática se o atraso no ao vivo passar de 45 s | 1 |
| RF-021 | Detectar conexão morta em 5 s; primeira reconexão imediata; espera máxima de 5 s entre tentativas | 2 |
| RF-022 | Ao ir para o ao vivo, manter 8 s de folga de áudio já gravado | 2 |
| RF-023 | A posição de escuta não pode retroceder por erro do player | 3 |
| RF-024 | Retentar sem limite enquanto a rádio está reconectando | 3 |
| RF-025 | Pausar tira o ouvinte do ao vivo (o atraso passa a aparecer) | 3 |
| RF-026 | Falha por falta de rede não conta para a troca de qualidade | 5 |

## Limite conhecido
Sem buffer de partida não existe engasgo zero: se a rede ficar fora por mais
tempo que a folga de áudio já recebido (alguns segundos), a música para até a
rede voltar. O que esta especificação garante é que ela volta sozinha, no ao
vivo e com os controles funcionando.

## Critérios de sucesso (validação no aparelho)
- Andar pela casa trocando de repetidor por 10 minutos: no máximo pausas curtas,
  nunca atraso acumulado, controles funcionando.
- Sair de casa (WiFi → 5G): pausa curta e retomada no ao vivo.
- Voltar 5 minutos, trocar de rede: continua nos mesmos 5 minutos de atraso.
