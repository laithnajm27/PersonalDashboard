class Shotlist {
  const Shotlist({
    required this.szeneNummer,
    this.einstellungsGroesse = '',
    this.kameraBewegung = '',
    this.beschreibung = '',
    this.audioSfx = '',
    this.istErledigt = false,
  });

  final int szeneNummer;
  final String einstellungsGroesse;
  final String kameraBewegung;
  final String beschreibung;
  final String audioSfx;
  final bool istErledigt;

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
    );
  }

  Map<String, dynamic> toJson() => {
        'szene_nummer': szeneNummer,
        'einstellungs_groesse': einstellungsGroesse,
        'kamera_bewegung': kameraBewegung,
        'beschreibung': beschreibung,
        'audio_sfx': audioSfx,
        'ist_erledigt': istErledigt,
      };
}
