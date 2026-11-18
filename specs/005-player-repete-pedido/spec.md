# Especificação 005 — Rede travada não faz a música voltar no tempo

**Status:** implementada em 18/11/2026, aguardando validação no aparelho

## Contexto
Registro de diagnóstico enviado pelo autor em 18/11/2026:

```
09:40:00  --- Spoon Radio ---
09:40:02  rádio: conectou (audio/mpeg)
09:40:02  player: abre em -0s (play na rádio)
09:49:00  rádio: conexão caiu (estava recebendo): TimeoutException ... No stream event
09:49:04  rádio: reconectou e emendou sem perda
09:49:51  vigia: atraso de 45s no ao vivo, corrigindo
09:49:51  player: abre em -7s (ao vivo)
```

O áudio atrasou sozinho logo depois da reconexão e voltou ao ao vivo 47 s
depois, com o telefone bloqueado. É o mesmo defeito do "voltou 15 minutos" de
13/11 e do "atrasa e volta o tempo todo" do pedal.

## História de usuário
Como ouvinte, quero que uma travada de rede nunca me faça ouvir de novo algo
que já tocou.

**Aceite:**
1. Depois de uma travada, a música continua do ponto em que parou.
2. O atraso mostrado acompanha o que de fato está tocando.
3. Os dois itens acima têm teste automatizado reproduzindo o registro acima.

## Requisitos funcionais (RF)
| Código | Requisito |
|---|---|
| RF-036 | Quando o player repete o pedido do mesmo endereço sem dizer de onde continuar, o servidor local continua de onde parou de entregar |
| RF-037 | O momento ouvido soma só avanços normais do player; recomeço da contagem do player não congela nem volta o relógio |
| RF-038 | O servidor local percebe na hora quando o player larga a conexão e não conta como entregue áudio que o player não recebeu |
