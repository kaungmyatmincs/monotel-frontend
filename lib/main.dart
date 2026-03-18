import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const MonotelApp(),
    ),
  );
}

class MonotelApp extends StatelessWidget {
  const MonotelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginScreen(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOGIN
// ─────────────────────────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;
  String error = '';

  void handleLogin() async {
    setState(() { loading = true; error = ''; });
    try {
      final result = await ApiService.login(
        emailController.text,
        passwordController.text,
      );
      final token = result['token'] as String;

      // Load ALL data in parallel before navigating
      if (!mounted) return;
      await context.read<AppState>().init(token);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminLayout()),
      );
    } catch (e) {
      setState(() { error = 'Invalid credentials'; loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Monotel', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                onSubmitted: (_) => loading ? null : handleLogin(),
              ),
              const SizedBox(height: 20),
              if (error.isNotEmpty)
                Text(error, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading ? null : handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D4A3E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: loading
                      ? const SizedBox(height: 18, width: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN LAYOUT — IndexedStack keeps pages alive, no rebuild on tab switch
// ─────────────────────────────────────────────────────────────────────────────

class AdminLayout extends StatefulWidget {
  const AdminLayout({super.key});

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) => setState(() => selectedIndex = index),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text('Dashboard')),
              NavigationRailDestination(icon: Icon(Icons.apartment), label: Text('Buildings')),
              NavigationRailDestination(icon: Icon(Icons.meeting_room), label: Text('Rooms')),
              NavigationRailDestination(icon: Icon(Icons.people), label: Text('Tenants')),
              NavigationRailDestination(icon: Icon(Icons.receipt), label: Text('Billing')),
              NavigationRailDestination(icon: Icon(Icons.assignment), label: Text('Forms')),
              NavigationRailDestination(icon: Icon(Icons.badge), label: Text('Residents')),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            // IndexedStack: ALL pages stay mounted — zero rebuild, zero reload
            child: IndexedStack(
              index: selectedIndex,
              children: const [
                DashboardPage(),
                BuildingsPage(),
                RoomsPage(),
                TenantsPage(),
                BillingPage(),   // ← swapped
                FormsPage(),
                ResidentsPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD
// ─────────────────────────────────────────────────────────────────────────────

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _filter = 'paid';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.loadingDashboard && state.dashboard == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final data = state.dashboard;
    if (data == null) return const Center(child: Text('Failed to load'));

    final monthly = (_filter == 'all'
        ? data['all_monthly_revenue']
        : _filter == 'unpaid'
            ? data['unpaid_bills']
            : data['monthly_revenue']) as List<dynamic>;

    final unpaidBills = data['unpaid_bills'] as List<dynamic>;
    final totalCollected = double.parse(data['total_collected'].toString());
    final totalUnpaid = double.parse(data['total_unpaid'].toString());
    final totalMoney = totalCollected + totalUnpaid;
    final collectionRate = totalMoney > 0 ? (totalCollected / totalMoney * 100) : 0.0;
    final totalBills = int.parse(data['total_bills'].toString());
    final paidBills = int.parse(data['paid_bills'].toString());
    final maxRevenue = monthly.isEmpty
        ? 1.0
        : monthly
            .map((m) => double.parse((m['revenue'] ?? m['amount'] ?? '0').toString()))
            .reduce((a, b) => a > b ? a : b);

    return Container(
      color: const Color(0xFFF5F5F0),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Dashboard', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () => context.read<AppState>().refreshDashboard(),
                      tooltip: 'Refresh',
                    ),
                  ]),
                  const SizedBox(height: 20),
                  Row(children: [
                    _statCard('Collected', '฿${data['total_collected']}', Icons.check_circle_outline, const Color(0xFF2D4A3E)),
                    const SizedBox(width: 12),
                    _statCard('Unpaid', '฿${data['total_unpaid']}', Icons.warning_amber_outlined, const Color(0xFF8B2635)),
                    const SizedBox(width: 12),
                    _statCard('Tenants', '${data['total_tenants']}', Icons.people_outline, const Color(0xFF1A3A5C)),
                    const SizedBox(width: 12),
                    _statCard('Occupancy', '${data['occupied_rooms']}/${data['total_rooms']}', Icons.bed_outlined, const Color(0xFF5C4A1A)),
                  ]),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('Collection Rate', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('${collectionRate.toStringAsFixed(1)}%  •  $paidBills/$totalBills bills paid',
                            style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ]),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: collectionRate / 100,
                          minHeight: 12,
                          backgroundColor: Colors.grey[200],
                          color: const Color(0xFF2D4A3E),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Monthly Revenue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        _filterBtn('Paid', _filter == 'paid', () => setState(() => _filter = 'paid')),
                        _filterBtn('All', _filter == 'all', () => setState(() => _filter = 'all')),
                        _filterBtn('Unpaid', _filter == 'unpaid', () => setState(() => _filter = 'unpaid')),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Expanded(
                    child: monthly.isEmpty
                        ? const Center(child: Text('No data'))
                        : ListView.builder(
                            itemCount: monthly.length,
                            itemBuilder: (context, index) {
                              final m = monthly[index];
                              final revenue = double.parse((m['revenue'] ?? m['amount'] ?? '0').toString());
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(children: [
                                  SizedBox(
                                    width: 80,
                                    child: Text(m['month'] ?? m['tenant_name'] ?? '',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  ),
                                  Expanded(
                                    child: Stack(children: [
                                      Container(height: 26, decoration: BoxDecoration(
                                          color: Colors.grey[200], borderRadius: BorderRadius.circular(6))),
                                      FractionallySizedBox(
                                        widthFactor: revenue / maxRevenue,
                                        child: Container(height: 26, decoration: BoxDecoration(
                                            color: const Color(0xFF2D4A3E), borderRadius: BorderRadius.circular(6))),
                                      ),
                                    ]),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 80,
                                    child: Text('฿${revenue.toStringAsFixed(0)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                        textAlign: TextAlign.right),
                                  ),
                                ]),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            SizedBox(
              width: 280,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 56),
                  Row(children: [
                    const Text('Outstanding Bills', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFF8B2635), borderRadius: BorderRadius.circular(10)),
                      child: Text('${unpaidBills.length}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Expanded(
                    child: unpaidBills.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                            child: const Center(child: Text('All bills paid! 🎉', style: TextStyle(color: Colors.green))),
                          )
                        : ListView.builder(
                            itemCount: unpaidBills.length,
                            itemBuilder: (context, index) {
                              final bill = unpaidBills[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: const Border(left: BorderSide(color: Color(0xFF8B2635), width: 3)),
                                ),
                                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(bill['tenant_name'],
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text(bill['month'], style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                  ]),
                                  Text('฿${bill['amount']}',
                                      style: const TextStyle(color: Color(0xFF8B2635), fontWeight: FontWeight.bold)),
                                ]),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _filterBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF2D4A3E) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: TextStyle(
            color: active ? Colors.white : Colors.grey,
            fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BUILDINGS
// ─────────────────────────────────────────────────────────────────────────────

class BuildingsPage extends StatelessWidget {
  const BuildingsPage({super.key});

  void _showAddBuilding(BuildContext context) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Building'),
        content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Building Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ApiService.createBuilding(context.read<AppState>().token, nameCtrl.text.trim());
              if (!context.mounted) return;
              Navigator.pop(context);
              context.read<AppState>().refreshBuildings();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showBuildingDetail(BuildContext context, Map<String, dynamic> building, List<dynamic> allRooms) {
    final rooms = allRooms.where((r) => r['building_id'] == building['id']).toList();
    final occupied = rooms.where((r) => r['is_occupied'] == true).length;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(building['name']),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _detailRow('Total Rooms', '${rooms.length}'),
          _detailRow('Occupied', '$occupied'),
          _detailRow('Vacant', '${rooms.length - occupied}'),
          if (rooms.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Rooms:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: rooms.map((r) {
                final occ = r['is_occupied'] == true;
                return Chip(
                  label: Text(r['room_number']),
                  backgroundColor: occ ? Colors.red[100] : Colors.green[100],
                  labelStyle: TextStyle(color: occ ? Colors.red[800] : Colors.green[800], fontSize: 12),
                );
              }).toList(),
            ),
          ],
        ]),
        actions: [
          TextButton(
            onPressed: () async {
              if (rooms.isNotEmpty) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Cannot delete building with rooms. Remove rooms first.'),
                    backgroundColor: Colors.red));
                return;
              }
              Navigator.pop(context);
              final state = context.read<AppState>();
              await ApiService.deleteBuilding(state.token, building['id']);
              state.refreshBuildings();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
      Text(value),
    ]),
  );

  Widget _statChip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
    child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
  );

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final buildings = state.buildings;
    final allRooms = state.rooms;

    if (state.loadingBuildings && buildings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_buildings', 
        onPressed: () => _showAddBuilding(context),
        backgroundColor: const Color(0xFF2D4A3E),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Building', style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('Buildings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF2D4A3E), borderRadius: BorderRadius.circular(20)),
                child: Text('${buildings.length} total', style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 24),
            if (buildings.isEmpty)
              const Center(child: Text('No buildings yet'))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: buildings.length,
                  itemBuilder: (context, index) {
                    final building = buildings[index];
                    final rooms = allRooms.where((r) => r['building_id'] == building['id']).toList();
                    final occupied = rooms.where((r) => r['is_occupied'] == true).length;
                    final vacant = rooms.length - occupied;

                    return GestureDetector(
                      onTap: () => _showBuildingDetail(context, building, allRooms),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D4A3E),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(
                              color: const Color(0xFF2D4A3E).withOpacity(0.25),
                              blurRadius: 8, offset: const Offset(0, 4))],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Row(children: [
                                const Icon(Icons.apartment, color: Colors.white, size: 22),
                                const SizedBox(width: 10),
                                Text(building['name'],
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                              ]),
                              Row(children: [
                                _statChip('$occupied occupied', const Color(0xFF8B2635)),
                                const SizedBox(width: 6),
                                _statChip('$vacant vacant', Colors.green.shade700),
                              ]),
                            ]),
                            if (rooms.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: rooms.map((r) {
                                  final occ = r['is_occupied'] == true;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: occ
                                          ? const Color(0xFF8B2635).withOpacity(0.8)
                                          : Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(r['room_number'],
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROOMS
// ─────────────────────────────────────────────────────────────────────────────

class RoomsPage extends StatelessWidget {
  const RoomsPage({super.key});

  void _showAddRoom(BuildContext context, List<dynamic> buildings) {
    final roomNumCtrl = TextEditingController();
    final floorCtrl = TextEditingController();
    final rentCtrl = TextEditingController();
    String? selectedBuildingId;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Add Room'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Building'),
              value: selectedBuildingId,
              items: buildings.map<DropdownMenuItem<String>>((b) =>
                  DropdownMenuItem(value: b['id'] as String, child: Text(b['name']))).toList(),
              onChanged: (val) => setS(() => selectedBuildingId = val),
            ),
            TextField(controller: roomNumCtrl, decoration: const InputDecoration(labelText: 'Room Number')),
            TextField(controller: floorCtrl, decoration: const InputDecoration(labelText: 'Floor'),
                keyboardType: TextInputType.number),
            TextField(controller: rentCtrl, decoration: const InputDecoration(labelText: 'Monthly Rent'),
                keyboardType: TextInputType.number),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final state = context.read<AppState>();
                await ApiService.createRoom(state.token, selectedBuildingId!, roomNumCtrl.text,
                    int.tryParse(floorCtrl.text) ?? 1, double.tryParse(rentCtrl.text) ?? 0);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                state.refreshRooms();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRoomDetail(BuildContext context, Map<String, dynamic> room, List<dynamic> tenants) {
    final occupied = room['is_occupied'] == true;
    // Look up tenant from cached data — no extra API call!
    final tenant = tenants.firstWhere(
      (t) => t['room_id'] == room['id'] && t['is_active'] == true,
      orElse: () => null,
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Room ${room["room_number"]}'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _detailRow('Building', room['building_name'] ?? '-'),
          _detailRow('Floor', '${room['floor'] ?? '-'}'),
          _detailRow('Monthly Rent', '฿${room['monthly_rent']}'),
          _detailRow('Status', occupied ? 'Occupied' : 'Vacant'),
          _detailRow('Tenant', tenant != null ? tenant['name'] : 'No tenant'),
        ]),
        actions: [
          TextButton(
            onPressed: () async {
              final state = context.read<AppState>();
              Navigator.pop(context);
              await ApiService.deleteRoom(state.token, room['id']);
              state.refreshRooms();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              final state = context.read<AppState>();
              Navigator.pop(context);
              await ApiService.toggleRoom(state.token, room['id']);
              state.refreshRooms();
            },
            child: Text(occupied ? 'Mark Vacant' : 'Mark Occupied'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
      Text(value),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final rooms = state.rooms;
    final buildings = state.buildings;

    if (state.loadingRooms && rooms.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (rooms.isEmpty) return const Center(child: Text('No rooms yet'));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_rooms',
        onPressed: () => _showAddRoom(context, buildings),
        backgroundColor: const Color(0xFF2D4A3E),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Room', style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('Rooms', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF2D4A3E), borderRadius: BorderRadius.circular(20)),
                child: Text('${rooms.length} total', style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: Colors.green[700], borderRadius: BorderRadius.circular(20)),
                child: Text('${rooms.where((r) => r['is_occupied'] != true).length} vacant',
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.7,
                ),
                itemCount: rooms.length,
                itemBuilder: (context, index) {
                  final room = rooms[index];
                  final occupied = room['is_occupied'] == true;
                  return GestureDetector(
                    onTap: () => _showRoomDetail(context, room, state.tenants),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: occupied ? const Color(0xFF8B2635) : const Color(0xFF2D4A3E),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(
                            color: (occupied ? const Color(0xFF8B2635) : const Color(0xFF2D4A3E)).withOpacity(0.3),
                            blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text(room['room_number'],
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                              Icon(occupied ? Icons.person : Icons.bed_outlined, color: Colors.white70, size: 20),
                            ]),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(room['building_name'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text('฿${room['monthly_rent']}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(occupied ? 'Occupied' : 'Vacant',
                                    style: const TextStyle(color: Colors.white, fontSize: 11)),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TENANTS
// ─────────────────────────────────────────────────────────────────────────────

class TenantsPage extends StatefulWidget {
  const TenantsPage({super.key});

  @override
  State<TenantsPage> createState() => _TenantsPageState();
}

class _TenantsPageState extends State<TenantsPage> {
  Map<String, dynamic>? selectedTenant;
  List<dynamic> allBills = [];
  bool loadingBills = false;

  Future<void> _selectTenant(Map<String, dynamic> tenant) async {
    setState(() { loadingBills = true; selectedTenant = tenant; allBills = []; });
    try {
      final bills = await ApiService.getAllBills(context.read<AppState>().token, tenant['id']);
      if (mounted) setState(() { allBills = bills; loadingBills = false; });
    } catch (_) {
      if (mounted) setState(() => loadingBills = false);
    }
  }

  void _showAddTenant(BuildContext context) {
    final state = context.read<AppState>();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String? selectedRoomId;
    final vacantRooms = state.rooms
        .where((r) => r['is_occupied'] == false || r['is_occupied'] == null)
        .toList();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Add Tenant'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name')),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Assign Room'),
              value: selectedRoomId,
              items: vacantRooms.map<DropdownMenuItem<String>>((r) => DropdownMenuItem(
                  value: r['id'] as String,
                  child: Text('Room ${r['room_number']} - ฿${r['monthly_rent']}'))).toList(),
              onChanged: (val) => setS(() => selectedRoomId = val),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (selectedRoomId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a room')));
                  return;
                }
                await ApiService.createTenant(state.token, nameCtrl.text, phoneCtrl.text, selectedRoomId!);
                await ApiService.updateRoom(state.token, selectedRoomId!, {'is_occupied': true});
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                state.refreshAfterTenantChange();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTenant(Map<String, dynamic> tenant) {
    final nameCtrl = TextEditingController(text: tenant['name']);
    final phoneCtrl = TextEditingController(text: tenant['phone'] ?? '');
    final chatIdCtrl = TextEditingController(text: tenant['telegram_chat_id'] ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Tenant'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name')),
          TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
          const SizedBox(height: 16),
          const Divider(),
          const Text('Telegram Integration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          const Text(
            'Tenant: open Telegram → search @userinfobot → send any message → copy the \'Id\' number',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          TextField(
              controller: chatIdCtrl,
              decoration: const InputDecoration(labelText: 'Telegram Chat ID', hintText: 'e.g. 7717304392')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final state = context.read<AppState>();
              await ApiService.updateTenant(state.token, tenant['id'], {
                'name': nameCtrl.text,
                'phone': phoneCtrl.text,
                'telegram_chat_id': chatIdCtrl.text.isEmpty ? null : chatIdCtrl.text,
              });
              Navigator.pop(context);
              await state.refreshTenants();
              // Keep selected tenant in sync
              final updated = state.tenants.firstWhere(
                (t) => t['id'] == tenant['id'], orElse: () => tenant);
              if (mounted) setState(() => selectedTenant = updated);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeactivate(Map<String, dynamic> tenant) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Tenant?'),
        content: Text('${tenant["name"]} will be marked inactive. Their bill history is kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final state = context.read<AppState>();
              // BUG FIX: also free the room when deactivating tenant
          
              await ApiService.deactivateTenant(state.token, tenant['id']);
              if (!mounted) return;
              Navigator.pop(context);
              setState(() { selectedTenant = null; allBills = []; });
              state.refreshAfterTenantChange();
            },
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tenants = state.tenants;

    if (state.loadingTenants && tenants.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Row(
      children: [
        // LEFT: tenant list
        Container(
          width: 220,
          color: const Color(0xFFF0F0EB),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Tenants', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.person_add, color: Color(0xFF2D4A3E)),
                    onPressed: () => _showAddTenant(context),
                    tooltip: 'Add Tenant',
                  ),
                ]),
              ),
              const Divider(height: 1),
              Expanded(
                child: tenants.isEmpty
                    ? const Center(child: Text('No tenants yet'))
                    : ListView.builder(
                        itemCount: tenants.length,
                        itemBuilder: (context, index) {
                          final tenant = tenants[index];
                          final isSelected = selectedTenant?['id'] == tenant['id'];
                          return ListTile(
                            selected: isSelected,
                            selectedTileColor: const Color(0xFF2D4A3E).withOpacity(0.1),
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF2D4A3E),
                              child: Text(tenant['name'][0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontSize: 14)),
                            ),
                            title: Text(tenant['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('Room ${tenant['room_number'] ?? '-'}'),
                            onTap: () => _selectTenant(tenant),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: selectedTenant == null
              ? const Center(child: Text('Select a tenant'))
              : _buildDetail(),
        ),
      ],
    );
  }

  Widget _buildDetail() {
    final tenant = selectedTenant!;
    final hasTelegram = tenant['telegram_chat_id'] != null &&
        tenant['telegram_chat_id'].toString().isNotEmpty;

    return Container(
      color: const Color(0xFFF5F5F0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFF2D4A3E),
                  child: Text(tenant['name'][0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tenant['name'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('Room ${tenant['room_number'] ?? '-'}  •  ${tenant['phone'] ?? 'No phone'}',
                        style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.telegram, size: 14, color: hasTelegram ? Colors.blue : Colors.grey),
                      const SizedBox(width: 4),
                      Text(hasTelegram ? 'Telegram connected' : 'No Telegram',
                          style: TextStyle(fontSize: 12, color: hasTelegram ? Colors.blue : Colors.grey)),
                    ]),
                  ]),
                ),
                IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showEditTenant(tenant)),
                IconButton(
                    icon: const Icon(Icons.person_remove_outlined, color: Colors.red),
                    onPressed: () => _confirmDeactivate(tenant)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Billing History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('${allBills.length} bills', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
          ),
          Expanded(
            child: loadingBills
                ? const Center(child: CircularProgressIndicator())
                : allBills.isEmpty
                    ? const Center(child: Text('No bills yet'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: allBills.length,
                        itemBuilder: (context, index) {
                          final bill = allBills[index];
                          final isPaid = bill['status'] == 'paid';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Text(bill['month'],
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isPaid ? const Color(0xFF2D4A3E) : const Color(0xFF8B2635),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(isPaid ? 'Paid' : 'Unpaid',
                                        style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  ),
                                ]),
                                const SizedBox(height: 10),
                                _billRow('Rent', '฿${bill["rent"]}'),
                                _billRow('Water',
                                  (bill['water_curr'] != null &&
                                          num.tryParse(bill['water_curr'].toString()) != 0)
                                      ? () {
                                          final units = (num.parse(bill['water_curr'].toString()) -
                                                  num.parse(bill['water_prev'].toString()))
                                              .toInt();
                                          final rate = num.tryParse(bill['water_rate'].toString()) ?? 15;
                                          return '฿${bill["water"]} ($units units × ฿$rate)';
                                        }()
                                      : '฿${bill["water"]}'),
                                _billRow('Electricity',
                                  (bill['elec_curr'] != null &&
                                          num.tryParse(bill['elec_curr'].toString()) != 0)
                                      ? () {
                                          final units = (num.parse(bill['elec_curr'].toString()) -
                                                  num.parse(bill['elec_prev'].toString()))
                                              .toInt();
                                          final rate = num.tryParse(bill['elec_rate'].toString()) ?? 400;
                                          return '฿${bill["electricity"]} ($units units × ฿$rate)';
                                        }()
                                      : '฿${bill["electricity"]}'),
                                const Divider(height: 20),
                                _billRow('Total', '฿${bill["amount"]}', isBold: true),
                                const SizedBox(height: 12),
                                Row(children: [
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isPaid ? Colors.orange : const Color(0xFF2D4A3E),
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () async {
                                      final state = context.read<AppState>();
                                      if (isPaid) {
                                        await ApiService.markBillUnpaid(state.token, bill['id']);
                                      } else {
                                        await ApiService.markBillPaid(state.token, bill['id']);
                                      }
                                      final updated = await ApiService.getAllBills(state.token, tenant['id']);
                                      if (mounted) setState(() => allBills = updated);
                                      state.refreshDashboard();
                                    },
                                    child: Text(isPaid ? 'Mark Unpaid' : 'Mark Paid'),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.telegram, size: 16),
                                    label: const Text('Telegram'),
                                    onPressed: hasTelegram
                                        ? () async {
                                            try {
                                              await ApiService.sendBillTelegram(
                                                  context.read<AppState>().token, tenant['id'], bill['month']);
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Sent via Telegram!')));
                                            } catch (_) {
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Failed to send')));
                                            }
                                          }
                                        : null,
                                  ),
                                ]),
                              ]),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _billRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// METER INPUT / BILLING
// ─────────────────────────────────────────────────────────────────────────────

class MeterInputPage extends StatefulWidget {
  const MeterInputPage({super.key});

  @override
  State<MeterInputPage> createState() => _MeterInputPageState();
}

class _MeterInputPageState extends State<MeterInputPage> {
  final roomController = TextEditingController();
  final monthController = TextEditingController();
  final elecPrevController = TextEditingController();
  final elecCurrController = TextEditingController();
  final waterPrevController = TextEditingController();
  final waterCurrController = TextEditingController();

  bool loading = false;
  bool scanning = false;
  bool showRates = false;
  String message = '';
  List<Map<String, dynamic>> scannedRows = [];

  final List<String> currencies = ['฿', 'K', '\$', '€'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    monthController.text = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  double _calcElec(dynamic prev, dynamic curr) =>
      (double.tryParse(curr.toString()) ?? 0) - (double.tryParse(prev.toString()) ?? 0);

  void _scanSheet() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
    if (picked == null) return;

    setState(() { scanning = true; message = ''; scannedRows = []; });
    try {
      final bytes = await picked.readAsBytes();
      final result = await ApiService.scanMeterSheet(
          context.read<AppState>().token, bytes, picked.name);
      final parsed = result['parsed'] as List<dynamic>;
      setState(() {
        scannedRows = parsed.map((e) => Map<String, dynamic>.from(e)).toList();
        if (scannedRows.isNotEmpty) {
          final first = scannedRows[0];
          roomController.text = first['room_number'] ?? '';
          monthController.text = first['month'] ?? monthController.text;
          elecPrevController.text = first['elec_prev']?.toString() ?? '';
          elecCurrController.text = first['elec_curr']?.toString() ?? '';
          waterPrevController.text = first['water_prev']?.toString() ?? '';
          waterCurrController.text = first['water_curr']?.toString() ?? '';
          message = '✅ Scanned ${scannedRows.length} row(s). Review and confirm.';
        }
      });
    } catch (e) {
      setState(() => message = '❌ Scan failed: $e');
    } finally {
      setState(() => scanning = false);
    }
  }

  void _submitAll() async {
    final state = context.read<AppState>();
    setState(() { loading = true; message = 'Processing...'; });
    int successCount = 0;
    try {
      if (scannedRows.isNotEmpty) {
        for (var row in scannedRows) {
          await ApiService.createBillFromMeters(
            state.token,
            row['room_number'].toString(),
            row['month'].toString(),
            (row['elec_prev'] as num).toDouble(),
            (row['elec_curr'] as num).toDouble(),
            (row['water_prev'] as num).toDouble(),
            (row['water_curr'] as num).toDouble(),
            state.elecRate,
            state.waterRate,
          );
          successCount++;
        }
        setState(() { message = '✅ Created $successCount bills.'; scannedRows = []; });
      } else {
        await ApiService.createBillFromMeters(
          state.token,
          roomController.text,
          monthController.text,
          double.tryParse(elecPrevController.text) ?? 0,
          double.tryParse(elecCurrController.text) ?? 0,
          double.tryParse(waterPrevController.text) ?? 0,
          double.tryParse(waterCurrController.text) ?? 0,
          state.elecRate,
          state.waterRate,
        );
        setState(() => message = '✅ Bill created.');
      }
      // Refresh dashboard after billing
      state.refreshAfterBilling();
    } catch (e) {
      setState(() => message = '❌ Failed at bill ${successCount + 1}: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  Widget _field(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Read rates/currency from provider — persists across tab switches!
    final state = context.watch<AppState>();
    final elecRate = state.elecRate;
    final waterRate = state.waterRate;
    final currency = state.currency;

    final elecUnits = scannedRows.isEmpty
        ? _calcElec(elecPrevController.text, elecCurrController.text)
        : 0.0;
    final waterUnits = scannedRows.isEmpty
        ? _calcElec(waterPrevController.text, waterCurrController.text)
        : 0.0;
    final previewElec = elecUnits * elecRate;
    final previewWater = waterUnits * waterRate;

    return Container(
      color: const Color(0xFFF5F5F0),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Meter Input', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),

                    // Rate settings — reads/writes AppState, not local vars
                    GestureDetector(
                      onTap: () => setState(() => showRates = !showRates),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: const Color(0xFF2D4A3E), borderRadius: BorderRadius.circular(10)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text('⚙️ Rate Settings',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Row(children: [
                            Text('$currency  $elecRate/unit elec  •  $waterRate/unit water',
                                style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(width: 8),
                            Icon(showRates ? Icons.expand_less : Icons.expand_more, color: Colors.white),
                          ]),
                        ]),
                      ),
                    ),

                    if (showRates) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration:
                            BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Currency', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 8),
                          Row(
                            children: currencies.map((c) => GestureDetector(
                              onTap: () => context.read<AppState>().setCurrency(c),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: currency == c ? const Color(0xFF2D4A3E) : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(c,
                                    style: TextStyle(
                                        color: currency == c ? Colors.white : Colors.black,
                                        fontWeight: FontWeight.bold)),
                              ),
                            )).toList(),
                          ),
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(
                              child: TextField(
                                keyboardType: TextInputType.number,
                                controller: TextEditingController(text: elecRate.toString())
                                  ..selection = TextSelection.collapsed(offset: elecRate.toString().length),
                                onChanged: (v) {
                                  final d = double.tryParse(v);
                                  if (d != null) context.read<AppState>().setElecRate(d);
                                },
                                decoration: InputDecoration(
                                  labelText: 'Electricity rate per unit',
                                  prefixText: '$currency ',
                                  border: const OutlineInputBorder(),
                                  filled: true, fillColor: Colors.grey[50],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                keyboardType: TextInputType.number,
                                controller: TextEditingController(text: waterRate.toString())
                                  ..selection = TextSelection.collapsed(offset: waterRate.toString().length),
                                onChanged: (v) {
                                  final d = double.tryParse(v);
                                  if (d != null) context.read<AppState>().setWaterRate(d);
                                },
                                decoration: InputDecoration(
                                  labelText: 'Water rate per unit',
                                  prefixText: '$currency ',
                                  border: const OutlineInputBorder(),
                                  filled: true, fillColor: Colors.grey[50],
                                ),
                              ),
                            ),
                          ]),
                        ]),
                      ),
                    ],

                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: scanning ? null : _scanSheet,
                      icon: const Icon(Icons.document_scanner),
                      label: scanning ? const Text('Scanning...') : const Text('Scan Sheet (OCR)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2D4A3E),
                        side: const BorderSide(color: Color(0xFF2D4A3E)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (scannedRows.length > 1) ...[
                      Text('${scannedRows.length} rooms scanned:',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      ...scannedRows.map((row) {
                        final eu = _calcElec(row['elec_prev'], row['elec_curr']);
                        final wu = _calcElec(row['water_prev'], row['water_curr']);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: const Border(left: BorderSide(color: Color(0xFF2D4A3E), width: 3)),
                          ),
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Room ${row["room_number"]}',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text(row['month'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ]),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text('⚡ ${eu.toStringAsFixed(1)} units → $currency${(eu * elecRate).toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 12)),
                              Text('💧 ${wu.toStringAsFixed(1)} units → $currency${(wu * waterRate).toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 12)),
                            ]),
                          ]),
                        );
                      }),
                    ] else ...[
                      _field('Room Number', roomController),
                      _field('Month (YYYY-MM)', monthController),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text('⚡ Electricity', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Row(children: [
                        Expanded(child: _field('Previous Reading', elecPrevController)),
                        const SizedBox(width: 12),
                        Expanded(child: _field('Current Reading', elecCurrController)),
                      ]),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text('💧 Water', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Row(children: [
                        Expanded(child: _field('Previous Reading', waterPrevController)),
                        const SizedBox(width: 12),
                        Expanded(child: _field('Current Reading', waterCurrController)),
                      ]),
                    ],

                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(message,
                          style: TextStyle(color: message.startsWith('✅') ? Colors.green : Colors.red)),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D4A3E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: loading ? null : _submitAll,
                        child: loading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(scannedRows.isNotEmpty
                                ? 'Confirm & Create All Bills'
                                : 'Create Bill',
                                style: const TextStyle(fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 24),

            if (scannedRows.isEmpty)
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Bill Preview',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      _previewRow('Room', roomController.text.isEmpty ? '-' : roomController.text),
                      _previewRow('Month', monthController.text),
                      const Divider(height: 24),
                      _previewRow('Electricity',
                          '${elecUnits.toStringAsFixed(1)} units × $currency$elecRate'),
                      _previewRow('', '$currency${previewElec.toStringAsFixed(0)}'),
                      const SizedBox(height: 8),
                      _previewRow('Water', '${waterUnits.toStringAsFixed(1)} units × $currency$waterRate'),
                      _previewRow('', '$currency${previewWater.toStringAsFixed(0)}'),
                      const Divider(height: 24),
                      _previewRow('Est. Total',
                          '$currency${(previewElec + previewWater).toStringAsFixed(0)}',
                          bold: true),
                      const SizedBox(height: 8),
                      const Text('* Rent added from room settings',
                          style: TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _previewRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        Text(value,
            style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
      ]),
    );
  }
}

class FormsPage extends StatefulWidget {
  const FormsPage({super.key});

  @override
  State<FormsPage> createState() => _FormsPageState();
}

class _FormsPageState extends State<FormsPage> {
  Set<String> selectedRoomIds = {};
  DateTime fromDate = DateTime.now();
  DateTime toDate = DateTime.now().add(const Duration(days: 90));
  bool generating = false;
  String message = '';
  String _lang = 'my';

  // Settings
  bool showSettings = false;
  bool loadingSettings = true;
  bool savingSettings = false;
  String settingsMessage = '';
  final hostNameCtrl = TextEditingController();
  final wardNumberCtrl = TextEditingController();
  final streetNameCtrl = TextEditingController();
  String? hostGender;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    hostNameCtrl.dispose();
    wardNumberCtrl.dispose();
    streetNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final token = context.read<AppState>().token;
      final data = await ApiService.getSettings(token);
      setState(() {
        hostNameCtrl.text = data['host_name'] ?? '';
        wardNumberCtrl.text = data['ward_number'] ?? '';
        streetNameCtrl.text = data['street_name'] ?? '';
        hostGender = data['host_gender'];
        loadingSettings = false;
      });
    } catch (e) {
      setState(() => loadingSettings = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() { savingSettings = true; settingsMessage = ''; });
    try {
      final token = context.read<AppState>().token;
      await ApiService.updateSettings(token, {
        'host_name': hostNameCtrl.text,
        'ward_number': wardNumberCtrl.text,
        'street_name': streetNameCtrl.text,
        'host_gender': hostGender ?? 'female',
      });
      setState(() => settingsMessage = '✅ Saved.');
    } catch (e) {
      setState(() => settingsMessage = '❌ Failed.');
    } finally {
      setState(() => savingSettings = false);
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? fromDate : toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() {
      if (isFrom) fromDate = picked;
      else toDate = picked;
    });
  }

  Future<void> _generate() async {
    if (selectedRoomIds.isEmpty) {
      setState(() => message = 'Please select at least one room.');
      return;
    }
    setState(() { generating = true; message = ''; });
    try {
      final state = context.read<AppState>();
      final token = state.token;
      final roomIds = selectedRoomIds.join(',');
      final from = _formatDate(fromDate);
      final to = _formatDate(toDate);
      final today = _formatDate(DateTime.now());

      final uri = Uri.parse(
        'https://tbhjutc3ux.ap-southeast-2.awsapprunner.com/print/overnight-form'
        '?rooms=$roomIds&from_date=$from&to_date=$to&form_date=$today&lang=$_lang'
      );
      final response = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) {
        final base64Str = base64Encode(response.bodyBytes);
        final dataUri = 'data:application/pdf;base64,$base64Str';
        html.AnchorElement(href: dataUri)
          ..setAttribute('download', 'overnight_form.pdf')
          ..click();
        setState(() => message = '✅ PDF downloaded.');
      } else {
        setState(() => message = '❌ Failed: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => message = '❌ Error: $e');
    } finally {
      setState(() => generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final occupiedRooms = state.rooms.where((r) => r['is_occupied'] == true).toList();

    return Container(
      color: const Color(0xFFF5F5F0),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // LEFT — room selector
            SizedBox(
              width: 280,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Forms', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Overnight Stay Registration',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 20),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Select Rooms',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (selectedRoomIds.length == occupiedRooms.length) {
                            selectedRoomIds.clear();
                          } else {
                            selectedRoomIds = occupiedRooms.map((r) => r['id'] as String).toSet();
                          }
                        });
                      },
                      child: Text(
                        selectedRoomIds.length == occupiedRooms.length ? 'Deselect All' : 'Select All',
                        style: const TextStyle(color: Color(0xFF2D4A3E)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Expanded(
                    child: occupiedRooms.isEmpty
                        ? const Center(child: Text('No occupied rooms'))
                        : ListView.builder(
                            itemCount: occupiedRooms.length,
                            itemBuilder: (context, index) {
                              final room = occupiedRooms[index];
                              final id = room['id'] as String;
                              final selected = selectedRoomIds.contains(id);
                              final tenant = state.tenants.firstWhere(
                                (t) => t['room_id'] == id && t['is_active'] == true,
                                orElse: () => null,
                              );
                              return GestureDetector(
                                onTap: () => setState(() {
                                  if (selected) selectedRoomIds.remove(id);
                                  else selectedRoomIds.add(id);
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: selected ? const Color(0xFF2D4A3E) : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selected ? const Color(0xFF2D4A3E) : Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Row(children: [
                                    Icon(
                                      selected ? Icons.check_box : Icons.check_box_outline_blank,
                                      color: selected ? Colors.white : Colors.grey,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text('Room ${room['room_number']}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: selected ? Colors.white : Colors.black,
                                          )),
                                      if (tenant != null)
                                        Text(tenant['name'],
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: selected ? Colors.white70 : Colors.grey,
                                            )),
                                    ]),
                                  ]),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 24),

            // RIGHT
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 48),

                    // Main options card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Form Language', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 8),
                          Row(children: [
                            ChoiceChip(
                              label: const Text('မြန်မာ'),
                              selected: _lang == 'my',
                              onSelected: (_) => setState(() => _lang = 'my'),
                              selectedColor: const Color(0xFF2D4A3E),
                              labelStyle: TextStyle(color: _lang == 'my' ? Colors.white : Colors.black),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('English'),
                              selected: _lang == 'en',
                              onSelected: (_) => setState(() => _lang = 'en'),
                              selectedColor: const Color(0xFF2D4A3E),
                              labelStyle: TextStyle(color: _lang == 'en' ? Colors.white : Colors.black),
                            ),
                          ]),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 12),
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2D4A3E).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${selectedRoomIds.length} room${selectedRoomIds.length == 1 ? '' : 's'} selected',
                                style: const TextStyle(color: Color(0xFF2D4A3E), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2D4A3E),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              onPressed: generating ? null : _generate,
                              icon: generating
                                  ? const SizedBox(width: 16, height: 16,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.download),
                              label: Text(
                                generating ? 'Generating...' : 'Generate & Download PDF',
                                style: const TextStyle(fontSize: 15),
                              ),
                            ),
                          ),
                          if (message.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(message,
                                style: TextStyle(
                                    color: message.startsWith('✅') ? Colors.green : Colors.red)),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Form Settings collapsible
                    GestureDetector(
                      onTap: () => setState(() => showSettings = !showSettings),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D4A3E),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text('⚙️ Form Settings',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Row(children: [
                            Text(
                              loadingSettings ? '' : '${hostNameCtrl.text}  •  Ward ${wardNumberCtrl.text}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            const SizedBox(width: 8),
                            Icon(showSettings ? Icons.expand_less : Icons.expand_more, color: Colors.white),
                          ]),
                        ]),
                      ),
                    ),

                    if (showSettings) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                        child: loadingSettings
                            ? const Center(child: CircularProgressIndicator())
                            : Column(children: [
                                Row(children: [
                                  Expanded(
                                    child: TextField(
                                      controller: hostNameCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Host Name',
                                        border: OutlineInputBorder(),
                                        filled: true, fillColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: hostGender,
                                      decoration: const InputDecoration(
                                        labelText: 'Gender',
                                        border: OutlineInputBorder(),
                                        filled: true, fillColor: Colors.white,
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: 'male', child: Text('Male (ဦး)')),
                                        DropdownMenuItem(value: 'female', child: Text('Female (ဒေါ်)')),
                                      ],
                                      onChanged: (v) => setState(() => hostGender = v),
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 12),
                                Row(children: [
                                  Expanded(
                                    child: TextField(
                                      controller: wardNumberCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Ward Number',
                                        border: OutlineInputBorder(),
                                        filled: true, fillColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: streetNameCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Street Name',
                                        border: OutlineInputBorder(),
                                        filled: true, fillColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 12),
                                Row(children: [
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2D4A3E),
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: savingSettings ? null : _saveSettings,
                                    child: savingSettings
                                        ? const SizedBox(width: 14, height: 14,
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                        : const Text('Save'),
                                  ),
                                  const SizedBox(width: 12),
                                  if (settingsMessage.isNotEmpty)
                                    Text(settingsMessage,
                                        style: TextStyle(
                                            color: settingsMessage.startsWith('✅') ? Colors.green : Colors.red)),
                                ]),
                              ]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESIDENTS — Full tenant profile management
// ─────────────────────────────────────────────────────────────────────────────

class ResidentsPage extends StatefulWidget {
  const ResidentsPage({super.key});

  @override
  State<ResidentsPage> createState() => _ResidentsPageState();
}

class _ResidentsPageState extends State<ResidentsPage> {
  Map<String, dynamic>? selectedTenant;

  void _selectTenant(Map<String, dynamic> t) {
    setState(() => selectedTenant = t);
  }

  void _showAddResident(BuildContext context) {
    final state = context.read<AppState>();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String? selectedRoomId;
    final vacantRooms = state.rooms
        .where((r) => r['is_occupied'] == false || r['is_occupied'] == null)
        .toList();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Add Resident'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name')),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Assign Room'),
              value: selectedRoomId,
              items: vacantRooms.map<DropdownMenuItem<String>>((r) => DropdownMenuItem(
                  value: r['id'] as String,
                  child: Text('Room ${r['room_number']} - ฿${r['monthly_rent']}'))).toList(),
              onChanged: (val) => setS(() => selectedRoomId = val),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D4A3E), foregroundColor: Colors.white),
              onPressed: () async {
                if (selectedRoomId == null) return;
                await ApiService.createTenant(state.token, nameCtrl.text, phoneCtrl.text, selectedRoomId!);
                await ApiService.updateRoom(state.token, selectedRoomId!, {'is_occupied': true});
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                state.refreshAfterTenantChange();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeactivate(BuildContext context, Map<String, dynamic> tenant) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Resident?'),
        content: Text('${tenant["name"]} will be marked inactive. Bill history is kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              final state = context.read<AppState>();
              await ApiService.deactivateTenant(state.token, tenant['id']);
              if (!mounted) return;
              Navigator.pop(context);
              setState(() => selectedTenant = null);
              state.refreshAfterTenantChange();
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tenants = state.tenants;

    return Row(
      children: [
        // LEFT — tenant list
        Container(
          width: 260,
          color: const Color(0xFFF0F0EB),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Residents', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.person_add, color: Color(0xFF2D4A3E)),
                    onPressed: () => _showAddResident(context),
                  ),
                ]),
              ),
              const Divider(height: 1),
              Expanded(
                child: tenants.isEmpty
                    ? const Center(child: Text('No residents yet'))
                    : ListView.builder(
                        itemCount: tenants.length,
                        itemBuilder: (context, index) {
                          final t = tenants[index];
                          final isSelected = selectedTenant?['id'] == t['id'];
                          return ListTile(
                            selected: isSelected,
                            selectedTileColor: const Color(0xFF2D4A3E).withOpacity(0.1),
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF2D4A3E),
                              child: Text(t['name'][0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontSize: 14)),
                            ),
                            title: Text(t['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('Room ${t['room_number'] ?? '-'}'),
                            onTap: () => _selectTenant(t),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: selectedTenant == null
              ? const Center(child: Text('Select a resident'))
              : _ResidentDetailPanel(
                  key: ValueKey(selectedTenant!['id']),
                  tenant: selectedTenant!,
                  onDeactivate: () => _confirmDeactivate(context, selectedTenant!),
                  onSaved: (updated) {
                    setState(() => selectedTenant = updated);
                    context.read<AppState>().refreshTenants();
                  },
                ),
        ),
      ],
    );
  }
}

class _ResidentDetailPanel extends StatefulWidget {
  final Map<String, dynamic> tenant;
  final VoidCallback onDeactivate;
  final Function(Map<String, dynamic>) onSaved;

  const _ResidentDetailPanel({
    super.key,
    required this.tenant,
    required this.onDeactivate,
    required this.onSaved,
  });

  @override
  State<_ResidentDetailPanel> createState() => _ResidentDetailPanelState();
}

class _ResidentDetailPanelState extends State<_ResidentDetailPanel> {
  late TextEditingController nameCtrl;
  late TextEditingController phoneCtrl;
  late TextEditingController fatherCtrl;
  late TextEditingController motherCtrl;
  late TextEditingController nrcCtrl;
  late TextEditingController ethnicityCtrl;
  late TextEditingController occupationCtrl;
  late TextEditingController relationshipCtrl;
  late TextEditingController prevAddressCtrl;
  late TextEditingController visitPurposeCtrl;
  String? selectedGender;
  DateTime? selectedDob;
  bool saving = false;
  String message = '';

  @override
  void initState() {
    super.initState();
    final t = widget.tenant;
    nameCtrl = TextEditingController(text: t['name'] ?? '');
    phoneCtrl = TextEditingController(text: t['phone'] ?? '');
    fatherCtrl = TextEditingController(text: t['father_name'] ?? '');
    motherCtrl = TextEditingController(text: t['mother_name'] ?? '');
    nrcCtrl = TextEditingController(text: t['nrc_number'] ?? '');
    ethnicityCtrl = TextEditingController(text: t['ethnicity'] ?? '');
    occupationCtrl = TextEditingController(text: t['occupation'] ?? '');
    relationshipCtrl = TextEditingController(text: t['relationship'] ?? '');
    prevAddressCtrl = TextEditingController(text: t['previous_address'] ?? '');
    visitPurposeCtrl = TextEditingController(text: t['visit_purpose'] ?? '');
    selectedGender = t['gender'];
    if (t['date_of_birth'] != null) {
      selectedDob = DateTime.tryParse(t['date_of_birth']);
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose(); phoneCtrl.dispose(); fatherCtrl.dispose();
    motherCtrl.dispose(); nrcCtrl.dispose(); ethnicityCtrl.dispose();
    occupationCtrl.dispose(); relationshipCtrl.dispose();
    prevAddressCtrl.dispose(); visitPurposeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { saving = true; message = ''; });
    try {
      final state = context.read<AppState>();
      final data = {
        'name': nameCtrl.text,
        'phone': phoneCtrl.text,
        'father_name': fatherCtrl.text,
        'mother_name': motherCtrl.text,
        'nrc_number': nrcCtrl.text,
        'ethnicity': ethnicityCtrl.text,
        'occupation': occupationCtrl.text,
        'relationship': relationshipCtrl.text,
        'previous_address': prevAddressCtrl.text,
        'visit_purpose': visitPurposeCtrl.text,
        'gender': selectedGender,
        if (selectedDob != null)
          'date_of_birth': selectedDob!.toIso8601String().substring(0, 10),
      };
      await ApiService.updateTenant(state.token, widget.tenant['id'], data);
      setState(() => message = '✅ Saved.');
      widget.onSaved({...widget.tenant, ...data});
    } catch (e) {
      setState(() => message = '❌ Failed: $e');
    } finally {
      setState(() => saving = false);
    }
  }

  Widget _field(String label, TextEditingController ctrl, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tenant;
    return Container(
      color: const Color(0xFFF5F5F0),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Row(children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF2D4A3E),
                child: Text(t['name'][0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                  Text('Room ${t['room_number'] ?? '-'}',
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ]),
              ),
              TextButton.icon(
                icon: const Icon(Icons.person_remove, color: Colors.red, size: 18),
                label: const Text('Remove', style: TextStyle(color: Colors.red)),
                onPressed: widget.onDeactivate,
              ),
            ]),
          ),
          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Basic Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _field('Full Name', nameCtrl)),
                    const SizedBox(width: 12),
                    Expanded(child: _field('Phone', phoneCtrl)),
                  ]),
                  Row(children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDob ?? DateTime(1990),
                              firstDate: DateTime(1920),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) setState(() => selectedDob = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(children: [
                              const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text('Date of Birth', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                Text(
                                  selectedDob != null
                                      ? '${selectedDob!.year}-${selectedDob!.month.toString().padLeft(2,'0')}-${selectedDob!.day.toString().padLeft(2,'0')}'
                                      : 'Select date',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ]),
                            ]),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DropdownButtonFormField<String>(
                          value: selectedGender,
                          decoration: const InputDecoration(
                            labelText: 'Gender',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'male', child: Text('Male')),
                            DropdownMenuItem(value: 'female', child: Text('Female')),
                          ],
                          onChanged: (v) => setState(() => selectedGender = v),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  const Text('Identity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _field('NRC Number', nrcCtrl)),
                    const SizedBox(width: 12),
                    Expanded(child: _field('Ethnicity', ethnicityCtrl)),
                  ]),
                  Row(children: [
                    Expanded(child: _field("Father's Name", fatherCtrl)),
                    const SizedBox(width: 12),
                    Expanded(child: _field("Mother's Name", motherCtrl)),
                  ]),
                  const SizedBox(height: 4),
                  const Text('Stay Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _field('Occupation', occupationCtrl)),
                    const SizedBox(width: 12),
                    Expanded(child: _field('Relationship to Host', relationshipCtrl)),
                  ]),
                  _field('Purpose of Visit', visitPurposeCtrl),
                  _field('Previous Address', prevAddressCtrl, maxLines: 2),
                  const SizedBox(height: 8),
                  Row(children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D4A3E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      ),
                      onPressed: saving ? null : _save,
                      child: saving
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Save Changes'),
                    ),
                    const SizedBox(width: 12),
                    if (message.isNotEmpty)
                      Text(message,
                          style: TextStyle(
                              color: message.startsWith('✅') ? Colors.green : Colors.red)),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Billing — Full bill receipt managment
// ─────────────────────────────────────────────────────────────────────────────

class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  List<dynamic> _rooms = [];
  List<dynamic> _bills = [];
  dynamic _selectedRoom;
  bool _loadingRooms = true;
  bool _loadingBills = false;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    final token = context.read<AppState>().token;
    final rooms = await ApiService.getRooms(token);
    // Only occupied rooms make sense for billing
    setState(() {
      _rooms = rooms.where((r) => r['is_occupied'] == true).toList();
      _loadingRooms = false;
    });
  }

  Future<void> _loadBills(String roomId) async {
    setState(() => _loadingBills = true);
    final token = context.read<AppState>().token;
    final bills = await ApiService.getBillsByRoom(token, roomId);
    setState(() {
      _bills = bills;
      _loadingBills = false;
    });
  }

  void _selectRoom(dynamic room) {
    setState(() {
      _selectedRoom = room;
      _bills = [];
    });
    _loadBills(room['id']);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Left: Room list ──────────────────────────────────────────────────
        Container(
          width: 220,
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Text("Rooms", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: _loadingRooms
                    ? const Center(child: CircularProgressIndicator())
                    : _rooms.isEmpty
                        ? const Center(child: Text("No occupied rooms", style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            itemCount: _rooms.length,
                            itemBuilder: (context, i) {
                              final room = _rooms[i];
                              final selected = _selectedRoom?['id'] == room['id'];
                              return ListTile(
                                selected: selected,
                                selectedTileColor: Colors.blue.shade50,
                                leading: CircleAvatar(
                                  backgroundColor: selected ? Colors.blue : Colors.grey.shade200,
                                  child: Text(
                                    room['room_number'] ?? '',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: selected ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ),
                                title: Text("Room ${room['room_number']}", style: const TextStyle(fontSize: 13)),
                                subtitle: Text(
                                  "${double.tryParse(room['monthly_rent'].toString())?.toStringAsFixed(0) ?? '—'} ks/mo",
                                  style: const TextStyle(fontSize: 11),
                                ),
                                onTap: () => _selectRoom(room),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),

        // ── Right: Bills panel ───────────────────────────────────────────────
        Expanded(
          child: _selectedRoom == null
              ? const Center(child: Text("Select a room to view bills", style: TextStyle(color: Colors.grey)))
              : _BillsPanel(
                  room: _selectedRoom,
                  bills: _bills,
                  loading: _loadingBills,
                  onRefresh: () => _loadBills(_selectedRoom['id']),
                ),
        ),
      ],
    );
  }
}

// ── Bills Panel ───────────────────────────────────────────────────────────────

class _BillsPanel extends StatelessWidget {
  final dynamic room;
  final List<dynamic> bills;
  final bool loading;
  final VoidCallback onRefresh;

  const _BillsPanel({
    required this.room,
    required this.bills,
    required this.loading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Room ${room['room_number']}", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  Text("${double.tryParse(room['monthly_rent'].toString())?.toStringAsFixed(0) ?? '—'} ks/month rent",
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showCreateBillDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text("New Bill"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),

        // Bills list
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : bills.isEmpty
                  ? const Center(child: Text("No bills yet for this room", style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: bills.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _BillCard(
                        bill: bills[i],
                        onRefresh: onRefresh,
                      ),
                    ),
        ),
      ],
    );
  }

  void _showCreateBillDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreateBillDialog(room: room, onCreated: onRefresh),
    );
  }
}

// ── Bill Card ─────────────────────────────────────────────────────────────────

class _BillCard extends StatelessWidget {
  final dynamic bill;
  final VoidCallback onRefresh;

  const _BillCard({required this.bill, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final isPaid = bill['status'] == 'paid';
    final amount = double.tryParse(bill['amount'].toString())?.toStringAsFixed(0) ?? '0';
    final extras = bill['extra_charges'] is List
        ? bill['extra_charges'] as List
        : jsonDecode(bill['extra_charges'] ?? '[]') as List;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row
            Row(
              children: [
                Text(bill['month'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isPaid ? Colors.green.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isPaid ? Colors.green.shade200 : Colors.orange.shade200),
                  ),
                  child: Text(
                    isPaid ? "Paid" : "Unpaid",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isPaid ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                  ),
                ),
                const Spacer(),
                Text("${_fmtNum(int.parse(amount))} ks",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            // Breakdown
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _chip(Icons.home_outlined, "Rent: ${_fmt(bill['rent'])} ks"),
                _chip(Icons.flash_on_outlined, "Elec: ${_fmt(bill['electricity'])} ks (${_units(bill['elec_prev'], bill['elec_curr'])} u)"),
                _chip(Icons.water_drop_outlined, "Water: ${_fmt(bill['water'])} ks (${_units(bill['water_prev'], bill['water_curr'])} u)"),
                if (extras.isNotEmpty)
                  ...extras.map((e) => _chip(Icons.add_circle_outline, "${e['label']}: ${_fmt(e['amount'])} ks")),
              ],
            ),
            const SizedBox(height: 12),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Receipt MY
                TextButton.icon(
                  onPressed: () => _downloadReceipt(context, bill['id'], 'my'),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text("မြန်မာ PDF"),
                  style: TextButton.styleFrom(foregroundColor: Colors.teal),
                ),
                // Receipt EN
                TextButton.icon(
                  onPressed: () => _downloadReceipt(context, bill['id'], 'en'),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text("Eng PDF"),
                  style: TextButton.styleFrom(foregroundColor: Colors.teal.shade300),
                ),
                const SizedBox(width: 4),
                // Pay / Unpay
                if (!isPaid)
                  TextButton.icon(
                    onPressed: () => _payBill(context),
                    icon: Icon(isPaid ? Icons.cancel_outlined : Icons.check_circle_outline, size: 16),
                    label: Text(isPaid ? "Mark Unpaid" : "Mark Paid"),
                    style: TextButton.styleFrom(foregroundColor: isPaid ? Colors.orange : Colors.green),
                  ),
                // Delete
                TextButton.icon(
                  onPressed: () => _deleteBill(context),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text("Delete"),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  String _fmtNum(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  Widget _chip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey.shade600),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      ],
    );
  }

  String _fmt(dynamic v) {
    if (v == null) return '0';
    if (v is String) return (double.tryParse(v) ?? 0).toStringAsFixed(0);
    return (v as num).toStringAsFixed(0);
  }

  String _units(dynamic prev, dynamic curr) {
    if (prev == null || curr == null) return '0';
    final p = prev is String ? double.tryParse(prev) ?? 0 : (prev as num).toDouble();
    final c = curr is String ? double.tryParse(curr) ?? 0 : (curr as num).toDouble();
    return (c - p).toStringAsFixed(0);
  }

  Future<void> _downloadReceipt(BuildContext context, String billId, String lang) async {
    try {
      final token = context.read<AppState>().token;
      final bytes = await ApiService.getReceiptPdf(token, billId, lang: lang);
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'receipt_${bill['month']}_$lang.pdf')
        ..click();
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to download receipt: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _payBill(BuildContext context) async {
    final token = context.read<AppState>().token;
    final isPaid = bill['status'] == 'paid';
    try {
      if (isPaid) {
        await ApiService.markBillUnpaid(token, bill['id']);
      } else {
        await ApiService.payBill(token, bill['id']);
      }
      onRefresh();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteBill(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Bill"),
        content: Text("Delete bill for ${bill['month']}? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    final token = context.read<AppState>().token;
    try {
      await ApiService.deleteBill(token, bill['id']);
      onRefresh();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }
}

// ── Create Bill Dialog ────────────────────────────────────────────────────────

class _CreateBillDialog extends StatefulWidget {
  final dynamic room;
  final VoidCallback onCreated;

  const _CreateBillDialog({required this.room, required this.onCreated});

  @override
  State<_CreateBillDialog> createState() => _CreateBillDialogState();
}

class _CreateBillDialogState extends State<_CreateBillDialog> {
  final _monthCtrl = TextEditingController();
  final _elecPrevCtrl = TextEditingController();
  final _elecCurrCtrl = TextEditingController();
  final _elecRateCtrl = TextEditingController(text: '250');
  final _waterPrevCtrl = TextEditingController();
  final _waterCurrCtrl = TextEditingController();
  final _waterRateCtrl = TextEditingController(text: '15');

  // Extra charges list: [{labelCtrl, amountCtrl, remarkCtrl}]
  final List<Map<String, TextEditingController>> _extras = [];

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Default month to current YYYY-MM
    final now = DateTime.now();
    _monthCtrl.text = "${now.year}-${now.month.toString().padLeft(2, '0')}";
  }

  void _addExtra() {
    setState(() {
      _extras.add({
        'label': TextEditingController(),
        'amount': TextEditingController(),
        'remark': TextEditingController(),
      });
    });
  }

  void _removeExtra(int i) {
    setState(() => _extras.removeAt(i));
  }

  Future<void> _submit() async {
    setState(() { _saving = true; _error = null; });

    final elecPrev = double.tryParse(_elecPrevCtrl.text) ?? 0;
    final elecCurr = double.tryParse(_elecCurrCtrl.text) ?? 0;
    final elecRate = double.tryParse(_elecRateCtrl.text) ?? 250;
    final waterPrev = double.tryParse(_waterPrevCtrl.text) ?? 0;
    final waterCurr = double.tryParse(_waterCurrCtrl.text) ?? 0;
    final waterRate = double.tryParse(_waterRateCtrl.text) ?? 15;

    final extraCharges = _extras.map((e) => {
      'label': e['label']!.text,
      'amount': double.tryParse(e['amount']!.text) ?? 0,
      'remark': e['remark']!.text,
    }).where((e) => (e['label'] as String).isNotEmpty).toList();

    try {
      final token = context.read<AppState>().token;
      final tenants = await ApiService.getTenants(token);
      final tenant = tenants.firstWhere(
        (t) => t['room_id'] == widget.room['id'] && t['is_active'] == true,
        orElse: () => null,
      );

      if (tenant == null) {
        setState(() { _error = "No active tenant in this room"; _saving = false; });
        return;
      }

      try {
        await ApiService.createBill(
          token,
          tenantId: tenant['id'],
          month: _monthCtrl.text.trim(),
          elecPrev: elecPrev, elecCurr: elecCurr, elecRate: elecRate,
          waterPrev: waterPrev, waterCurr: waterCurr, waterRate: waterRate,
          extraCharges: extraCharges.cast<Map<String, dynamic>>(),
        );
        if (!mounted) return;
        Navigator.pop(context);
        widget.onCreated();
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('already exists') || msg.contains('duplicate') || msg.contains('unique')) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Bill Already Exists"),
              content: Text("A bill for ${_monthCtrl.text.trim()} already exists. Override it?"),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Override"),
                ),
              ],
            ),
          );
          if (confirm != true) { setState(() => _saving = false); return; }
          try {
            final bills = await ApiService.getBillsByRoom(token, widget.room['id']);
            final existing = bills.firstWhere(
              (b) => b['month'] == _monthCtrl.text.trim(),
              orElse: () => null,
            );
            if (existing != null) await ApiService.deleteBill(token, existing['id']);
            await ApiService.createBill(
              token,
              tenantId: tenant['id'],
              month: _monthCtrl.text.trim(),
              elecPrev: elecPrev, elecCurr: elecCurr, elecRate: elecRate,
              waterPrev: waterPrev, waterCurr: waterCurr, waterRate: waterRate,
              extraCharges: extraCharges.cast<Map<String, dynamic>>(),
            );
            if (!mounted) return;
            Navigator.pop(context);
            widget.onCreated();
          } catch (e2) {
            setState(() { _error = e2.toString().replaceFirst("Exception: ", ""); _saving = false; });
          }
        } else {
          setState(() { _error = msg.replaceFirst("Exception: ", ""); _saving = false; });
        }
      }
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst("Exception: ", ""); _saving = false; });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 640),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("New Bill — Room ${widget.room['room_number']}",
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Month
                    _field("Month (YYYY-MM)", _monthCtrl),
                    const SizedBox(height: 12),

                    // Electricity
                    const Text("Electricity", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(child: _field("Prev Reading", _elecPrevCtrl, numeric: true)),
                      const SizedBox(width: 8),
                      Expanded(child: _field("Curr Reading", _elecCurrCtrl, numeric: true)),
                      const SizedBox(width: 8),
                      Expanded(child: _field("Rate (ks/unit)", _elecRateCtrl, numeric: true)),
                    ]),
                    const SizedBox(height: 12),

                    // Water
                    const Text("Water", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(child: _field("Prev Reading", _waterPrevCtrl, numeric: true)),
                      const SizedBox(width: 8),
                      Expanded(child: _field("Curr Reading", _waterCurrCtrl, numeric: true)),
                      const SizedBox(width: 8),
                      Expanded(child: _field("Rate (ks/unit)", _waterRateCtrl, numeric: true)),
                    ]),
                    const SizedBox(height: 16),

                    // Extra charges
                    Row(
                      children: [
                        const Text("Extra Charges", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _addExtra,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text("Add"),
                        ),
                      ],
                    ),
                    ..._extras.asMap().entries.map((entry) {
                      final i = entry.key;
                      final e = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(flex: 3, child: _field("Description (e.g. Light bulb)", e['label']!)),
                            const SizedBox(width: 8),
                            Expanded(flex: 2, child: _field("Amount (ks)", e['amount']!, numeric: true)),
                            const SizedBox(width: 8),
                            Expanded(flex: 2, child: _field("Remark", e['remark']!)),
                            IconButton(
                              onPressed: () => _removeExtra(i),
                              icon: const Icon(Icons.close, size: 18, color: Colors.red),
                            ),
                          ],
                        ),
                      );
                    }),

                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  child: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text("Create Bill"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {bool numeric = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }
}















































