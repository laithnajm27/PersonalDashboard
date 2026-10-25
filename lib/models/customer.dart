class Customer {
  const Customer({
    this.id,
    required this.name,
    this.unternehmen,
    this.instagramHandle,
    this.email,
    this.telefon,
    this.notizen,
  });

  final String? id;
  final String name;
  final String? unternehmen;
  final String? instagramHandle;
  final String? email;
  final String? telefon;
  final String? notizen;

  factory Customer.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('Kundendatensatz hat keinen gültigen Namen.');
    }
    return Customer(
      id: json['id']?.toString(),
      name: name,
      unternehmen: json['unternehmen'] as String?,
      instagramHandle: json['instagram_handle'] as String?,
      email: json['email'] as String?,
      telefon: json['telefon'] as String?,
      notizen: json['notizen'] as String?,
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    return {
      if (includeId && id != null) 'id': id,
      'name': name,
      'unternehmen': unternehmen,
      'instagram_handle': instagramHandle,
      'email': email,
      'telefon': telefon,
      'notizen': notizen,
    };
  }
}
