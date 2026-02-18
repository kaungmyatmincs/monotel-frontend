import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://localhost:3000";

  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final response = await http.post(
      Uri.parse("$baseUrl/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "password": password,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Login failed");
    }
  }

  static Future<List<dynamic>> getBuildings(String token) async {
    final response = await http.get(
        Uri.parse("$baseUrl/buildings"),
        headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
        },
    );

    if (response.statusCode == 200) {
        return jsonDecode(response.body);
    } else {
        throw Exception("Failed to load buildings");
    }
  }

  static Future<List<dynamic>> getRooms(String token) async {
    final response = await http.get(
        Uri.parse("$baseUrl/rooms"),
        headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
        },
    );

    if (response.statusCode == 200) {
        return jsonDecode(response.body);
    } else {
        throw Exception("Failed to load rooms");
    }
  }

  static Future<void> toggleRoom(String token, String roomId) async {
    final response = await http.patch(
        Uri.parse("$baseUrl/rooms/$roomId/toggle"),
        headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
        },
    );

    if (response.statusCode != 200) {
        throw Exception("Failed to toggle room");
    }
  }

}
