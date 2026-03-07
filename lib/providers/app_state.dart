// lib/providers/app_state.dart
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class AppState extends ChangeNotifier {
  // ── Auth ──────────────────────────────────────────────────────────────────
  String _token = '';
  String get token => _token;

  // ── Cached data ───────────────────────────────────────────────────────────
  List<dynamic> buildings = [];
  List<dynamic> rooms = [];
  List<dynamic> tenants = [];
  Map<String, dynamic>? dashboard;

  // ── Loading flags ─────────────────────────────────────────────────────────
  bool loadingBuildings = false;
  bool loadingRooms = false;
  bool loadingTenants = false;
  bool loadingDashboard = false;

  // ── Persistent settings (survive tab switches) ────────────────────────────
  double elecRate = 400;
  double waterRate = 15;
  String currency = '฿';

  // ── Init ──────────────────────────────────────────────────────────────────
  /// Call once right after login. Loads everything in parallel.
  Future<void> init(String token) async {
    _token = token;
    await Future.wait([
      refreshBuildings(),
      refreshRooms(),
      refreshTenants(),
      refreshDashboard(),
    ]);
  }

  // ── Refresh methods (call after mutations) ────────────────────────────────
  Future<void> refreshBuildings() async {
    loadingBuildings = true;
    notifyListeners();
    try {
      buildings = await ApiService.getBuildings(_token);
    } catch (_) {}
    loadingBuildings = false;
    notifyListeners();
  }

  Future<void> refreshRooms() async {
    loadingRooms = true;
    notifyListeners();
    try {
      rooms = await ApiService.getRooms(_token);
    } catch (_) {}
    loadingRooms = false;
    notifyListeners();
  }

  Future<void> refreshTenants() async {
    loadingTenants = true;
    notifyListeners();
    try {
      tenants = await ApiService.getTenants(_token);
    } catch (_) {}
    loadingTenants = false;
    notifyListeners();
  }

  Future<void> refreshDashboard() async {
    loadingDashboard = true;
    notifyListeners();
    try {
      dashboard = await ApiService.getDashboard(_token);
    } catch (_) {}
    loadingDashboard = false;
    notifyListeners();
  }

  /// Refresh everything that changes when a bill is created/updated.
  Future<void> refreshAfterBilling() async {
    await Future.wait([refreshDashboard(), refreshTenants()]);
  }

  /// Refresh everything that changes when a tenant is added/removed.
  Future<void> refreshAfterTenantChange() async {
    await Future.wait([refreshTenants(), refreshRooms(), refreshDashboard()]);
  }

  // ── Settings setters ──────────────────────────────────────────────────────
  void setElecRate(double v) { elecRate = v; notifyListeners(); }
  void setWaterRate(double v) { waterRate = v; notifyListeners(); }
  void setCurrency(String v) { currency = v; notifyListeners(); }
}