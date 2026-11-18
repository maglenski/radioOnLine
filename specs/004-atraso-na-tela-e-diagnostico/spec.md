# Especificação 004 — Barra de tempo estável, diagnóstico e novo visual da barra

**Status:** implementada em 18/11/2026, aguardando validação no aparelho

## Contexto
Relato do autor (18/11/2026): pedalando com 5G, na volta a tela ficava o tempo
todo "atrasando e voltando para o ao vivo sozinha"; só parou com stop e
fechando o app. Ao abrir o app e dar play, a barra ficou indo um pouco para
trás e voltando, várias vezes, até parar. A troca de rede em si não falhou.

## Histórias de usuário

### História 1 — A barra só se move quando o ouvinte se move (prioridade 1)
**Aceite:**
1. Fora do ao vivo (depois de uma pausa ou de voltar no tempo), o atraso
   mostrado fica estável; não oscila com a qualidade do sinal.
2. O aviso AO VIVO não fica alternando com "ir para o ao vivo".

### História 2 — Diagnóstico para defeito que só acontece na rua (prioridade 1)
Como autor, quero mandar o que o app registrou quando algo estranho acontecer,
para a causa ser encontrada sem adivinhação.

**Aceite:**
1. O app guarda os últimos 400 eventos do motor de áudio, com horário:
   conexão, queda, reconexão (com ou sem emenda), pausa, play, interrupção do
   sistema, fone desconectado, erro do player, correção automática de atraso e
   cada reposicionamento do player com o motivo.
2. Uma tela "Diagnóstico", aberta pelo ícone no topo do player, mostra os
   eventos e copia tudo com um toque.
3. Os eventos ficam só na memória do app e somem ao fechá-lo.

### História 3 — Barra no estilo pedido (prioridade 2)
**Aceite:** canaleta cinza clara arredondada, preenchimento em degradê azul e
botão redondo metálico, conforme a imagem de referência enviada pelo autor.

## Requisitos funcionais (RF)
| Código | Requisito | História |
|---|---|---|
| RF-032 | O atraso mostrado é medido contra o relógio, não contra a chegada do último pedaço de áudio | 1 |
| RF-033 | Diário de eventos do motor de áudio em memória (400 eventos) | 2 |
| RF-034 | Tela de diagnóstico com cópia para a área de transferência | 2 |
| RF-035 | Novo visual da barra de volta no tempo | 3 |
