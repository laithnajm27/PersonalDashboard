import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/insights.dart';

class EdgeApi {
  EdgeApi(this._client);

  final SupabaseClient _client;

  factory EdgeApi.fromInitialized() => EdgeApi(Supabase.instance.client);

  Future<InstagramInsights> fetchInstagramInsights() async {
    final response = await _client.functions.invoke(
      'api',
      body: {'action': 'instagram_insights'},
    );
    final data = _asJsonObject(response.data);
    return InstagramInsights.fromJson(data);
  }

  Future<String> askAssistant({
    required List<Map<String, String>> messages,
    required InstagramInsights insights,
  }) async {
    final response = await _client.functions.invoke(
      'api',
      body: {
        'action': 'assistant',
        'messages': messages,
        'insights': insights.toJson(),
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
    throw const FormatException('Die Edge Function hat eine ungültige Antwort geliefert.');
  }
}
