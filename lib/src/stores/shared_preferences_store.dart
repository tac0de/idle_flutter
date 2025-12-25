import 'package:idle_save/idle_save.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesStore extends SaveStore {
  SharedPreferencesStore(this.key);

  final String key;

  @override
  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  @override
  Future<void> write(String data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, data);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
