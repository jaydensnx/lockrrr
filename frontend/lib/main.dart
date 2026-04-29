import 'dart:async';
import 'package:flutter/material.dart';

import 'ups_service.dart';
import 'fedex_service.dart';
import 'amazon_service.dart';

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

    if (userController.text == username && passController.text == password) {
      widget.onLoginSuccess();
    } else {
      setState(() {
        error = "Invalid login";
      });
    }
  }

  @override
  void dispose() {
    userController.dispose();
    passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SizedBox.expand(
            child: Image.asset(
              'assets/trackingmap.png',
              fit: BoxFit.cover,
            ),
          ),
          Container(
            color: Colors.black.withOpacity(0.3),
          ),
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
                        "Sign in",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: userController,
                        decoration: const InputDecoration(
                          labelText: "Username",
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: "Password",
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (error != null)
                        Text(
                          error!,
                          style: const TextStyle(color: Colors.red),
                        ),
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

/* ---------------- DATA MODEL ---------------- */

class UnlockNotification {
  final String title;
  final DateTime timestamp;

  UnlockNotification({
    required this.title,
    required this.timestamp,
  });
}

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
      const TrackingScreen(),
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
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              child: Text(
                "Delivery Box",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.inbox),
              title: const Text("Dashboard"),
              onTap: () => goTo(0),
            ),
            ListTile(
              leading: const Icon(Icons.local_shipping),
              title: const Text("Tracking"),
              onTap: () => goTo(1),
            ),
            ListTile(
              leading: const Icon(Icons.lock),
              title: const Text("Lock"),
              onTap: () => goTo(2),
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

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          "Dashboard",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.local_shipping, color: Colors.blue),
            title: Text(
              "Package Tracking",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              "Open the Tracking page from the menu to track UPS, FedEx, or Amazon packages.",
            ),
          ),
        ),
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

/* ---------------- TRACKING PAGE ---------------- */

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final upsController = TextEditingController();
  final fedexController = TextEditingController();
  final amazonController = TextEditingController();

  String? upsResult;
  String? fedexResult;
  String? amazonResult;

  bool upsLoading = false;
  bool fedexLoading = false;
  bool amazonLoading = false;

  final upsService = UpsService(
    clientId: 'YOUR_UPS_CLIENT_ID',
    clientSecret: 'YOUR_UPS_CLIENT_SECRET',
    accountNumber: 'YOUR_UPS_ACCOUNT_NUMBER',
    baseUrl: 'https://wwwcie.ups.com',
  );

  final fedexService = FedExService(
    clientId: 'YOUR_FEDEX_CLIENT_ID',
    clientSecret: 'YOUR_FEDEX_CLIENT_SECRET',
    baseUrl: 'https://apis-sandbox.fedex.com',
  );

  final amazonService = AmazonService(
    accessToken: 'YOUR_AMAZON_ACCESS_TOKEN',
    baseUrl: 'YOUR_AMAZON_BASE_URL',
  );

  Future<void> trackUps() async {
    final trackingNumber = upsController.text.trim();

    if (trackingNumber.isEmpty) {
      setState(() {
        upsResult = "Please enter a UPS tracking number.";
      });
      return;
    }

    setState(() {
      upsLoading = true;
      upsResult = null;
    });

    try {
      final res = await http.post(
        Uri.parse('http://localhost:8080/api/tracking'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'carrier': 'ups',
          'trackingNumber': trackingNumber,
        }),
      );

      if (res.statusCode != 200) {
        throw Exception("Failed: ${res.statusCode} - ${res.body}");
      }

      final decoded = jsonDecode(res.body);

      setState(() {
        upsResult = decoded.toString();
      });
    } catch (e) {
      setState(() {
        upsResult = "UPS error: $e";
      });
    } finally {
      setState(() {
        upsLoading = false;
      });
    }
  }

  Future<void> trackFedEx() async {
    final trackingNumber = fedexController.text.trim();

    if (trackingNumber.isEmpty) {
      setState(() {
        fedexResult = "Please enter a FedEx tracking number.";
      });
      return;
    }

    setState(() {
      fedexLoading = true;
      fedexResult = null;
    });

    try {
      final res = await http.post(
        Uri.parse('http://localhost:8080/api/tracking'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'carrier': 'fedex',
          'trackingNumber': trackingNumber,
        }),
      );

      if (res.statusCode != 200) {
        throw Exception("Failed: ${res.statusCode} - ${res.body}");
      }

      final decoded = jsonDecode(res.body);

      setState(() {
        fedexResult = decoded.toString();
      });
    } catch (e) {
      setState(() {
        fedexResult = "FedEx error: $e";
      });
    } finally {
      setState(() {
        fedexLoading = false;
      });
    }
  }

  Future<void> trackAmazon() async {
    final packageNumber = amazonController.text.trim();

    if (packageNumber.isEmpty) {
      setState(() {
        amazonResult = "Please enter an Amazon package number.";
      });
      return;
    }

    setState(() {
      amazonLoading = true;
      amazonResult = null;
    });

    try {
      final res = await http.post(
        Uri.parse('http://localhost:8080/api/tracking'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'carrier': 'amazon',
          'trackingNumber': packageNumber,
        }),
      );

      if (res.statusCode != 200) {
        throw Exception("Failed: ${res.statusCode} - ${res.body}");
      }

      final decoded = jsonDecode(res.body);

      setState(() {
        amazonResult = decoded.toString();
      });
    } catch (e) {
      setState(() {
        amazonResult = "Amazon error: $e";
      });
    } finally {
      setState(() {
        amazonLoading = false;
      });
    }
  }

  Widget trackingCard({
    required String title,
    required IconData icon,
    required TextEditingController controller,
    required bool loading,
    required String? result,
    required VoidCallback onTrack,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: "$title Tracking Number",
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: loading ? null : onTrack,
                icon: const Icon(Icons.search),
                label: Text(loading ? "Tracking..." : "Track $title"),
              ),
            ),
            if (result != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  result,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    upsController.dispose();
    fedexController.dispose();
    amazonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          "Track Your Packages",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          "Enter a tracking number under the correct carrier.",
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        trackingCard(
          title: "UPS",
          icon: Icons.local_shipping,
          controller: upsController,
          loading: upsLoading,
          result: upsResult,
          onTrack: trackUps,
        ),
        trackingCard(
          title: "FedEx",
          icon: Icons.inventory_2,
          controller: fedexController,
          loading: fedexLoading,
          result: fedexResult,
          onTrack: trackFedEx,
        ),
        trackingCard(
          title: "Amazon",
          icon: Icons.shopping_cart,
          controller: amazonController,
          loading: amazonLoading,
          result: amazonResult,
          onTrack: trackAmazon,
        ),
      ],
    );
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
  Timer? relockTimer;

  void toggleLock() {
    if (locked) {
      setState(() {
        locked = false;
      });

      widget.onUnlocked();

      relockTimer?.cancel();

      relockTimer = Timer(const Duration(seconds: 10), () {
        if (mounted) {
          setState(() {
            locked = true;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    relockTimer?.cancel();
    super.dispose();
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
                  onPressed: locked ? toggleLock : null,
                  child: Text(locked ? "Unlock" : "Waiting..."),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}