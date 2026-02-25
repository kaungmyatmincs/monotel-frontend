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
  late Future<List<dynamic>> buildingsFuture;

  @override
  void initState() {
    super.initState();
    buildingsFuture = ApiService.getBuildings(widget.token);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: buildingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(child: Text("Error loading buildings"));
        }

        final buildings = snapshot.data ?? [];

        if (buildings.isEmpty) {
          return const Center(child: Text("No buildings yet"));
        }

        return ListView.builder(
          itemCount: buildings.length,
          itemBuilder: (context, index) {
            final building = buildings[index];
            return ListTile(
              title: Text(building["name"]),
            );
          },
        );
      },
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
  late Future<List<dynamic>> roomsFuture;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  void _loadRooms() {
    roomsFuture = ApiService.getRooms(widget.token);
  }

  Future<void> _toggleRoom(String roomId) async {
    await ApiService.toggleRoom(widget.token, roomId);
    setState(() {
      _loadRooms();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: roomsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(child: Text("Error loading rooms"));
        }

        final rooms = snapshot.data ?? [];

        if (rooms.isEmpty) {
          return const Center(child: Text("No rooms yet"));
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: ListView.builder(
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final room = rooms[index];
              final occupied = room["is_occupied"] == true;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Room ${room["room_number"]}",
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text("Building: ${room["building_name"] ?? ""}"),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            occupied ? "Occupied" : "Vacant",
                            style: TextStyle(
                              color:
                                  occupied ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Switch(
                            value: occupied,
                            onChanged: (_) {
                              _toggleRoom(room["id"]);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
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
  List<dynamic> allBills = [];
  late Future<List<dynamic>> tenantsFuture;
  Map<String, dynamic>? selectedTenant;
  Map<String, dynamic>? currentBill;

  @override
  void initState() {
    super.initState();
    tenantsFuture = ApiService.getTenants(widget.token);
  }

  void _selectTenant(Map<String, dynamic> tenant) async {
    final bills =
        await ApiService.getAllBills(widget.token, tenant["id"]);

    setState(() {
      selectedTenant = tenant;
      currentBill = bills.isNotEmpty ? bills.first : null;
      allBills = bills;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: FutureBuilder<List<dynamic>>(
            future: tenantsFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final tenants = snapshot.data!;

              return ListView.builder(
                itemCount: tenants.length,
                itemBuilder: (context, index) {
                  final tenant = tenants[index];

                  return ListTile(
                    title: Text(tenant["name"]),
                    subtitle:
                        Text("Room ${tenant["room_number"] ?? ""}"),
                    onTap: () => _selectTenant(tenant),
                  );
                },
              );
            },
          ),
        ),
        const VerticalDivider(),
        Expanded(
          flex: 2,
          child: selectedTenant == null
              ? const Center(child: Text("Select a tenant"))
              : _buildTenantDetail(),
        )
      ],
    );
  }

  Widget _buildTenantDetail() {
    if (selectedTenant == null) {
      return const Center(child: Text("Select a tenant"));
    }

    if (allBills.isEmpty) {
      return const Center(
        child: Text(
          "No bills found",
          style: TextStyle(fontSize: 18),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            selectedTenant!["name"],
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            "Room ${selectedTenant!["room_number"]}",
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 30),

          const Text(
            "Billing History",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          Expanded(
            child: ListView.builder(
              itemCount: allBills.length,
              itemBuilder: (context, index) {
                final bill = allBills[index];
                final isPaid = bill["status"] == "paid";

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              bill["month"],
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isPaid
                                    ? Colors.green
                                    : Colors.red,
                                borderRadius:
                                    BorderRadius.circular(20),
                              ),
                              child: Text(
                                isPaid ? "Paid" : "Unpaid",
                                style: const TextStyle(
                                    color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _billRow("Rent", bill["rent"]),
                        _billRow("Water", (bill["water_curr"] != null && bill["water_curr"] != 0)
                            ? "${bill["water"]} (${(num.parse(bill["water_curr"].toString()) - num.parse(bill["water_prev"].toString())).toInt()} units)"
                            : "${bill["water"]}"),
                        _billRow("Electricity", (bill["elec_curr"] != null && bill["elec_curr"] != 0)
                            ? "${bill["electricity"]} (${(num.parse(bill["elec_curr"].toString()) - num.parse(bill["elec_prev"].toString())).toInt()} units)"
                            : "${bill["electricity"]}"),
                        const Divider(height: 24),
                        _billRow("Total", bill["total"],
                            isBold: true),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    isPaid ? Colors.orange : Colors.green,
                              ),
                              onPressed: () async {
                                if (isPaid) {
                                  await ApiService.markBillUnpaid(
                                      widget.token, bill["id"]);
                                } else {
                                  await ApiService.markBillPaid(
                                      widget.token, bill["id"]);
                                }

                                final updatedBills =
                                    await ApiService.getAllBills(
                                        widget.token,
                                        selectedTenant!["id"]);

                                setState(() {
                                  allBills = updatedBills;
                                });
                              },
                              child: Text(
                                  isPaid ? "Mark as Unpaid" : "Mark as Paid"),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: () async {
                                try {
                                  await ApiService.sendBillTelegram(
                                    widget.token,
                                    selectedTenant!["id"],
                                    bill["month"],
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Bill sent via Telegram!")),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Failed to send bill")),
                                  );
                                }
                              },
                              child: const Text("Send to Telegram"),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _billRow(String label, dynamic value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
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

  bool loading = false;
  bool scanning = false;
  String message = "";
  List<Map<String, dynamic>> scannedRows = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    monthController.text =
        "${now.year}-${now.month.toString().padLeft(2, '0')}";
  }

  void _scanSheet() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
    if (picked == null) return;

    setState(() {
      scanning = true;
      message = "";
      scannedRows = [];
    });

    try {
      final bytes = await picked.readAsBytes();
      final result = await ApiService.scanMeterSheet(
          widget.token, bytes, picked.name);

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
      setState(() {
        message = "❌ Scan failed: ${e.toString()}";
      });
    } finally {
      setState(() => scanning = false);
    }
  }

  void _submitAll() async {
    setState(() {
      loading = true;
      message = "";
    });

    try {
      if (scannedRows.isNotEmpty) {
        // Submit all scanned rows
        int created = 0;
        for (final row in scannedRows) {
          await ApiService.createBillFromMeters(
            widget.token,
            row["room_number"],
            row["month"],
            (row["elec_prev"] as num).toDouble(),
            (row["elec_curr"] as num).toDouble(),
            (row["water_prev"] as num).toDouble(),
            (row["water_curr"] as num).toDouble(),
          );
          created++;
        }
        setState(() {
          message = "✅ Created $created bills successfully!";
          scannedRows = [];
        });
      } else {
        // Manual single submit
        final result = await ApiService.createBillFromMeters(
          widget.token,
          roomController.text.trim(),
          monthController.text.trim(),
          double.parse(elecPrevController.text.trim()),
          double.parse(elecCurrController.text.trim()),
          double.parse(waterPrevController.text.trim()),
          double.parse(waterCurrController.text.trim()),
        );
        setState(() {
          message =
              "✅ Bill created! Total: ${result["amount"]} (Elec: ${result["electricity"]}, Water: ${result["water"]}, Rent: ${result["rent"]})";
        });
      }
    } catch (e) {
      setState(() {
        message = "❌ ${e.toString().replaceAll('Exception: ', '')}";
      });
    } finally {
      setState(() => loading = false);
    }
  }

  Widget _field(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Enter Meter Readings",
                style:
                    TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: scanning ? null : _scanSheet,
              icon: const Icon(Icons.document_scanner),
              label: scanning
                  ? const Text("Scanning...")
                  : const Text("Scan Sheet (OCR)"),
            ),
            const SizedBox(height: 24),
            if (scannedRows.length > 1) ...[
              Text("${scannedRows.length} rooms scanned:",
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...scannedRows.map((row) => Card(
                    child: ListTile(
                      title: Text("Room ${row["room_number"]}"),
                      subtitle: Text(
                          "Elec: ${row["elec_prev"]}→${row["elec_curr"]}  Water: ${row["water_prev"]}→${row["water_curr"]}"),
                    ),
                  )),
              const SizedBox(height: 16),
            ] else ...[
              _field("Room Number", roomController),
              _field("Month (YYYY-MM)", monthController),
              const Divider(),
              const Text("⚡ Electricity",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _field("Previous Reading", elecPrevController),
              _field("Current Reading", elecCurrController),
              const Divider(),
              const Text("💧 Water",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _field("Previous Reading", waterPrevController),
              _field("Current Reading", waterCurrController),
            ],
            const SizedBox(height: 8),
            if (message.isNotEmpty)
              Text(message,
                  style: TextStyle(
                      color: message.startsWith("✅")
                          ? Colors.green
                          : Colors.red)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : _submitAll,
                child: loading
                    ? const CircularProgressIndicator()
                    : Text(scannedRows.isNotEmpty
                        ? "Confirm & Create All Bills"
                        : "Create Bill"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



