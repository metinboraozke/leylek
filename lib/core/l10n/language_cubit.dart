import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'strings.dart';

/// Kullanıcının seçtiği dilin kaydı. Seçilmemişse cihaz dili kullanılır.
abstract interface class LanguageStore {
  Future<String?> load();
  Future<void> save(String lang);
}

class PrefsLanguageStore implements LanguageStore {
  PrefsLanguageStore([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;
  static const String _key = 'language_v1';

  @override
  Future<String?> load() async {
    try {
      return await _prefs.getString(_key);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> save(String lang) async {
    try {
      await _prefs.setString(_key, lang);
    } on Object {
      // Kaydedilemezse dil yalnızca bu oturumda geçerli olur.
    }
  }
}

/// Testlerde ve kaydın kullanılamadığı ortamlarda.
class MemoryLanguageStore implements LanguageStore {
  String? _lang;

  @override
  Future<String?> load() async => _lang;

  @override
  Future<void> save(String lang) async => _lang = lang;
}

/// Etkin dil (`tr` / `en`). Değişince [S.lang] güncellenir ve kaydedilir.
class LanguageCubit extends Cubit<String> {
  LanguageCubit(this._store, {required String initial}) : super(initial) {
    S.lang = initial;
    _store.load().then((saved) {
      if (!isClosed && saved != null && saved != state) _apply(saved);
    });
  }

  final LanguageStore _store;

  Future<void> select(String lang) async {
    if (!S.supported.contains(lang) || lang == state) return;
    _apply(lang);
    await _store.save(lang);
  }

  void _apply(String lang) {
    S.lang = lang;
    emit(S.lang);
  }
}
