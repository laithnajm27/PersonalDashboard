class Shotlist {
  const Shotlist({
    required this.szeneNummer,
    this.einstellungsGroesse = '',
    this.kameraBewegung = '',
    this.beschreibung = '',
    this.audioSfx = '',
    this.istErledigt = false,
    this.equipmentIds = const [],
  });

  final int szeneNummer;
  final String einstellungsGroesse;
  final String kameraBewegung;
  final String beschreibung;
  final String audioSfx;
  final bool istErledigt;
  final List<String> equipmentIds;

  factory Shotlist.fromJson(Map<String, dynamic> json) {
    final sceneNumber = json['szene_nummer'];
    if (sceneNumber is! num || sceneNumber < 1) {
      throw const FormatException('Shotlist-Szene hat keine gültige Nummer.');
    }
    return Shotlist(
      szeneNummer: sceneNumber.toInt(),
      einstellungsGroesse: json['einstellungs_groesse'] as String? ?? '',
      kameraBewegung: json['kamera_bewegung'] as String? ?? '',
      beschreibung: json['beschreibung'] as String? ?? '',
      audioSfx: json['audio_sfx'] as String? ?? '',
      istErledigt: json['ist_erledigt'] as bool? ?? false,
      equipmentIds: (json['equipment_ids'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'szene_nummer': szeneNummer,
        'einstellungs_groesse': einstellungsGroesse,
        'kamera_bewegung': kameraBewegung,
        'beschreibung': beschreibung,
        'audio_sfx': audioSfx,
        'ist_erledigt': istErledigt,
        'equipment_ids': equipmentIds,
      };
}
