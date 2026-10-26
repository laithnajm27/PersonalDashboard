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
    this.statusUpdatedAt,
    this.beschreibung = '',
    this.ort = '',
    this.startAt,
    this.dueAt,
    this.budget,
    this.shotlistDaten = const [],
  });

  final String? id;
  final String kundeId;
  final String titel;
  final ProjectType projektTyp;
  final String status;
  final DateTime? statusUpdatedAt;
  final String beschreibung;
  final String ort;
  final DateTime? startAt;
  final DateTime? dueAt;
  final double? budget;
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
      statusUpdatedAt: json['status_updated_at'] is String
          ? DateTime.tryParse(json['status_updated_at'] as String)?.toLocal()
          : null,
      beschreibung: json['beschreibung'] as String? ?? '',
      ort: json['ort'] as String? ?? '',
      startAt: _parseProjectDate(json['start_at']),
      dueAt: _parseProjectDate(json['due_at']),
      budget: (json['budget'] as num?)?.toDouble(),
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
        'beschreibung': beschreibung,
        'ort': ort,
        'start_at': startAt?.toUtc().toIso8601String(),
        'due_at': dueAt?.toUtc().toIso8601String(),
        'budget': budget,
        if (statusUpdatedAt != null)
          'status_updated_at': statusUpdatedAt!.toUtc().toIso8601String(),
        'shotlist_daten': shotlistDaten.map((item) => item.toJson()).toList(),
      };
}

class ProjectLink {
  const ProjectLink({
    this.id,
    required this.projectId,
    required this.title,
    required this.url,
    this.note = '',
  });

  final String? id;
  final String projectId;
  final String title;
  final String url;
  final String note;

  factory ProjectLink.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    final projectId = json['project_id']?.toString();
    final title = json['title'];
    final url = json['url'];
    if (id == null ||
        projectId == null ||
        title is! String ||
        title.trim().isEmpty ||
        url is! String ||
        url.trim().isEmpty) {
      throw const FormatException('Projektlink ist unvollständig.');
    }
    return ProjectLink(
      id: id,
      projectId: projectId,
      title: title,
      url: url,
      note: json['note'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) => {
        if (includeId && id != null) 'id': id,
        'project_id': projectId,
        'title': title,
        'url': url,
        'note': note,
      };
}

DateTime? _parseProjectDate(Object? value) {
  if (value is! String) {
    return null;
  }
  return DateTime.tryParse(value)?.toLocal();
}
