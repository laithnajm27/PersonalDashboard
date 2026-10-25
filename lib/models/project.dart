import 'shotlist.dart';

enum ProjectType { foto, video, gespraech, kombi }

extension ProjectTypeLabel on ProjectType {
  String get label => switch (this) {
        ProjectType.foto => 'Foto',
        ProjectType.video => 'Video',
        ProjectType.gespraech => 'Gespräch',
        ProjectType.kombi => 'Kombi',
      };

  static ProjectType fromJson(Object? value) {
    for (final type in ProjectType.values) {
      if (type.name == value) {
        return type;
      }
    }
    throw FormatException('Unbekannter Projekttyp: $value');
  }
}

class Project {
  const Project({
    this.id,
    required this.kundeId,
    required this.titel,
    this.projektTyp = ProjectType.foto,
    this.status = 'Offen',
    this.shotlistDaten = const [],
  });

  final String? id;
  final String kundeId;
  final String titel;
  final ProjectType projektTyp;
  final String status;
  final List<Shotlist> shotlistDaten;

  factory Project.fromJson(Map<String, dynamic> json) {
    final rawShotlist = json['shotlist_daten'] as List<dynamic>? ?? const [];
    final id = json['id']?.toString();
    final customerId = json['kunde_id']?.toString();
    final title = json['titel'];
    if (id == null || customerId == null || title is! String || title.isEmpty) {
      throw const FormatException('Projektdatensatz ist unvollständig.');
    }
    return Project(
      id: id,
      kundeId: customerId,
      titel: title,
      projektTyp: ProjectTypeLabel.fromJson(json['projekt_typ']),
      status: json['status'] as String,
      shotlistDaten: rawShotlist
          .whereType<Map<String, dynamic>>()
          .map(Shotlist.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) => {
        if (includeId && id != null) 'id': id,
        'kunde_id': kundeId,
        'titel': titel,
        'projekt_typ': projektTyp.name,
        'status': status,
        'shotlist_daten': shotlistDaten.map((item) => item.toJson()).toList(),
      };
}
