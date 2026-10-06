import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'db/app_database.dart';
import 'screens/dashboard_screen.dart';
import 'screens/payments_screen.dart';
import 'screens/products_screen.dart';
import 'screens/reminders_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/routes_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/shops_screen.dart';
import 'services/services.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  await state.load();
  try {
    await initializeDateFormatting('ur');
  } catch (_) {}
  await NotificationService.init();
  runApp(ChangeNotifierProvider.value(
    value: state,
    child: const OrderBookerApp(),
  ));
  // fire due-reminder notification shortly after launch
  Future.delayed(const Duration(seconds: 2), () async {
    final due = (await AppDatabase.instance.getReminders(pendingOnly: true))
        .where((r) => r.dueDate.compareTo(todayStr()) <= 0)
        .toList();
    await NotificationService.notifyDueReminders(
        due, (k) => state.s(k));
  });
}

class OrderBookerApp extends StatelessWidget {
  const OrderBookerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    return MaterialApp(
      title: st.s('appTitle'),
      debugShowCheckedModeBanner: false,
      locale: Locale(st.lang),
      supportedLocales: const [Locale('en'), Locale('ur')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _idx = 0;

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final pages = [
      const DashboardScreen(),
      const ShopsScreen(),
      const ProductsScreen(),
      const PaymentsScreen(),
      const MoreScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _idx, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.dashboard),
              label: st.s('dashboard')),
          NavigationDestination(
              icon: const Icon(Icons.store), label: st.s('shops')),
          NavigationDestination(
              icon: const Icon(Icons.inventory),
              label: st.s('products')),
          NavigationDestination(
              icon: const Icon(Icons.payments),
              label: st.s('payments')),
          NavigationDestination(
              icon: const Icon(Icons.more_horiz), label: st.s('more')),
        ],
      ),
    );
  }
}

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final items = [
      (Icons.notifications, st.s('reminders'), const RemindersScreen()),
      (Icons.route, st.s('routes'), const RoutesScreen()),
      (Icons.folder, st.s('reports'), const ReportsScreen()),
      (Icons.settings, st.s('settings'), const SettingsScreen()),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(st.s('more'))),
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (c, i) {
          final (icon, label, page) = items[i];
          return Card(
            margin:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              leading: Icon(icon),
              title: Text(label,
                  style: const TextStyle(fontSize: 16)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => page)),
            ),
          );
        },
      ),
    );
  }
}
