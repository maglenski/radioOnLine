# Tarefas 001

Legenda: RF = requisito funcional da [spec.md](spec.md).

## Fase 1 — Base
- [x] T01 Criar projeto Flutter (Android e iOS) e dependências
- [x] T02 Modelo `Station` com conversão do catálogo e JSON (RF-012, RF-013)

## Fase 2 — Motor de áudio (testado sem tela)
- [x] T03 `IcyDemuxer` + testes com pedaços de tamanho aleatório (RF-002)
- [x] T04 `TimeshiftBuffer` em disco + testes de descarte e posição ↔ horário (RF-008)
- [x] T05 `StreamRelay`: conexão, metadados, reconexão com espera crescente, travamento (RF-004, RF-005)
- [x] T06 `StreamRelay`: playlists `.pls`/`.m3u` e detecção de HLS (RF-011, RF-013)
- [x] T07 `StreamRelay`: troca automática e manual para o reserva (RF-014, RF-015)
- [x] T08 `LocalStreamServer` servindo o buffer a partir de uma posição (RF-009)
- [x] T09 Testes de integração com rádio falsa: reconexão, reserva, playlist, servidor local

## Fase 3 — Player
- [x] T10 `RadioAudioHandler`: tocar, pausar gravando, voltar/avançar, ao vivo (RF-009, RF-010)
- [x] T11 Notificação e tela de bloqueio com voltar/avançar 30 s (RF-006)
- [x] T12 Pausa ao desconectar fone (RF-007)
- [x] T13 Reabrir o player sozinho em caso de erro (RF-004)
- [x] T14 Capa do álbum pelo título (RF-003)
- [x] T15 Timer para desligar (RF-017)

## Fase 4 — Interface
- [x] T16 Busca com sugestões de gênero e filtro Brasil (RF-001)
- [x] T17 Favoritas com reordenação, edição e remoção (RF-012)
- [x] T18 Cadastro manual com endereço reserva (RF-013)
- [x] T19 Sugestão automática de reserva ao favoritar (RF-016)
- [x] T20 Tela do player com barra de volta no tempo e mini player
- [x] T21 Identidade visual própria e ícone

## Fase 5 — Validação no aparelho (autor)
- [ ] T22 Uma hora tocando com quedas de WiFi provocadas
- [ ] T23 Voltar 10 minutos e retornar ao ao vivo
- [ ] T24 Spoon Radio no WiFi de casa em alta qualidade / reserva automática
- [ ] T25 Tela apagada por 30 minutos sem o Android matar o app
