import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
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

  /* ---------------- ITEM IN BOX STATUS ---------------- */

  // Now driven by has_package from GET /api/box-state via polling.
  // Updated automatically every 5 seconds — no manual button needed.
  bool itemInBox = false;

  /* ---------------- FETCH ALERTS FROM SERVER ---------------- */

  // Fetches alerts from GET http://lockrrr.site/api/alerts
  // Replaces the notifications list with the latest 4 from the server
  // to avoid duplicates on repeated fetches.
  Future<void> fetchAlerts() async {
    try {
      final res = await http.get(
        Uri.parse("http://lockrrr.site/api/alerts"),
      );

      if (res.statusCode == 200) {
        final dynamic decoded = jsonDecode(res.body);

        if (decoded is! List) return;

        final List<dynamic> alerts = decoded;

        final List<UnlockNotification> fetched = [];

        for (final a in alerts) {
          if (a is! Map) continue;

          final String title =
              (a['message'] as String? ?? '').isNotEmpty
                  ? a['message'] as String
                  : 'Box Unlocked';

          DateTime timestamp;
          try {
            timestamp = DateTime.parse(a['timestamp'] as String? ?? '');
          } catch (_) {
            timestamp = DateTime.now();
          }

          fetched.add(UnlockNotification(title: title, timestamp: timestamp));

          // Only keep the 4 most recent
          if (fetched.length >= 4) break;
        }

        setState(() {
          // Replace list entirely to avoid duplicates
          notifications
            ..clear()
            ..addAll(fetched);
        });
      }
    } catch (_) {
      // Silently ignore network errors — dashboard shows whatever is cached
    }
  }

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

    // Refresh alerts from server after an unlock
    fetchAlerts();
  }

  // Called by LockScreen's poll whenever box-state is refreshed.
  // Updates both lock-adjacent UI and the has_package indicator.
  void onBoxStateUpdated({required bool hasPackage}) {
    setState(() {
      itemInBox = hasPackage;
    });
  }

  void goTo(int i) {
    setState(() => index = i);
    Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();
    // Load alerts when the app shell first opens
    fetchAlerts();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(
        notifications: notifications,
        itemInBox: itemInBox,
      ),
      const TrackingScreen(),
      LockScreen(
        onUnlocked: addUnlockNotification,
        onBoxStateUpdated: onBoxStateUpdated,
      ),
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

  // Now driven by has_package from the API — no manual callback needed.
  final bool itemInBox;

  const DashboardScreen({
    super.key,
    required this.notifications,
    required this.itemInBox,
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
        const SizedBox(height: 16),

        /* ---------------- ITEM IN BOX CARD ---------------- */

        // has_package from /api/box-state drives this card automatically.
        // The manual Add/Remove button has been removed — the ESP32/MQTT
        // updates the server, the app polls it every 5 seconds.
        Card(
          color: itemInBox ? Colors.green.shade50 : null,
          child: ListTile(
            leading: Icon(
              itemInBox ? Icons.inventory_2 : Icons.inventory_2_outlined,
              color: itemInBox ? Colors.green : Colors.grey,
            ),
            title: const Text(
              "Item in Box",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              itemInBox
                  ? "📦 A package has been detected."
                  : "No package detected.",
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
    // Guard against out-of-range month values from corrupted API data
    if (month < 1 || month > 12) return "Unknown";
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

    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      upsResult =
          "Carrier: UPS\n"
          "Tracking Number: $trackingNumber\n"
          "Status: Out for Delivery\n"
          "Location: Harrisonburg, VA\n"
          "Estimated Delivery: Today 2–6 PM\n"
          "Description: Package is out for delivery.";
      upsLoading = false;
    });
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

    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      fedexResult =
          "Carrier: FedEx\n"
          "Tracking Number: $trackingNumber\n"
          "Status: In Transit\n"
          "Location: Richmond, VA\n"
          "Estimated Delivery: Tomorrow\n"
          "Description: Package is moving through the network.";
      fedexLoading = false;
    });
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

    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      amazonResult =
          "Carrier: Amazon\n"
          "Package Number: $packageNumber\n"
          "Status: Arriving Today\n"
          "Location: Local Delivery Station\n"
          "Estimated Delivery: By 10 PM\n"
          "Description: Package is nearby and out for delivery.";
      amazonLoading = false;
    });
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

  // Called every poll cycle with the latest has_package value
  // so AppShell can update the Dashboard without extra API calls.
  final void Function({required bool hasPackage}) onBoxStateUpdated;

  const LockScreen({
    super.key,
    required this.onUnlocked,
    required this.onBoxStateUpdated,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool locked = true;
  bool isLoading = false;
  String? errorMessage;
  Timer? pollTimer;

  /* ---------------- POLL BOX STATE FROM SERVER ---------------- */

  // Polls GET http://lockrrr.site:3000/api/box-state every 5 seconds.
  // Reads both is_locked and has_package from the response.
  Future<void> fetchLockState() async {
    try {
      final response = await http.get(
        Uri.parse("https://lockrrr.site/api/box-state"),
      );

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is Map) {
          final bool serverLocked = data['is_locked'] as bool? ?? true;
          final bool hasPackage = data['has_package'] as bool? ?? false;

          if (mounted) {
            setState(() {
              locked = serverLocked;
            });
            // Pass has_package up to AppShell to update the Dashboard card
            widget.onBoxStateUpdated(hasPackage: hasPackage);
          }
        }
      }
    } catch (_) {
      // Silently ignore poll errors — UI keeps last known state
    }
  }

  /* ---------------- SEND UNLOCK TO SERVER ---------------- */

  // Posts to POST http://lockrrr.site:3000/api/unlock
  Future<void> toggleLock() async {
    if (!locked || isLoading) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse("https://lockrrr.site/api/unlock"),
         headers: {
          "x-api-key": "ayeyoulockingthatbadboyup67",
        },
      );

      if (response.statusCode == 200) {
        pollTimer?.cancel();
        setState(() {
          locked = false;
          isLoading = false;
        });
        widget.onUnlocked();
        // Restart polling so re-lock is detected from the server
        _startPolling();
      } else {
        setState(() {
          isLoading = false;
          errorMessage =
              "Unlock failed (server error ${response.statusCode}). Please try again.";
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage =
              "Could not reach the server. Check your connection and try again.";
        });
      }
    }
  }

  void _startPolling() {
    pollTimer?.cancel();
    pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      fetchLockState();
    });
  }

  @override
  void initState() {
    super.initState();
    // Fetch state immediately on screen open, then poll every 5 seconds
    fetchLockState();
    _startPolling();
  }

  @override
  void dispose() {
    pollTimer?.cancel();
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
                color: locked ? Colors.green : Colors.orange,
              ),
              const SizedBox(height: 12),
              Text(
                locked ? "Locked" : "Unlocked",
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (locked && !isLoading) ? toggleLock : null,
                  child: Text(
                    isLoading
                        ? "Unlocking..."
                        : locked
                            ? "Unlock"
                            : "Waiting...",
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}