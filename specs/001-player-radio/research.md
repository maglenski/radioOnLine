# Pesquisa 001 — Como funcionam as rádios online

## Como um app tipo TuneIn acha as rádios
As rádios não "anunciam" nada na rede. Cada rádio tem um servidor de streaming
(Icecast, SHOUTcast ou um serviço de hospedagem) com um endereço fixo. Os apps
mantêm **catálogos**: bancos de dados com nome, país, gênero (tags), formato e
o endereço de cada rádio. O TuneIn tem catálogo próprio e fechado.

Este projeto usa o **Radio Browser** (https://www.radio-browser.info):
catálogo comunitário e aberto, com dezenas de milhares de rádios, API sem chave
e vários servidores espelho (lista oficial em `all.api.radio-browser.info`).
Regras de boa convivência seguidas: `User-Agent` identificado e aviso de clique
(`/json/url/{id}`) ao tocar.

## Como o áudio chega
- **Icecast / SHOUTcast:** uma conexão HTTP que nunca termina, com quadros MP3
  ou AAC em sequência.
- **Metadados ICY:** pedindo com o cabeçalho `Icy-MetaData: 1`, o servidor
  informa `icy-metaint: N` e, a cada N bytes de áudio, insere 1 byte de tamanho
  (×16) seguido de `StreamTitle='Artista - Música';`. É assim que o app sabe a
  música atual sem nenhuma API extra.
- **Playlists `.pls` / `.m3u`:** arquivos de texto com o endereço real; o app
  resolve antes de conectar.
- **HLS (`.m3u8`):** áudio em pedaços de alguns segundos; tocado direto.

## A gravação de 30 minutos (timeshift)
É o mesmo recurso que causou o conflito de direitos autorais no TuneIn, por ser
um serviço comercial que guardava o áudio. Aqui a gravação fica só no celular,
dura no máximo 30 minutos, é apagada ao trocar de rádio e não pode ser exportada.

Tamanho: bitrate × 30 min. A 128 kbps ≈ 29 MB; a 320 kbps ≈ 72 MB.

## Hipóteses para a Spoon Radio cortar na alta qualidade só no WiFi de casa
Observação do autor: na alta qualidade corta no WiFi; no 5G ou a 96 kbps não
corta; outras rádios em alta qualidade funcionam no mesmo WiFi.

Hipóteses, da mais à menos provável, para verificar nos testes:
1. O endereço de alta qualidade está num servidor/porta diferente (ex.: porta
   8000) que o roteador ou a operadora de internet fixa trata mal.
2. Caminho IPv6 do provedor de casa com problema até esse servidor (no 5G o
   caminho é outro).
3. MTU / fragmentação no roteador afetando conexões longas a esse servidor.

A versão 1.0 resolve na prática com o endereço reserva automático (RF-014),
sem depender de descobrir a causa. Para diagnosticar: anotar o endereço exato
de cada qualidade e testar no WiFi com e sem IPv6 no roteador.
