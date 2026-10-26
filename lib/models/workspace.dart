enum TaskStatus {
  open,
  inProgress,
  done;

  String get databaseValue => switch (this) {
        TaskStatus.open => 'open',
        TaskStatus.inProgress => 'in_progress',
        TaskStatus.done => 'done',
      };

  static TaskStatus fromDatabase(Object? value) => switch (value) {
        'open' => TaskStatus.open,
        'in_progress' => TaskStatus.inProgress,
        'done' => TaskStatus.done,
        _ => throw FormatException('Unbekannter Aufgabenstatus: $value'),
      };
}

enum TaskPriority { low, normal, high }

class DashboardTask {
  const DashboardTask({
    this.id,
    required this.title,
    this.description = '',
    this.status = TaskStatus.open,
    this.priority = TaskPriority.normal,
    this.dueAt,
    this.completedAt,
    this.projectId,
  });

  final String? id;
  final String title;
  final String description;
  final TaskStatus status;
  final TaskPriority priority;
  final DateTime? dueAt;
  final DateTime? completedAt;
  final String? projectId;

  factory DashboardTask.fromJson(Map<String, dynamic> json) {
    return DashboardTask(
      id: json['id']?.toString(),
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      status: TaskStatus.fromDatabase(json['status']),
      priority: TaskPriority.values.byName(json['priority'] as String),
      dueAt: _parseDate(json['due_at']),
      completedAt: _parseDate(json['completed_at']),
      projectId: json['project_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) => {
        if (includeId && id != null) 'id': id,
        'title': title,
        'description': description,
        'status': status.databaseValue,
        'priority': priority.name,
        'due_at': dueAt?.toUtc().toIso8601String(),
        'project_id': projectId,
        'completed_at': status == TaskStatus.done
            ? (completedAt ?? DateTime.now()).toUtc().toIso8601String()
            : null,
      };
}

class CreatorGoal {
  const CreatorGoal({
    this.id,
    required this.title,
    this.description = '',
    this.dueAt,
    this.completedAt,
  });

  final String? id;
  final String title;
  final String description;
  final DateTime? dueAt;
  final DateTime? completedAt;

  bool get isCompleted => completedAt != null;

  factory CreatorGoal.fromJson(Map<String, dynamic> json) => CreatorGoal(
        id: json['id']?.toString(),
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        dueAt: _parseDate(json['due_at']),
        completedAt: _parseDate(json['completed_at']),
      );

  Map<String, dynamic> toJson({bool includeId = true}) => {
        if (includeId && id != null) 'id': id,
        'title': title,
        'description': description,
        'due_at': dueAt?.toUtc().toIso8601String(),
        'completed_at': completedAt?.toUtc().toIso8601String(),
      };
}

class EquipmentItem {
  const EquipmentItem({
    this.id,
    required this.name,
    this.description = '',
  });

  final String? id;
  final String name;
  final String description;

  factory EquipmentItem.fromJson(Map<String, dynamic> json) => EquipmentItem(
        id: json['id']?.toString(),
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
      );

  Map<String, dynamic> toJson({bool includeId = true}) => {
        if (includeId && id != null) 'id': id,
        'name': name,
        'description': description,
      };
}

class CreatorProfile {
  const CreatorProfile({
    required this.id,
    this.fullName = '',
    this.companyName = '',
    this.companyAddress = '',
    this.companyEmail = '',
    this.companyPhone = '',
    this.taxNumber = '',
    this.vatId = '',
    this.bankDetails = '',
    this.invoiceNote = '',
    this.smallBusinessDefault = false,
    this.themeMode = 'system',
    this.legalNoticeUrl = '',
    this.privacyUrl = '',
  });

  final String id;
  final String fullName;
  final String companyName;
  final String companyAddress;
  final String companyEmail;
  final String companyPhone;
  final String taxNumber;
  final String vatId;
  final String bankDetails;
  final String invoiceNote;
  final bool smallBusinessDefault;
  final String themeMode;
  final String legalNoticeUrl;
  final String privacyUrl;

  factory CreatorProfile.fromJson(Map<String, dynamic> json) => CreatorProfile(
        id: json['id'] as String,
        fullName: json['full_name'] as String? ?? '',
        companyName: json['company_name'] as String? ?? '',
        companyAddress: json['company_address'] as String? ?? '',
        companyEmail: json['company_email'] as String? ?? '',
        companyPhone: json['company_phone'] as String? ?? '',
        taxNumber: json['tax_number'] as String? ?? '',
        vatId: json['vat_id'] as String? ?? '',
        bankDetails: json['bank_details'] as String? ?? '',
        invoiceNote: json['invoice_note'] as String? ?? '',
        smallBusinessDefault: json['small_business_default'] as bool? ?? false,
        themeMode: json['theme_mode'] as String? ?? 'system',
        legalNoticeUrl: json['legal_notice_url'] as String? ?? '',
        privacyUrl: json['privacy_url'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'company_name': companyName,
        'company_address': companyAddress,
        'company_email': companyEmail,
        'company_phone': companyPhone,
        'tax_number': taxNumber,
        'vat_id': vatId,
        'bank_details': bankDetails,
        'invoice_note': invoiceNote,
        'small_business_default': smallBusinessDefault,
        'theme_mode': themeMode,
        'legal_notice_url': legalNoticeUrl,
        'privacy_url': privacyUrl,
      };
}

DateTime? _parseDate(Object? value) {
  if (value is! String) {
    return null;
  }
  return DateTime.tryParse(value)?.toLocal();
}
