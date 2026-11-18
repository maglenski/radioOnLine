# Especificação 001 — Player de rádio online com volta no tempo

**Status:** implementada na versão 1.0.0 · **Data:** 13/11/2026

## Contexto
O autor ouve rádios online pelo celular (principalmente a Spoon Radio). Os
players atuais falham de três jeitos: a rádio some do catálogo, a conexão cai
depois de algumas músicas e é preciso reconectar na mão, e a qualidade mais alta
corta em algumas redes. Este app resolve isso para uso pessoal.

## Histórias de usuário

### História 1 — Achar e tocar uma rádio (prioridade 1)
Como ouvinte, quero digitar um nome ou gênero ("rock") e ver uma lista de
rádios para tocar com um toque.

**Aceite:**
1. Dada a busca "rock", aparecem rádios cujo nome ou gênero contém "rock",
   mais ouvidas primeiro.
2. Posso limitar a busca a rádios do Brasil.
3. Tocar uma rádio mostra o nome dela e, quando a rádio informa, a música atual.

### História 2 — Ouvir sem cortes (prioridade 1)
Como ouvinte, quero que a música continue mesmo se a internet oscilar.

**Aceite:**
1. Se a conexão cair, o app reconecta sozinho, sem toque do usuário.
2. Durante a reconexão, o que já foi recebido continua tocando.
3. O app continua tocando com a tela apagada e mostra controles na
   notificação e na tela de bloqueio.
4. Ao desconectar o fone, a reprodução pausa.

### História 3 — Voltar no tempo até 30 minutos (prioridade 1)
Como ouvinte, quero voltar para ouvir de novo algo que passou, e depois
retornar ao ao vivo.

**Aceite:**
1. O app guarda os últimos 30 minutos da rádio que está tocando.
2. Posso voltar e avançar de 30 em 30 segundos ou arrastar uma barra.
3. Um botão leva direto ao ao vivo; a tela mostra quanto estou atrasado.
4. Ao pausar, a gravação continua; ao voltar a tocar, continua de onde parei.
5. Rádios que não permitem gravação (formato HLS) tocam normalmente, sem a barra.

### História 4 — Favoritas (prioridade 2)
**Aceite:**
1. Favoritar e desfavoritar pela busca e pelo player.
2. As favoritas ficam salvas no celular e podem ser reordenadas.

### História 5 — Rádio pelo endereço (prioridade 2)
Como ouvinte, quero colar o endereço do stream de uma rádio que não está no
catálogo.

**Aceite:**
1. Cadastro com nome, endereço principal e endereço reserva opcional.
2. Aceita link direto do áudio e playlists `.pls` e `.m3u`.

### História 6 — Qualidade reserva automática (prioridade 2)
Como ouvinte numa rede que não aguenta a qualidade alta de uma rádio, quero
que o app troque sozinho para uma qualidade menor.

**Aceite:**
1. Cada favorita pode ter um endereço reserva.
2. Com 3 quedas em 2 minutos no endereço principal, o app passa para o reserva
   sem parar a música.
3. Posso alternar manualmente entre alta e reserva no player.
4. Ao favoritar uma rádio do catálogo, se existir a mesma rádio com qualidade
   menor, ela vira o reserva automaticamente.

### História 7 — Timer para dormir (prioridade 3)
**Aceite:** escolher 15, 30, 45, 60 ou 90 minutos; ao fim, pausa.

## Requisitos funcionais (RF)
| Código | Requisito | História |
|---|---|---|
| RF-001 | Buscar rádios por nome e gênero no catálogo aberto, com filtro Brasil | 1 |
| RF-002 | Mostrar título da música atual quando a rádio enviar (metadados ICY) | 1 |
| RF-003 | Mostrar capa do álbum quando encontrada; senão, o ícone da rádio | 1 |
| RF-004 | Reconectar automaticamente com espera crescente (0,5 s até 10 s) | 2 |
| RF-005 | Detectar travamento (12 s sem dados) e reconectar | 2 |
| RF-006 | Tocar em segundo plano com controles na notificação e tela de bloqueio | 2 |
| RF-007 | Pausar ao desconectar fone | 2 |
| RF-008 | Gravar os últimos 30 minutos em disco, descartando o mais antigo | 3 |
| RF-009 | Voltar/avançar 30 s, barra de tempo e botão "ao vivo" | 3 |
| RF-010 | Pausa não interrompe a gravação | 3 |
| RF-011 | Tocar direto, sem gravação, rádios em HLS ou servidores incompatíveis | 3 |
| RF-012 | Favoritas salvas no aparelho, com reordenação | 4 |
| RF-013 | Cadastro manual com endereço principal, reserva e playlists | 5 |
| RF-014 | Troca automática para o reserva após 3 quedas em 2 minutos | 6 |
| RF-015 | Alternância manual alta/reserva | 6 |
| RF-016 | Sugestão automática de reserva ao favoritar | 6 |
| RF-017 | Timer para desligar | 7 |

## Requisitos não funcionais (RNF)
| Código | Requisito |
|---|---|
| RNF-001 | Android 7 ou superior; iOS compila, mas não é alvo de teste nesta versão |
| RNF-002 | Gravação ocupa no máximo ~75 MB (30 min a 320 kbps) na pasta temporária |
| RNF-003 | Nenhuma chave de API, login ou serviço pago |
| RNF-004 | Código público, licença MIT |

## Critérios de sucesso
- Uma hora de reprodução contínua sem intervenção do usuário, mesmo com
  quedas de rede provocadas (desligar e ligar o WiFi).
- Voltar 10 minutos e retornar ao ao vivo sem erro.
- A Spoon Radio toca no WiFi de casa, na alta ou trocando sozinha para a reserva.

## Fora do escopo desta versão
Android Auto/CarPlay, gravação para arquivo, conta/sincronização, equalizador,
histórico de músicas, widget de tela inicial.
