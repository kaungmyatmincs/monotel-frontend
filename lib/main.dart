import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

void main() {
  runApp(const MonotelApp());
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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;
  String error = "";

  void handleLogin() async {
    setState(() {
      loading = true;
      error = "";
    });

    try {
      final result = await ApiService.login(
        emailController.text,
        passwordController.text,
      );

      final token = result["token"];

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AdminLayout(token: token),
        ),
      );
    } catch (e) {
      setState(() {
        error = "Invalid credentials";
        loading = false;
      });
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
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: "Email"),
              ),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Password"),
              ),
              const SizedBox(height: 20),
              if (error.isNotEmpty)
                Text(error, style: const TextStyle(color: Colors.red)),
              ElevatedButton(
                onPressed: loading ? null : handleLogin,
                child: loading
                    ? const CircularProgressIndicator()
                    : const Text("Login"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminLayout extends StatefulWidget {
  final String token;

  const AdminLayout({super.key, required this.token});

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  int selectedIndex = 0;

  final List<String> pages = [
    "Dashboard",
    "Buildings",
    "Rooms",
    "Tenants",
    "Billing"
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                  icon: Icon(Icons.dashboard), label: Text("Dashboard")),
              NavigationRailDestination(
                  icon: Icon(Icons.apartment), label: Text("Buildings")),
              NavigationRailDestination(
                  icon: Icon(Icons.meeting_room), label: Text("Rooms")),
              NavigationRailDestination(
                  icon: Icon(Icons.people), label: Text("Tenants")),
              NavigationRailDestination(
                  icon: Icon(Icons.receipt), label: Text("Billing")),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (selectedIndex == 1) {
      return BuildingsPage(token: widget.token);
    }

    if (selectedIndex == 2) {
      return RoomsPage(token: widget.token);
    }

    if (selectedIndex == 3) {
      return TenantsPage(token: widget.token);
    }

    if (selectedIndex == 0) {
      return DashboardPage(token: widget.token);
    }

    if (selectedIndex == 4) {
      return MeterInputPage(token: widget.token);
    }

    return Center(
      child: Text(
        pages[selectedIndex],
        style: const TextStyle(fontSize: 32),
      ),
    );
  }
}

class BuildingsPage extends StatefulWidget {
  final String token;
  const BuildingsPage({super.key, required this.token});

  @override
  State<BuildingsPage> createState() => _BuildingsPageState();
}

class _BuildingsPageState extends State<BuildingsPage> {
  List<dynamic> buildings = [];
  List<dynamic> allRooms = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final b = await ApiService.getBuildings(widget.token);
      final r = await ApiService.getRooms(widget.token);
      setState(() {
        buildings = b;
        allRooms = r;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
    }
  }

  void _showAddBuilding() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Building"),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: "Building Name"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await ApiService.createBuilding(widget.token, nameCtrl.text.trim());
              Navigator.pop(context);
              _load();
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  void _showBuildingDetail(Map<String, dynamic> building) {
    final rooms = allRooms.where((r) => r["building_id"] == building["id"]).toList();
    final occupied = rooms.where((r) => r["is_occupied"] == true).length;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(building["name"]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _detailRow("Total Rooms", "${rooms.length}"),
          _detailRow("Occupied", "$occupied"),
          _detailRow("Vacant", "${rooms.length - occupied}"),
          if (rooms.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text("Rooms:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: rooms.map((r) {
                final occ = r["is_occupied"] == true;
                return Chip(
                  label: Text(r["room_number"]),
                  backgroundColor: occ ? Colors.red[100] : Colors.green[100],
                  labelStyle: TextStyle(color: occ ? Colors.red[800] : Colors.green[800], fontSize: 12),
                );
              }).toList(),
            ),
          ]
        ]),
        actions: [
          TextButton(
            onPressed: () async {
              if (rooms.isNotEmpty) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Cannot delete building with rooms. Remove rooms first."), backgroundColor: Colors.red),
                );
                return;
              }
              Navigator.pop(context);
              await ApiService.deleteBuilding(widget.token, building["id"]);
              _load();
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(value),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBuilding,
        backgroundColor: const Color(0xFF2D4A3E),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Building", style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text("Buildings", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF2D4A3E), borderRadius: BorderRadius.circular(20)),
                child: Text("${buildings.length} total", style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 24),
            if (!loading && buildings.isEmpty)
              const Center(child: Text("No buildings yet"))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: buildings.length,
                  itemBuilder: (context, index) {
                    final building = buildings[index];
                    final rooms = allRooms.where((r) => r["building_id"] == building["id"]).toList();
                    final occupied = rooms.where((r) => r["is_occupied"] == true).length;
                    final vacant = rooms.length - occupied;

                    return GestureDetector(
                      onTap: () => _showBuildingDetail(building),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D4A3E),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2D4A3E).withOpacity(0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Row(children: [
                                const Icon(Icons.apartment, color: Colors.white, size: 22),
                                const SizedBox(width: 10),
                                Text(building["name"],
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                              ]),
                              Row(children: [
                                _statChip("$occupied occupied", const Color(0xFF8B2635)),
                                const SizedBox(width: 6),
                                _statChip("$vacant vacant", Colors.green.shade700),
                              ]),
                            ]),
                            if (rooms.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: rooms.map((r) {
                                  final occ = r["is_occupied"] == true;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: occ
                                          ? const Color(0xFF8B2635).withOpacity(0.8)
                                          : Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      r["room_number"],
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
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

  Widget _statChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
    );
  }
}

class RoomsPage extends StatefulWidget {
  final String token;
  const RoomsPage({super.key, required this.token});

  @override
  State<RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends State<RoomsPage> {
  List<dynamic> rooms = [];
  List<dynamic> buildings = [];
  bool loading = true;

  Future<void> _load() async {
    try {
      final r = await ApiService.getRooms(widget.token);
      final b = await ApiService.getBuildings(widget.token);
      if (mounted) setState(() {
        rooms = r;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _toggleRoom(String roomId) async {
    await ApiService.toggleRoom(widget.token, roomId);
    _load();
  }

  Future<void> _deleteRoom(String roomId) async {
    await ApiService.deleteRoom(widget.token, roomId);
    _load();
  }

  void _showAddRoom() {
    final roomNumCtrl = TextEditingController();
    final floorCtrl = TextEditingController();
    final rentCtrl = TextEditingController();
    String? selectedBuildingId;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text("Add Room"),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: "Building"),
              items: buildings.map<DropdownMenuItem<String>>((b) {
                return DropdownMenuItem(value: b["id"] as String, child: Text(b["name"]));
              }).toList(),
              onChanged: (val) => setS(() => selectedBuildingId = val),
            ),
            TextField(controller: roomNumCtrl, decoration: const InputDecoration(labelText: "Room Number")),
            TextField(controller: floorCtrl, decoration: const InputDecoration(labelText: "Floor"), keyboardType: TextInputType.number),
            TextField(controller: rentCtrl, decoration: const InputDecoration(labelText: "Monthly Rent"), keyboardType: TextInputType.number),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                await ApiService.createRoom(widget.token, selectedBuildingId!, roomNumCtrl.text, int.tryParse(floorCtrl.text) ?? 1, double.tryParse(rentCtrl.text) ?? 0);
                Navigator.pop(ctx);
                _load();
              },
              child: const Text("Add"),
            ),
          ],
        ),
      ),
    );
  }

  void _showRoomDetail(Map<String, dynamic> room) {
    final occupied = room["is_occupied"] == true;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Room ${room["room_number"]}"),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _detailRow("Building", room["building_name"] ?? "-"),
          _detailRow("Floor", "${room["floor"] ?? "-"}"),
          _detailRow("Monthly Rent", "฿${room["monthly_rent"]}"),
          _detailRow("Status", occupied ? "Occupied" : "Vacant"),
          FutureBuilder<List<dynamic>>(
            future: ApiService.getTenants(widget.token),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              final tenant = snapshot.data!.firstWhere(
                (t) => t["room_id"] == room["id"] && t["is_active"] == true,
                orElse: () => null,
              );
              if (tenant == null) return _detailRow("Tenant", "No tenant");
              return _detailRow("Tenant", tenant["name"]);
            },
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteRoom(room["id"]);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _toggleRoom(room["id"]);
            },
            child: Text(occupied ? "Mark Vacant" : "Mark Occupied"),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (!loading && (rooms.isEmpty)) return const Center(child: Text("No rooms yet"));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddRoom,
        backgroundColor: const Color(0xFF2D4A3E),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Room", style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text("Rooms", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF2D4A3E), borderRadius: BorderRadius.circular(20)),
                child: Text("${rooms.length} total", style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: Colors.green[700], borderRadius: BorderRadius.circular(20)),
                child: Text("${rooms.where((r) => r["is_occupied"] != true).length} vacant", style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.6,
                ),
                itemCount: rooms.length,
                itemBuilder: (context, index) {
                  final room = rooms[index];
                  final occupied = room["is_occupied"] == true;
                  return GestureDetector(
                    onTap: () => _showRoomDetail(room),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: occupied ? const Color(0xFF8B2635) : const Color(0xFF2D4A3E),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: (occupied ? const Color(0xFF8B2635) : const Color(0xFF2D4A3E)).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text(
                                room["room_number"],
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              Icon(occupied ? Icons.person : Icons.bed_outlined, color: Colors.white70, size: 20),
                            ]),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(room["building_name"] ?? "", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text("฿${room["monthly_rent"]}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  occupied ? "Occupied" : "Vacant",
                                  style: const TextStyle(color: Colors.white, fontSize: 11),
                                ),
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

class TenantsPage extends StatefulWidget {
  final String token;
  const TenantsPage({super.key, required this.token});

  @override
  State<TenantsPage> createState() => _TenantsPageState();
}

class _TenantsPageState extends State<TenantsPage> {
  List<dynamic> tenants = [];
  List<dynamic> rooms = [];
  List<dynamic> allBills = [];
  Map<String, dynamic>? selectedTenant;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final t = await ApiService.getTenants(widget.token);
    final r = await ApiService.getRooms(widget.token);
    setState(() {
      tenants = t;
      rooms = r;
      loading = false;
    });
  }

  Future<void> _selectTenant(Map<String, dynamic> tenant) async {
    final bills = await ApiService.getAllBills(widget.token, tenant["id"]);
    setState(() {
      selectedTenant = tenant;
      allBills = bills;
    });
  }

  void _showAddTenant() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String? selectedRoomId;
    final vacantRooms = rooms.where((r) => r["is_occupied"] == false || r["is_occupied"] == null).toList();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text("Add Tenant"),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Full Name")),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: "Phone"), keyboardType: TextInputType.phone),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: "Assign Room"),
              value: selectedRoomId,
              items: vacantRooms.map<DropdownMenuItem<String>>((r) =>
                DropdownMenuItem(value: r["id"] as String, child: Text("Room ${r["room_number"]} - ฿${r["monthly_rent"]}"))).toList(),
              onChanged: (val) => setS(() => selectedRoomId = val),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                if (selectedRoomId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please select a room")));
                  return;
                }
                await ApiService.createTenant(widget.token, nameCtrl.text, phoneCtrl.text, selectedRoomId!);
                await ApiService.updateRoom(widget.token, selectedRoomId!, {"is_occupied": true});
                Navigator.pop(ctx);
                _load();
              },
              child: const Text("Add"),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTenant(Map<String, dynamic> tenant) {
    final nameCtrl = TextEditingController(text: tenant["name"]);
    final phoneCtrl = TextEditingController(text: tenant["phone"] ?? "");
    final chatIdCtrl = TextEditingController(text: tenant["telegram_chat_id"] ?? "");

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Tenant"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Full Name")),
          TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: "Phone")),
          const SizedBox(height: 16),
          const Divider(),
          const Text("Telegram Integration", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          const Text(
            "Tenant: open Telegram → search @userinfobot → send any message → copy the 'Id' number",
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          TextField(controller: chatIdCtrl, decoration: const InputDecoration(labelText: "Telegram Chat ID", hintText: "e.g. 7717304392")),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await ApiService.updateTenant(widget.token, tenant["id"], {
                "name": nameCtrl.text,
                "phone": phoneCtrl.text,
                "telegram_chat_id": chatIdCtrl.text.isEmpty ? null : chatIdCtrl.text,
              });
              Navigator.pop(context);
              final updated = await ApiService.getTenants(widget.token);
              setState(() {
                tenants = updated;
                selectedTenant = updated.firstWhere((t) => t["id"] == tenant["id"], orElse: () => tenant);
              });
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _confirmDeactivate(Map<String, dynamic> tenant) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Remove Tenant?"),
        content: Text("${tenant["name"]} will be marked inactive. Their bill history is kept."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ApiService.deactivateTenant(widget.token, tenant["id"]);
              Navigator.pop(context);
              setState(() => selectedTenant = null);
              _load();
            },
            child: const Text("Remove", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    return Row(
      children: [
        // LEFT: tenant list
        Container(
          width: 260,
          color: const Color(0xFFF0F0EB),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text("Tenants", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.person_add, color: Color(0xFF2D4A3E)),
                    onPressed: _showAddTenant,
                    tooltip: "Add Tenant",
                  ),
                ]),
              ),
              const Divider(height: 1),
              Expanded(
                child: tenants.isEmpty
                    ? const Center(child: Text("No tenants yet"))
                    : ListView.builder(
                        itemCount: tenants.length,
                        itemBuilder: (context, index) {
                          final tenant = tenants[index];
                          final isSelected = selectedTenant?["id"] == tenant["id"];
                          return ListTile(
                            selected: isSelected,
                            selectedTileColor: const Color(0xFF2D4A3E).withOpacity(0.1),
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF2D4A3E),
                              child: Text(tenant["name"][0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontSize: 14)),
                            ),
                            title: Text(tenant["name"], style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text("Room ${tenant["room_number"] ?? "-"}"),
                            onTap: () => _selectTenant(tenant),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),

        const VerticalDivider(width: 1),

        // RIGHT: tenant detail
        Expanded(
          child: selectedTenant == null
              ? const Center(child: Text("Select a tenant"))
              : _buildDetail(),
        ),
      ],
    );
  }

  Widget _buildDetail() {
    final tenant = selectedTenant!;
    final hasTelegram = tenant["telegram_chat_id"] != null && tenant["telegram_chat_id"].toString().isNotEmpty;

    return Container(
      color: const Color(0xFFF5F5F0),
      child: Column(
        children: [
          // Tenant profile header
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFF2D4A3E),
                  child: Text(tenant["name"][0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tenant["name"], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text("Room ${tenant["room_number"] ?? "-"}  •  ${tenant["phone"] ?? "No phone"}",
                        style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.telegram, size: 14, color: hasTelegram ? Colors.blue : Colors.grey),
                      const SizedBox(width: 4),
                      Text(hasTelegram ? "Telegram connected" : "No Telegram",
                          style: TextStyle(fontSize: 12, color: hasTelegram ? Colors.blue : Colors.grey)),
                    ]),
                  ]),
                ),
                IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showEditTenant(tenant), tooltip: "Edit"),
                IconButton(icon: const Icon(Icons.person_remove_outlined, color: Colors.red),
                    onPressed: () => _confirmDeactivate(tenant), tooltip: "Remove Tenant"),
              ],
            ),
          ),

          // Bills
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text("Billing History", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text("${allBills.length} bills", style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
          ),

          Expanded(
            child: allBills.isEmpty
                ? const Center(child: Text("No bills yet"))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: allBills.length,
                    itemBuilder: (context, index) {
                      final bill = allBills[index];
                      final isPaid = bill["status"] == "paid";
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text(bill["month"], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isPaid ? const Color(0xFF2D4A3E) : const Color(0xFF8B2635),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(isPaid ? "Paid" : "Unpaid",
                                    style: const TextStyle(color: Colors.white, fontSize: 12)),
                              ),
                            ]),
                            const SizedBox(height: 10),
                            _billRow("Rent", "฿${bill["rent"]}"),
                            _billRow("Water",
                              (bill["water_curr"] != null && num.tryParse(bill["water_curr"].toString()) != 0)
                                ? () {
                                    final units = (num.parse(bill["water_curr"].toString()) - num.parse(bill["water_prev"].toString())).toInt();
                                    final rate = num.tryParse(bill["water_rate"].toString()) ?? 15;
                                    return "฿${bill["water"]} ($units units × ฿$rate)";
                                  }()
                                : "฿${bill["water"]}"),
                            _billRow("Electricity",
                              (bill["elec_curr"] != null && num.tryParse(bill["elec_curr"].toString()) != 0)
                                ? () {
                                    final units = (num.parse(bill["elec_curr"].toString()) - num.parse(bill["elec_prev"].toString())).toInt();
                                    final rate = num.tryParse(bill["elec_rate"].toString()) ?? 400;
                                    return "฿${bill["electricity"]} ($units units × ฿$rate)";
                                  }()
                                : "฿${bill["electricity"]}"),
                            const Divider(height: 20),
                            _billRow("Total", "฿${bill["amount"]}", isBold: true),
                            const SizedBox(height: 12),
                            Row(children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isPaid ? Colors.orange : const Color(0xFF2D4A3E),
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () async {
                                  if (isPaid) {
                                    await ApiService.markBillUnpaid(widget.token, bill["id"]);
                                  } else {
                                    await ApiService.markBillPaid(widget.token, bill["id"]);
                                  }
                                  final updated = await ApiService.getAllBills(widget.token, tenant["id"]);
                                  setState(() => allBills = updated);
                                },
                                child: Text(isPaid ? "Mark Unpaid" : "Mark Paid"),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.telegram, size: 16),
                                label: const Text("Telegram"),
                                onPressed: hasTelegram ? () async {
                                  try {
                                    await ApiService.sendBillTelegram(widget.token, tenant["id"], bill["month"]);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Sent via Telegram!")));
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Failed to send")));
                                  }
                                } : null,
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

class MeterInputPage extends StatefulWidget {
  final String token;
  const MeterInputPage({super.key, required this.token});

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
  final elecRateController = TextEditingController(text: "400");
  final waterRateController = TextEditingController(text: "15");

  String currency = "฿";
  bool loading = false;
  bool scanning = false;
  bool showRates = false;
  String message = "";
  List<Map<String, dynamic>> scannedRows = [];

  final List<String> currencies = ["฿", "K", "\$", "€"];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    monthController.text = "${now.year}-${now.month.toString().padLeft(2, '0')}";
  }

  double get elecRate => double.tryParse(elecRateController.text) ?? 400;
  double get waterRate => double.tryParse(waterRateController.text) ?? 15;

  double _calcElec(dynamic prev, dynamic curr) =>
      (double.tryParse(curr.toString()) ?? 0) - (double.tryParse(prev.toString()) ?? 0);

  void _scanSheet() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
    if (picked == null) return;

    setState(() { scanning = true; message = ""; scannedRows = []; });

    try {
      final bytes = await picked.readAsBytes();
      final result = await ApiService.scanMeterSheet(widget.token, bytes, picked.name);
      final parsed = result["parsed"] as List<dynamic>;

      setState(() {
        scannedRows = parsed.map((e) => Map<String, dynamic>.from(e)).toList();
        if (scannedRows.isNotEmpty) {
          final first = scannedRows[0];
          roomController.text = first["room_number"] ?? "";
          monthController.text = first["month"] ?? monthController.text;
          elecPrevController.text = first["elec_prev"]?.toString() ?? "";
          elecCurrController.text = first["elec_curr"]?.toString() ?? "";
          waterPrevController.text = first["water_prev"]?.toString() ?? "";
          waterCurrController.text = first["water_curr"]?.toString() ?? "";
          message = "✅ Scanned ${scannedRows.length} row(s). Review and confirm.";
        }
      });
    } catch (e) {
      setState(() => message = "❌ Scan failed: ${e.toString()}");
    } finally {
      setState(() => scanning = false);
    }
  }

  void _submitAll() async {
    print("DEBUG rates: elec=$elecRate water=$waterRate");
    setState(() { loading = true; message = "Processing..."; });
    int successCount = 0;

    try {
      if (scannedRows.isNotEmpty) {
        for (var row in scannedRows) {
          await ApiService.createBillFromMeters(
            widget.token,
            row["room_number"].toString(),
            row["month"].toString(),
            (row["elec_prev"] as num).toDouble(),
            (row["elec_curr"] as num).toDouble(),
            (row["water_prev"] as num).toDouble(),
            (row["water_curr"] as num).toDouble(),
            elecRate,
            waterRate,
          );
          successCount++;
        }
        setState(() { message = "✅ Created $successCount bills."; scannedRows = []; });
      } else {
        await ApiService.createBillFromMeters(
          widget.token,
          roomController.text,
          monthController.text,
          double.tryParse(elecPrevController.text) ?? 0,
          double.tryParse(elecCurrController.text) ?? 0,
          double.tryParse(waterPrevController.text) ?? 0,
          double.tryParse(waterCurrController.text) ?? 0,
          elecRate,
          waterRate,
        );
        setState(() => message = "✅ Bill created.");
      }
    } catch (e) {
      setState(() => message = "❌ Failed at bill ${successCount + 1}: $e");
    } finally {
      setState(() => loading = false);
    }
  }

  Widget _field(String label, TextEditingController controller, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            // LEFT — input form
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Meter Input", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),

                    // Rate settings panel
                    GestureDetector(
                      onTap: () => setState(() => showRates = !showRates),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D4A3E),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text("⚙️ Rate Settings", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Row(children: [
                            Text("$currency  $elecRate/unit elec  •  $waterRate/unit water",
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
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text("Currency", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 8),
                          Row(children: currencies.map((c) => GestureDetector(
                            onTap: () => setState(() => currency = c),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: currency == c ? const Color(0xFF2D4A3E) : Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(c, style: TextStyle(
                                  color: currency == c ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold)),
                            ),
                          )).toList()),
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(child: TextField(
                              controller: elecRateController,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                labelText: "Electricity rate per unit",
                                prefixText: "$currency ",
                                border: const OutlineInputBorder(),
                                filled: true, fillColor: Colors.grey[50],
                              ),
                            )),
                            const SizedBox(width: 12),
                            Expanded(child: TextField(
                              controller: waterRateController,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                labelText: "Water rate per unit",
                                prefixText: "$currency ",
                                border: const OutlineInputBorder(),
                                filled: true, fillColor: Colors.grey[50],
                              ),
                            )),
                          ]),
                        ]),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // OCR button
                    OutlinedButton.icon(
                      onPressed: scanning ? null : _scanSheet,
                      icon: const Icon(Icons.document_scanner),
                      label: scanning ? const Text("Scanning...") : const Text("Scan Sheet (OCR)"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2D4A3E),
                        side: const BorderSide(color: Color(0xFF2D4A3E)),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Scanned rows or manual form
                    if (scannedRows.length > 1) ...[
                      Text("${scannedRows.length} rooms scanned:",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      ...scannedRows.map((row) {
                        final eu = _calcElec(row["elec_prev"], row["elec_curr"]);
                        final wu = _calcElec(row["water_prev"], row["water_curr"]);
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
                              Text("Room ${row["room_number"]}", style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text(row["month"], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ]),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text("⚡ ${eu.toStringAsFixed(1)} units → $currency${(eu * elecRate).toStringAsFixed(0)}",
                                  style: const TextStyle(fontSize: 12)),
                              Text("💧 ${wu.toStringAsFixed(1)} units → $currency${(wu * waterRate).toStringAsFixed(0)}",
                                  style: const TextStyle(fontSize: 12)),
                            ]),
                          ]),
                        );
                      }),
                    ] else ...[
                      _field("Room Number", roomController),
                      _field("Month (YYYY-MM)", monthController),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text("⚡ Electricity", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Row(children: [
                        Expanded(child: _field("Previous Reading", elecPrevController)),
                        const SizedBox(width: 12),
                        Expanded(child: _field("Current Reading", elecCurrController)),
                      ]),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text("💧 Water", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Row(children: [
                        Expanded(child: _field("Previous Reading", waterPrevController)),
                        const SizedBox(width: 12),
                        Expanded(child: _field("Current Reading", waterCurrController)),
                      ]),
                    ],

                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(message, style: TextStyle(
                          color: message.startsWith("✅") ? Colors.green : Colors.red)),
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
                            : Text(scannedRows.isNotEmpty ? "Confirm & Create All Bills" : "Create Bill",
                                style: const TextStyle(fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 24),

            // RIGHT — live preview (manual only)
            if (scannedRows.isEmpty)
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Bill Preview", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      _previewRow("Room", roomController.text.isEmpty ? "-" : roomController.text),
                      _previewRow("Month", monthController.text),
                      const Divider(height: 24),
                      _previewRow("Electricity", "${elecUnits.toStringAsFixed(1)} units × $currency$elecRate"),
                      _previewRow("", "$currency${previewElec.toStringAsFixed(0)}"),
                      const SizedBox(height: 8),
                      _previewRow("Water", "${waterUnits.toStringAsFixed(1)} units × $currency$waterRate"),
                      _previewRow("", "$currency${previewWater.toStringAsFixed(0)}"),
                      const Divider(height: 24),
                      _previewRow("Est. Total", "$currency${(previewElec + previewWater).toStringAsFixed(0)}",
                          bold: true),
                      const SizedBox(height: 8),
                      const Text("* Rent added from room settings", style: TextStyle(color: Colors.grey, fontSize: 11)),
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
        Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
      ]),
    );
  }
}

class DashboardPage extends StatefulWidget {
  final String token;
  const DashboardPage({super.key, required this.token});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic>? data;
  bool loading = true;
  String _filter = "paid";

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    try {
      final result = await ApiService.getDashboard(widget.token);
      setState(() { data = result; loading = false; });
    } catch (e) {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (data == null) return const Center(child: Text("Failed to load"));

    final monthly = (_filter == "all"
      ? data!["all_monthly_revenue"]
      : _filter == "unpaid"
          ? data!["unpaid_bills"] as List<dynamic>
          : data!["monthly_revenue"]) as List<dynamic>;

    final unpaidBills = data!["unpaid_bills"] as List<dynamic>;

    final totalCollected = double.parse(data!["total_collected"].toString());
    final totalUnpaid = double.parse(data!["total_unpaid"].toString());
    final totalMoney = totalCollected + totalUnpaid;
    final collectionRate = totalMoney > 0 ? (totalCollected / totalMoney * 100) : 0.0;

    final totalBills = int.parse(data!["total_bills"].toString());
    final paidBills = int.parse(data!["paid_bills"].toString());

    final maxRevenue = monthly.isEmpty ? 1.0 :
        monthly.map((m) => double.parse((m["revenue"] ?? m["amount"] ?? "0").toString())).reduce((a, b) => a > b ? a : b);

    return Container(
      color: const Color(0xFFF5F5F0),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // LEFT COLUMN — stats + chart
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Dashboard", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  // Stat cards
                  Row(children: [
                    _statCard("Collected", "฿${data!["total_collected"]}", Icons.check_circle_outline, const Color(0xFF2D4A3E)),
                    const SizedBox(width: 12),
                    _statCard("Unpaid", "฿${data!["total_unpaid"]}", Icons.warning_amber_outlined, const Color(0xFF8B2635)),
                    const SizedBox(width: 12),
                    _statCard("Tenants", "${data!["total_tenants"]}", Icons.people_outline, const Color(0xFF1A3A5C)),
                    const SizedBox(width: 12),
                    _statCard("Occupancy", "${data!["occupied_rooms"]}/${data!["total_rooms"]}", Icons.bed_outlined, const Color(0xFF5C4A1A)),
                  ]),
                  const SizedBox(height: 20),

                  // Collection rate bar
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text("Collection Rate", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text("${collectionRate.toStringAsFixed(1)}%  •  $paidBills/$totalBills bills paid",
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

                  // Chart header with filter
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text("Monthly Revenue", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        _filterBtn("Paid", _filter == "paid", () => setState(() => _filter = "paid")),
                        _filterBtn("All", _filter == "all", () => setState(() => _filter = "all")),
                        _filterBtn("Unpaid", _filter == "unpaid", () => setState(() => _filter = "unpaid")),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 12),

                  // Chart
                  Expanded(
                    child: monthly.isEmpty
                        ? const Center(child: Text("No data"))
                        : ListView.builder(
                            itemCount: monthly.length,
                            itemBuilder: (context, index) {
                              final m = monthly[index];
                              final revenue = double.parse((m["revenue"] ?? m["amount"] ?? "0").toString());
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(children: [
                                  SizedBox(width: 80, child: Text(m["month"] ?? m["tenant_name"] ?? "",
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
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
                                  SizedBox(width: 80,
                                      child: Text("฿${revenue.toStringAsFixed(0)}",
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                          textAlign: TextAlign.right)),
                                ]),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 24),

            // RIGHT COLUMN — unpaid bills
            SizedBox(
              width: 280,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 56),
                  Row(children: [
                    const Text("Outstanding Bills", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFF8B2635), borderRadius: BorderRadius.circular(10)),
                      child: Text("${unpaidBills.length}", style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Expanded(
                    child: unpaidBills.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                            child: const Center(child: Text("All bills paid! 🎉", style: TextStyle(color: Colors.green))),
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
                                    Text(bill["tenant_name"], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text(bill["month"], style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                  ]),
                                  Text("฿${bill["amount"]}", style: const TextStyle(
                                      color: Color(0xFF8B2635), fontWeight: FontWeight.bold)),
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



