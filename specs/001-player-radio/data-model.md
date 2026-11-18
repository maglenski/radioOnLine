# Modelo de dados 001

O app não tem banco de dados (princípio 7). Os dados persistidos ficam em
`shared_preferences` como JSON.

## Station (rádio)
| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| id | texto | sim | `stationuuid` do catálogo ou `manual-<timestamp>` |
| name | texto | sim | Nome exibido |
| streamUrl | texto | sim | Endereço principal (melhor qualidade) |
| fallbackUrl | texto | não | Endereço reserva (qualidade menor) |
| faviconUrl | texto | não | Ícone da rádio |
| homepage | texto | não | Site da rádio |
| country | texto | não | Código do país (BR) |
| codec | texto | não | MP3, AAC… |
| bitrate | inteiro | não | kbps |
| tags | lista de texto | não | Gêneros |
| manual | booleano | sim | Cadastrada pelo usuário |

## Chaves gravadas
| Chave | Conteúdo |
|---|---|
| `favorites_v1` | Lista JSON de `Station`, na ordem escolhida pelo usuário |
| `last_station_v1` | `Station` tocada por último |

## Dados temporários (não persistem)
`TimeshiftBuffer` grava segmentos `seg_<geração>_<n>.bin` em
`<pasta temporária>/timeshift/`, apagados ao trocar de rádio e ao abrir o app.
