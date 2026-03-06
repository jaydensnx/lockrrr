import 'package:flutter/material.dart';

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
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  final screens = const [
    DashboardScreen(),
    LockScreen(),
  ];

  void goTo(int i) {
    setState(() => index = i);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Delivery Box", style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 2),
            Text("Front Porch • Box #1", style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          )
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              child: Text("Delivery Box",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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

/* ---------------- Dashboard ---------------- */

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text("Items in Box",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        Card(
          child: ListTile(
            leading: const Icon(Icons.inventory_2, size: 36, color: Colors.amber),
            title: const Text("Item in Box",
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text("Now"),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),

        const SizedBox(height: 24),

        const Text("Recent Motion Detected",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        motionTile("Motion Detected", "Today • 2:41 PM", true),
        motionTile("Package Delivered", "Today • 1:12 PM", false),
        motionTile("Motion Detected", "Today • 10:05 AM", true),
        motionTile("Motion Detected", "Yesterday • 5:32 PM", true),
      ],
    );
  }

  static Widget motionTile(String title, String time, bool isMotion) {
    return Card(
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(time),
        trailing: isMotion
            ? const Icon(Icons.circle, color: Colors.red, size: 10)
            : const Icon(Icons.check_circle, color: Colors.green),
      ),
    );
  }
}

/* ---------------- Lock Screen ---------------- */

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool locked = true;

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
                    fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => locked = !locked);
                  },
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