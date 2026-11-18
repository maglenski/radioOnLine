import 'dart:convert';
import 'dart:typed_data';

/// Separa o áudio dos metadados ICY (título da música) num stream SHOUTcast/Icecast.
///
/// Quando o pedido vai com `Icy-MetaData: 1`, o servidor intercala a cada
/// `metaInt` bytes de áudio um bloco: 1 byte de tamanho (×16) + o texto.
/// Exemplo do texto: `StreamTitle='Interpol - Evil';StreamUrl='';`
class IcyDemuxer {
  IcyDemuxer(this.metaInt) : _audioLeft = metaInt ?? 0;

  /// Intervalo informado no cabeçalho `icy-metaint`. 0 ou nulo = sem metadados.
  final int? metaInt;

  int _audioLeft;
  int _metaLeft = 0;
  bool _readingLength = false;
  final _meta = BytesBuilder(copy: false);

  bool get _enabled => metaInt != null && metaInt! > 0;

  /// Processa um pedaço recebido da rede. Devolve só o áudio;
  /// cada título completo é entregue em [onTitle].
  Uint8List process(Uint8List chunk, void Function(String title) onTitle) {
    if (!_enabled) return chunk;
    final audio = BytesBuilder(copy: false);
    var i = 0;
    while (i < chunk.length) {
      if (_audioLeft > 0) {
        final n = (_audioLeft < chunk.length - i) ? _audioLeft : chunk.length - i;
        audio.add(Uint8List.sublistView(chunk, i, i + n));
        _audioLeft -= n;
        i += n;
        if (_audioLeft == 0) _readingLength = true;
      } else if (_readingLength) {
        _metaLeft = chunk[i] * 16;
        _readingLength = false;
        i++;
        if (_metaLeft == 0) _audioLeft = metaInt!;
      } else {
        final n = (_metaLeft < chunk.length - i) ? _metaLeft : chunk.length - i;
        _meta.add(Uint8List.sublistView(chunk, i, i + n));
        _metaLeft -= n;
        i += n;
        if (_metaLeft == 0) {
          final title = parseStreamTitle(_meta.takeBytes());
          if (title != null) onTitle(title);
          _audioLeft = metaInt!;
        }
      }
    }
    return audio.takeBytes();
  }

  /// Extrai o `StreamTitle` do bloco de metadados. Devolve nulo se vazio.
  static String? parseStreamTitle(List<int> raw) {
    var text = utf8.decode(raw, allowMalformed: true);
    if (text.contains('�')) text = latin1.decode(raw, allowInvalid: true);
    text = text.replaceAll('\u0000', '');
    final match = RegExp(r"StreamTitle='(.*?)';", dotAll: true).firstMatch(text);
    final title = match?.group(1)?.trim();
    return (title == null || title.isEmpty) ? null : title;
  }
}
