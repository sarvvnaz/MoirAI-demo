import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LocalStorage {
  // Returns the file path for storing JSON data
  static Future<String> _getFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/user_stats.json';
  }

  // Save user feedback and stats to local storage (in JSON format)
  static Future<void> saveUserStats(Map<String, dynamic> userStats) async {
    final path = await _getFilePath();
    final file = File(path);

    if (await file.exists()) {
      String contents = await file.readAsString();
      List<dynamic> data = json.decode(contents);
      data.add(userStats);  // Add new user stats to the existing list
      await file.writeAsString(json.encode(data));  // Write the updated data
    } else {
      List<dynamic> data = [userStats];  // Start a new list if no file exists
      await file.writeAsString(json.encode(data));  // Write new data
    }
  }

  // Load all user stats from the stored JSON file
  static Future<List<Map<String, dynamic>>> loadUserStats() async {
    final path = await _getFilePath();
    final file = File(path);

    if (await file.exists()) {
      String contents = await file.readAsString();
      List<dynamic> data = json.decode(contents);
      return List<Map<String, dynamic>>.from(data);
    } else {
      return [];  // Return empty list if no data is found
    }
  }
}
