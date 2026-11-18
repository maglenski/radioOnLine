/// Uma rádio que o app sabe tocar.
///
/// Vem do catálogo Radio Browser ou é cadastrada à mão pelo usuário.
class Station {
  const Station({
    required this.id,
    required this.name,
    required this.streamUrl,
    this.fallbackUrl,
    this.faviconUrl,
    this.homepage,
    this.country,
    this.codec,
    this.bitrate,
    this.tags = const [],
    this.manual = false,
  });

  /// Identificador estável. No catálogo é o `stationuuid`; nas manuais é gerado.
  final String id;
  final String name;

  /// Endereço principal do stream (normalmente a melhor qualidade).
  final String streamUrl;

  /// Endereço reserva, de qualidade menor, usado quando o principal fica cortando.
  final String? fallbackUrl;

  final String? faviconUrl;
  final String? homepage;
  final String? country;
  final String? codec;
  final int? bitrate;
  final List<String> tags;
  final bool manual;

  Station copyWith({
    String? name,
    String? streamUrl,
    String? fallbackUrl,
    bool clearFallback = false,
    String? faviconUrl,
  }) {
    return Station(
      id: id,
      name: name ?? this.name,
      streamUrl: streamUrl ?? this.streamUrl,
      fallbackUrl: clearFallback ? null : (fallbackUrl ?? this.fallbackUrl),
      faviconUrl: faviconUrl ?? this.faviconUrl,
      homepage: homepage,
      country: country,
      codec: codec,
      bitrate: bitrate,
      tags: tags,
      manual: manual,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'streamUrl': streamUrl,
        'fallbackUrl': fallbackUrl,
        'faviconUrl': faviconUrl,
        'homepage': homepage,
        'country': country,
        'codec': codec,
        'bitrate': bitrate,
        'tags': tags,
        'manual': manual,
      };

  factory Station.fromJson(Map<String, dynamic> json) => Station(
        id: json['id'] as String,
        name: json['name'] as String,
        streamUrl: json['streamUrl'] as String,
        fallbackUrl: json['fallbackUrl'] as String?,
        faviconUrl: json['faviconUrl'] as String?,
        homepage: json['homepage'] as String?,
        country: json['country'] as String?,
        codec: json['codec'] as String?,
        bitrate: json['bitrate'] as int?,
        tags: (json['tags'] as List?)?.cast<String>() ?? const [],
        manual: json['manual'] as bool? ?? false,
      );

  /// Converte um item da API do Radio Browser.
  factory Station.fromRadioBrowser(Map<String, dynamic> json) {
    String? blankToNull(Object? v) {
      final s = (v as String?)?.trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    final resolved = blankToNull(json['url_resolved']);
    final bitrate = json['bitrate'] is int ? json['bitrate'] as int : null;
    return Station(
      id: json['stationuuid'] as String,
      name: (json['name'] as String? ?? '').trim(),
      streamUrl: resolved ?? (json['url'] as String),
      faviconUrl: blankToNull(json['favicon']),
      homepage: blankToNull(json['homepage']),
      country: blankToNull(json['countrycode']),
      codec: blankToNull(json['codec']),
      bitrate: (bitrate == null || bitrate == 0) ? null : bitrate,
      tags: (blankToNull(json['tags']) ?? '')
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .take(5)
          .toList(),
    );
  }

  /// Linha curta de detalhes: "BR · MP3 · 128 kbps".
  String get details => [
        if (country != null) country,
        if (codec != null) codec,
        if (bitrate != null) '$bitrate kbps',
      ].join(' · ');

  @override
  bool operator ==(Object other) => other is Station && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
