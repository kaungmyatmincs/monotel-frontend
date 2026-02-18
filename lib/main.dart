import 'package:flutter/material.dart';
import 'services/api_service.dart';

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


