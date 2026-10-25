import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/insights.dart';

class EdgeApi {
  EdgeApi(this._client);

  final SupabaseClient _client;

  factory EdgeApi.fromInitialized() => EdgeApi(Supabase.instance.client);

  Future<Uri> startInstagramOAuth() async {
    final response = await _client.functions.invoke(
      'api',
      body: {'action': 'instagram_oauth_start'},
    );
    final data = _asJsonObject(response.data);
    final value = data['authorization_url'];
    final uri = value is String ? Uri.tryParse(value) : null;
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'www.instagram.com' ||
        uri.path != '/oauth/authorize') {
      throw const FormatException(
          'Meta hat keine gültige Login-Adresse geliefert.');
    }
    return uri;
  }

  Future<InstagramInsights> fetchInstagramInsights() async {
    final response = await _client.functions.invoke(
      'api',
      body: {'action': 'instagram_insights'},
    );
    final data = _asJsonObject(response.data);
    return InstagramInsights.fromJson(data);
  }

  Future<InstagramConnection?> getInstagramConnection() async {
    final response = await _client.functions.invoke(
      'api',
      body: {'action': 'instagram_connection_status'},
    );
    final data = _asJsonObject(response.data);
    if (data['connected'] != true) {
      return null;
    }
    return InstagramConnection.fromJson(data);
  }

  Future<void> disconnectInstagram() async {
    final response = await _client.functions.invoke(
      'api',
      body: {'action': 'instagram_disconnect'},
    );
    _asJsonObject(response.data);
  }

  Future<String> askAssistant({
    required List<Map<String, String>> messages,
  }) async {
    final response = await _client.functions.invoke(
      'api',
      body: {
        'action': 'assistant',
        'messages': messages,
      },
    );
    final data = _asJsonObject(response.data);
    final reply = data['reply'];
    if (reply is! String || reply.trim().isEmpty) {
      throw const FormatException('Der KI-Dienst hat keine Antwort geliefert.');
    }
    return reply;
  }

  Map<String, dynamic> _asJsonObject(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    throw const FormatException(
        'Die Edge Function hat eine ungültige Antwort geliefert.');
  }
}
