# Constituição do projeto Sintonia (radioOnLine)

Princípios que valem para toda funcionalidade. Uma especificação ou plano que
contrarie um destes itens precisa justificar a exceção por escrito.

## 1. Especificação antes do código
Toda funcionalidade nasce em `specs/NNN-nome/` com, nesta ordem:
`spec.md` (o quê e por quê, sem tecnologia) → `plan.md` (como) →
`tasks.md` (passos verificáveis). O código só entra depois, e cada tarefa
aponta para o requisito que atende.

## 2. Confiabilidade acima de recursos
O app existe porque outros players cortam a música. Nenhum recurso novo pode
piorar a estabilidade da reprodução. Queda de rede é situação normal, não erro:
o app reconecta sozinho, sem o usuário precisar tocar em nada.

## 3. Só tecnologia aberta e sem conta
Nada de chave de API, login ou serviço pago. Catálogo: Radio Browser.
Capas: busca pública do iTunes. O repositório é público e precisa compilar
para qualquer pessoa que o clonar.

## 4. Gravação só local
A volta no tempo grava no máximo 30 minutos, em pasta temporária do próprio
celular, apagada ao trocar de rádio ou fechar o app. Não há exportação nem
compartilhamento do áudio gravado.

## 5. Identidade própria
Nome, ícone e visual são do projeto. Nenhuma marca de rádio ou de outro app é
usada como identidade; logos de rádio só aparecem como ícone da própria rádio,
vindos do catálogo.

## 6. Testes no que pode quebrar sem ninguém ver
Toda lógica de áudio que não depende de tela (separação de metadados, buffer,
reconexão, servidor local) tem teste automatizado rodando com `flutter test`.

## 7. Simples primeiro
Sem banco de dados, sem gerenciador de estado pesado, sem backend. Cresce
quando houver necessidade real registrada numa especificação.
