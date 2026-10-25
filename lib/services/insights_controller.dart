import 'package:flutter/foundation.dart';

import '../models/insights.dart';
import 'edge_api.dart';
import 'package:url_launcher/url_launcher.dart';

class InsightsController extends ChangeNotifier {
  InsightsController(this._edgeApi);

  final EdgeApi _edgeApi;
  InstagramInsights? insights;
  InstagramConnection? connection;
  bool isLoading = false;

  Future<InstagramConnection?> loadConnection() async {
    connection = await _edgeApi.getInstagramConnection();
    if (connection == null) {
      insights = null;
    }
    notifyListeners();
    return connection;
  }

  Future<void> beginInstagramConnection() async {
    final authorizationUrl = await _edgeApi.startInstagramOAuth();
    final launched = await launchUrl(
      authorizationUrl,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      throw StateError('Der Meta-Login konnte nicht geöffnet werden.');
    }
  }

  Future<InstagramInsights> connectAndLoad() async {
    isLoading = true;
    notifyListeners();
    try {
      final result = await _edgeApi.fetchInstagramInsights();
      insights = result;
      connection = await _edgeApi.getInstagramConnection();
      return result;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> disconnectInstagram() async {
    isLoading = true;
    notifyListeners();
    try {
      await _edgeApi.disconnectInstagram();
      connection = null;
      insights = null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
