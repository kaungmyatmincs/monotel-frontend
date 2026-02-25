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
    String token,
    String roomNumber,
    String month,
    double elecPrev,
    double elecCurr,
    double waterPrev,
    double waterCurr,
  ) async {
    final response = await http.post(
      Uri.parse("$baseUrl/tenants/create-bill-from-meters"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "room_number": roomNumber,
        "month": month,
        "elec_prev": elecPrev,
        "elec_curr": elecCurr,
        "water_prev": waterPrev,
        "water_curr": waterCurr,
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error["error"] ?? "Failed to create bill");
    }
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
}
    