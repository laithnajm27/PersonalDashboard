import 'package:flutter/foundation.dart';

import '../models/insights.dart';
import 'edge_api.dart';

class InsightsController extends ChangeNotifier {
  InsightsController(this._edgeApi);

  final EdgeApi _edgeApi;
  InstagramInsights? insights;
  bool isLoading = false;

  Future<InstagramInsights> connectAndLoad() async {
    isLoading = true;
    notifyListeners();
    try {
      final result = await _edgeApi.fetchInstagramInsights();
      insights = result;
      return result;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
