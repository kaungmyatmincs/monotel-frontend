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

  static Future<void> createBuilding(String token, String name) async {
    final response = await http.post(
      Uri.parse("$baseUrl/buildings"),
      headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
      body: jsonEncode({"name": name}),
    );
    if (response.statusCode != 201) throw Exception("Failed to create building");
  }

  static Future<void> deleteBuilding(String token, String buildingId) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/buildings/$buildingId"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (response.statusCode != 200) throw Exception("Failed to delete building");
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

  static Future<void> createRoom(String token, String buildingId, String roomNumber, int floor, double monthlyRent) async {
    final response = await http.post(
      Uri.parse("$baseUrl/rooms"),
      headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
      body: jsonEncode({"building_id": buildingId, "room_number": roomNumber, "floor": floor, "monthly_rent": monthlyRent}),
    );
    if (response.statusCode != 201) throw Exception("Failed to create room");
  }

  static Future<void> deleteRoom(String token, String roomId) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/rooms/$roomId"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (response.statusCode != 200) throw Exception("Failed to delete room");
  }

  static Future<void> updateRoom(String token, String roomId, Map<String, dynamic> data) async {
    await http.put(
      Uri.parse("$baseUrl/rooms/$roomId"),
      headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
      body: jsonEncode(data),
    );
  }

  static Future<List<dynamic>> getTenants(String token) async {
    final response = await http.get(
        Uri.parse("$baseUrl/tenants"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
    );

    if (response.statusCode == 200) {
        return jsonDecode(response.body);
    } else {
        throw Exception("Failed to load tenants");
    }
  }

  static Future<void> createTenant(String token, String name, String phone, String roomId) async {
    await http.post(
      Uri.parse("$baseUrl/tenants"),
      headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
      body: jsonEncode({"name": name, "phone": phone, "room_id": roomId}),
    );
  }

  static Future<void> updateTenant(String token, String tenantId, Map<String, dynamic> data) async {
    await http.patch(
      Uri.parse("$baseUrl/tenants/$tenantId"),
      headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
      body: jsonEncode(data),
    );
  }

  static Future<void> deactivateTenant(String token, String tenantId) async {
    await http.delete(
      Uri.parse("$baseUrl/tenants/$tenantId"),
      headers: {"Authorization": "Bearer $token"},
    );
  }

  static Future<void> setTelegramChatId(String token, String tenantId, String chatId) async {
    await http.patch(
      Uri.parse("$baseUrl/tenants/$tenantId/telegram-chat-id"),
      headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
      body: jsonEncode({"telegram_chat_id": chatId}),
    );
  }

  static Future<Map<String, dynamic>?> getCurrentBill(String token, String tenantId) async {
    final response = await http.get(
        Uri.parse("$baseUrl/tenants/$tenantId/current-bill"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
    );

    if (response.statusCode == 200) {
        if (response.body == "null") return null;
            return jsonDecode(response.body);
    } else {
            throw Exception("Failed to load bill");
    }
  }

  static Future<void> markBillPaid(String token, String billId) async {
    final response = await http.patch(
        Uri.parse("$baseUrl/tenants/bills/$billId/mark-paid"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
    );

    if (response.statusCode != 200) {
        throw Exception("Failed to mark bill paid");
    }
  }

  static Future<List<dynamic>> getAllBills(String token, String tenantId) async {
    final response = await http.get(
        Uri.parse("$baseUrl/tenants/$tenantId/bills"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
    );

    if (response.statusCode == 200) {
        return jsonDecode(response.body);
    } else {
        throw Exception("Failed to load bills");
    }
  }

  static Future<void> markBillUnpaid(String token, String billId) async {
    final response = await http.patch(
        Uri.parse("$baseUrl/tenants/bills/$billId/mark-unpaid"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
    );

    if (response.statusCode != 200) {
        throw Exception("Failed to mark bill unpaid");
    }
  }

  static Future<void> sendBillTelegram(String token, String tenantId, String month) async {
    final response = await http.post(
      Uri.parse("$baseUrl/tenants/$tenantId/send-bill-telegram"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"month": month}),
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to send bill");
    }
  }

  static Future<Map<String, dynamic>> createBillFromMeters(
      String token, String roomNumber, String month,
      double elecPrev, double elecCurr, double waterPrev, double waterCurr,
      [double elecRate = 400, double waterRate = 15]) async {
    final response = await http.post(
      Uri.parse("$baseUrl/tenants/create-bill-from-meters"),
      headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
      body: jsonEncode({
        "room_number": roomNumber,
        "month": month,
        "elec_prev": elecPrev,
        "elec_curr": elecCurr,
        "water_prev": waterPrev,
        "water_curr": waterCurr,
        "elec_rate": elecRate,
        "water_rate": waterRate,
      }),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(jsonDecode(response.body)["error"] ?? "Failed");
  }

  static Future<Map<String, dynamic>> scanMeterSheet(String token, List<int> imageBytes, String filename) async {
    final uri = Uri.parse("http://localhost:8000/ocr");
    final request = http.MultipartRequest('POST', uri);
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      imageBytes,
      filename: filename,
    ));
    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode == 200) {
      return jsonDecode(body);
    } else {
      throw Exception("OCR failed");
    }
  }

  static Future<Map<String, dynamic>> getDashboard(String token) async {
    final response = await http.get(
      Uri.parse("$baseUrl/dashboard"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to load dashboard");
    }
  }
}
    