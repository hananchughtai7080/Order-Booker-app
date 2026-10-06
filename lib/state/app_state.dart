import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/strings.dart';

class AppState extends ChangeNotifier {
  String lang = 'en';
  double dailyTarget = 0;
  final Set<int> _visitedToday = {};
  String _visitedDate = '';

  String s(String key) => Strings.get(lang, key);

  bool get isUrdu => lang == 'ur';

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    lang = p.getString('lang') ?? 'en';
    dailyTarget = p.getDouble('daily_target') ?? 0;
    notifyListeners();
  }

  Future<void> setLang(String v) async {
    lang = v;
    final p = await SharedPreferences.getInstance();
    await p.setString('lang', v);
    notifyListeners();
  }

  Future<void> setDailyTarget(double v) async {
    dailyTarget = v;
    final p = await SharedPreferences.getInstance();
    await p.setDouble('daily_target', v);
    notifyListeners();
  }

  void _rollVisited(String today) {
    if (_visitedDate != today) {
      _visitedDate = today;
      _visitedToday.clear();
    }
  }

  bool isVisited(int shopId, String today) {
    _rollVisited(today);
    return _visitedToday.contains(shopId);
  }

  void toggleVisited(int shopId, String today) {
    _rollVisited(today);
    if (_visitedToday.contains(shopId)) {
      _visitedToday.remove(shopId);
    } else {
      _visitedToday.add(shopId);
    }
    notifyListeners();
  }

  void refresh() => notifyListeners();
}
