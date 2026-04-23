import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() => runApp(const DeliveryBoxApp());

class DeliveryBoxApp extends StatelessWidget {
  const DeliveryBoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Delivery Box',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const AuthGate(),
    );
  }
}

class TrackingApi {
  static const String trackingNumber = '1Z999AA10123456784';

  // Change this depending on what you're running on:
  // Android emulator -> http://10.0.2.2:8080
  // iOS simulator -> http://localhost:8080
  // Real phone -> http://YOUR_COMPUTER_IP:8080
  static const String baseUrl = 'http://10.0.2.2:8080';

  static Future<Map<String, dynamic>> fetchTracking() async {
    final uri = Uri.parse('$baseUrl/api/track/$trackingNumber');
    final response = await http.get(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load tracking: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (decoded['ok'] != true) {
      throw Exception(decoded['error']?.toString() ?? 'Unknown tracking error');
    }

    return (decoded['data'] as Map<String, dynamic>? ?? {});
  }
}

/* ---------------- AUTH GATE ---------------- */

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool loggedIn = false;

  @override
  Widget build(BuildContext context) {
    return loggedIn
        ? AppShell(
            onLogout: () {
              setState(() => loggedIn = false);
            },
          )
        : LoginScreen(
            onLoginSuccess: () {
              setState(() => loggedIn = true);
            },
          );
  }
}

/* ---------------- LOGIN SCREEN ---------------- */

<<<<<<< Updated upstream
/* ---------------- LOGIN SCREEN ---------------- */

=======
>>>>>>> Stashed changes
class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final userController = TextEditingController();
  final passController = TextEditingController();
  String? error;

  void signIn() {
    const username = "prototype";
    const password = "box1demo";

    if (userController.text == username &&
        passController.text == password) {
      widget.onLoginSuccess();
    } else {
      setState(() {
        error = "Invalid login";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
<<<<<<< Updated upstream
          // 🔹 BACKGROUND IMAGE
=======
>>>>>>> Stashed changes
          SizedBox.expand(
            child: Image.asset(
              'assets/trackingmap.png',
              fit: BoxFit.cover,
            ),
          ),
<<<<<<< Updated upstream

          // 🔹 OPTIONAL DARK OVERLAY (makes UI easier to see)
          Container(
            color: Colors.black.withOpacity(0.3),
          ),

          // 🔹 CENTER WHITE LOGIN BOX
=======
          Container(
            color: Colors.black.withOpacity(0.3),
          ),
>>>>>>> Stashed changes
          Center(
            child: SizedBox(
              width: 320,
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/logo.png',
                        height: 80,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Sign in to Box 1",
                        style: TextStyle(
<<<<<<< Updated upstream
                            fontSize: 22, fontWeight: FontWeight.bold),
=======
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
>>>>>>> Stashed changes
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: userController,
                        decoration:
                            const InputDecoration(labelText: "Username"),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passController,
                        obscureText: true,
                        decoration:
                            const InputDecoration(labelText: "Password"),
                      ),
                      const SizedBox(height: 16),
                      if (error != null)
<<<<<<< Updated upstream
                        Text(error!,
                            style: const TextStyle(color: Colors.red)),
=======
                        Text(
                          error!,
                          style: const TextStyle(color: Colors.red),
                        ),
>>>>>>> Stashed changes
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: signIn,
                          child: const Text("Sign In"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

<<<<<<< Updated upstream
=======
/* ---------------- DATA MODEL ---------------- */

class UnlockNotification {
  final String title;
  final DateTime timestamp;

  UnlockNotification({
    required this.title,
    required this.timestamp,
  });
}

>>>>>>> Stashed changes
/* ---------------- APP SHELL ---------------- */

class AppShell extends StatefulWidget {
  final VoidCallback onLogout;

  const AppShell({super.key, required this.onLogout});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  final List<UnlockNotification> notifications = [];

  void addUnlockNotification() {
    setState(() {
      notifications.insert(
        0,
        UnlockNotification(
          title: "Box Unlocked",
          timestamp: DateTime.now(),
        ),
      );

      if (notifications.length > 4) {
        notifications.removeLast();
      }
    });
  }

  void goTo(int i) {
    setState(() => index = i);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(notifications: notifications),
      LockScreen(onUnlocked: addUnlockNotification),
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 120,
        centerTitle: true,
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo.png',
              height: 70,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 4),
            const Text(
              "Front Porch • Box #1",
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: widget.onLogout,
          )
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              child: Text(
                "Delivery Box",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.inbox),
              title: const Text("Dashboard"),
              onTap: () => goTo(0),
            ),
            ListTile(
              leading: const Icon(Icons.lock),
              title: const Text("Lock"),
              onTap: () => goTo(1),
            ),
          ],
        ),
      ),
      body: screens[index],
    );
  }
}

/* ---------------- DASHBOARD ---------------- */

class DashboardScreen extends StatelessWidget {
  final List<UnlockNotification> notifications;

  const DashboardScreen({
    super.key,
    required this.notifications,
  });

  bool _isDelivered(String? status) {
    if (status == null) return false;
    final s = status.toLowerCase();
    return s.contains('delivered');
  }

  bool _isDelivered(String? status) {
    if (status == null) return false;
    final s = status.toLowerCase();
    return s.contains('delivered');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          "Items in Box",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading:
                const Icon(Icons.inventory_2, size: 36, color: Colors.amber),
<<<<<<< Updated upstream
            title: const Text("Item in Box",
                style: TextStyle(fontWeight: FontWeight.w600)),
=======
            title: const Text(
              "Item in Box",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
>>>>>>> Stashed changes
            subtitle: const Text("Now"),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
        const SizedBox(height: 24),
<<<<<<< Updated upstream

        const Text("Package Tracking",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
=======
        const Text(
          "Package Tracking",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
>>>>>>> Stashed changes
        const SizedBox(height: 12),
        FutureBuilder<Map<String, dynamic>>(
          future: TrackingApi.fetchTracking(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: ListTile(
                  leading: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  title: Text("Loading tracking info..."),
                ),
              );
            }

<<<<<<< Updated upstream
        FutureBuilder<Map<String, dynamic>>(
          future: TrackingApi.fetchTracking(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: ListTile(
                  leading: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  title: Text("Loading tracking info..."),
                ),
              );
            }

=======
>>>>>>> Stashed changes
            if (snapshot.hasError) {
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.error, color: Colors.red),
                  title: const Text(
                    "Could not load tracking",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(snapshot.error.toString()),
                ),
              );
            }

            final tracking = snapshot.data ?? {};
            final status = tracking['status']?.toString() ?? 'Unknown';
            final location = tracking['latestLocation']?.toString();
            final deliveryDate = tracking['deliveryDate']?.toString();
            final description = tracking['latestDescription']?.toString();
            final delivered = _isDelivered(status);

            return Column(
              children: [
                Card(
                  child: ListTile(
                    leading: Icon(
                      delivered ? Icons.check_circle : Icons.local_shipping,
                      color: delivered ? Colors.green : Colors.blue,
                      size: 32,
                    ),
                    title: Text(
                      status,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      location ?? description ?? 'No location available',
                    ),
                    trailing: Icon(
                      delivered ? Icons.done_all : Icons.schedule,
                      color: delivered ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
                if (deliveryDate != null && deliveryDate.isNotEmpty)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: const Text(
                        "Delivery Date",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(deliveryDate),
                    ),
                  ),
              ],
            );
          },
        ),
<<<<<<< Updated upstream

        const SizedBox(height: 24),
        const Text("Recent Motion Detected",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        motionTile("Motion Detected", "Today • 2:41 PM", true),
        motionTile("Package Delivered", "Today • 1:12 PM", false),
        motionTile("Motion Detected", "Today • 10:05 AM", true),
        motionTile("Motion Detected", "Yesterday • 5:32 PM", true),
=======
        const SizedBox(height: 24),
        const Text(
          "Notifications",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (notifications.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.notifications_none),
              title: Text("No notifications yet"),
              subtitle: Text("Unlock the box to see notifications here."),
            ),
          )
        else
          ...notifications.map(
            (note) => Card(
              child: ListTile(
                leading: const Icon(
                  Icons.notifications_active,
                  color: Colors.blue,
                ),
                title: Text(
                  note.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(formatDateTime(note.timestamp)),
                trailing: const Icon(Icons.lock_open, color: Colors.green),
              ),
            ),
          ),
>>>>>>> Stashed changes
      ],
    );
  }

  static String formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour > 12
        ? dateTime.hour - 12
        : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';

    final month = _monthName(dateTime.month);
    return "$month ${dateTime.day}, ${dateTime.year} • $hour:$minute $period";
  }

  static String _monthName(int month) {
    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];
    return months[month - 1];
  }
}

/* ---------------- LOCK ---------------- */

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const LockScreen({
    super.key,
    required this.onUnlocked,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool locked = true;

  void toggleLock() {
    setState(() {
      if (locked) {
        locked = false;
        widget.onUnlocked();
      } else {
        locked = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                locked ? Icons.lock : Icons.lock_open,
                size: 70,
                color: Colors.green,
              ),
              const SizedBox(height: 12),
              Text(
                locked ? "Locked" : "Unlocked",
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: toggleLock,
                  child: Text(locked ? "Unlock" : "Lock"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}