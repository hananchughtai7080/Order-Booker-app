import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../db/app_database.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'new_order_screen.dart';
import 'payments_screen.dart';
import 'products_screen.dart';
import 'shop_detail_screen.dart';
import 'shops_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_DashData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    context.read<AppState>().addListener(_reload);
  }

  @override
  void dispose() {
    context.read<AppState>().removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() => _future = _load());
  }

  Future<_DashData> _load() async {
    final db = AppDatabase.instance;
    final today = todayStr();
    final weekday = DateTime.now().weekday;
    final sale = await db.salesOn(today);
    final recovery = await db.recoveryOn(today);
    final ordersCount = await db.ordersCountOn(today);
    final outstanding = await db.totalOutstanding();
    final pendingRem = await db.pendingRemindersCount();
    final routeShops = await db.getShopsForDay(weekday);
    final recent = await db.getOrders(limit: 6);
    final shopCount = (await db.getShops()).length;
    final productCount = (await db.getProducts()).length;
    return _DashData(
        sale: sale,
        recovery: recovery,
        ordersCount: ordersCount,
        outstanding: outstanding,
        pendingRem: pendingRem,
        routeShops: routeShops,
        recent: recent,
        shopCount: shopCount,
        productCount: productCount);
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final todayLabel =
        DateFormat('EEEE, d MMM yyyy', st.isUrdu ? 'ur' : 'en').format(DateTime.now());
    return Scaffold(
      appBar: AppBar(title: Text(st.s('dashboard'))),
      body: FutureBuilder<_DashData>(
        future: _future,
        builder: (c, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final d = snap.data!;
          final today = todayStr();
          final unvisited =
              d.routeShops.where((s) => !st.isVisited(s.id!, today)).toList();
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Text(todayLabel,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.55,
                  children: [
                    StatCard(
                        title: st.s('todaysSale'),
                        value: 'Rs ${fmtMoney(d.sale)}',
                        icon: Icons.shopping_cart,
                        color: Colors.green),
                    StatCard(
                        title: st.s('todaysRecovery'),
                        value: 'Rs ${fmtMoney(d.recovery)}',
                        icon: Icons.payments,
                        color: Colors.blue),
                    StatCard(
                        title: st.s('totalOutstanding'),
                        value: 'Rs ${fmtMoney(d.outstanding)}',
                        icon: Icons.account_balance_wallet,
                        color: Colors.orange),
                    StatCard(
                        title: st.s('pendingReminders'),
                        value: '${d.pendingRem}',
                        icon: Icons.notifications,
                        color: Colors.red),
                  ],
                ),
                if (st.dailyTarget > 0) ...[
                  const SizedBox(height: 4),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                  '${st.s('dailyTarget')}: Rs ${fmtMoney(st.dailyTarget)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              Text(
                                  'Rs ${fmtMoney(d.sale)} ${st.s('targetAchieved')}',
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: (d.sale / st.dailyTarget).clamp(0, 1),
                            minHeight: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                SectionTitle(title: st.s('todaysRoute')),
                if (d.routeShops.isEmpty)
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(st.s('noShopsToday'))))
                else if (unvisited.isEmpty)
                  Card(
                      color: Colors.green[50],
                      child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            const Icon(Icons.check_circle,
                                color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(child: Text(st.s('allDone')))
                          ])))
                else
                  Card(
                    color: Colors.amber[50],
                    child: ListTile(
                      leading:
                          const Icon(Icons.store, color: Colors.amber),
                      title: Text(st.s('nextShop')),
                      subtitle: Text(
                          '${unvisited.first.name}${unvisited.first.ownerName.isNotEmpty ? ' (${unvisited.first.ownerName})' : ''}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      trailing: const Icon(Icons.arrow_forward_ios,
                          size: 16),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ShopDetailScreen(
                                  shopId: unvisited.first.id!))),
                    ),
                  ),
                if (d.routeShops.isNotEmpty)
                  Card(
                    child: Column(
                      children: d.routeShops.map((s) {
                        final v = st.isVisited(s.id!, today);
                        return CheckboxListTile(
                          value: v,
                          dense: true,
                          title: Text(s.name,
                              style: TextStyle(
                                  decoration: v
                                      ? TextDecoration.lineThrough
                                      : null)),
                          subtitle: s.routeName != null
                              ? Text(s.routeName!)
                              : null,
                          secondary: IconButton(
                            icon: const Icon(Icons.arrow_forward_ios,
                                size: 16),
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => ShopDetailScreen(
                                        shopId: s.id!))),
                          ),
                          onChanged: (_) =>
                              st.toggleVisited(s.id!, today),
                        );
                      }).toList(),
                    ),
                  ),
                SectionTitle(title: st.s('quickActions')),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _qa(context, Icons.add_shopping_cart, st.s('newOrder'),
                        () => _go(const NewOrderScreen())),
                    _qa(context, Icons.payments, st.s('addPayment'),
                        () => _go(const PaymentsScreen())),
                    _qa(context, Icons.store, st.s('addShop'),
                        () => _go(const ShopsScreen(openAdd: true))),
                    _qa(context, Icons.inventory, st.s('addProduct'),
                        () => _go(const ProductsScreen(openAdd: true))),
                  ],
                ),
                if (d.shopCount == 0)
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(st.s('getStartedTitle'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 6),
                          Text(st.s('getStartedBody')),
                        ],
                      ),
                    ),
                  ),
                SectionTitle(
                    title: st.s('recentOrders'),
                    trailing: TextButton(
                        onPressed: () => _go(const ShopsScreen()),
                        child: Text(st.s('viewAll')))),
                if (d.recent.isEmpty)
                  Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(st.s('noOrdersYet')))
                else
                  ...d.recent.map((o) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.receipt_long),
                          title: Text(o.shopName ?? ''),
                          subtitle: Text(
                              '${o.date} • ${o.status == 'delivered' ? st.s('statusDelivered') : st.s('statusBooked')}'),
                          trailing: Money(o.total, bold: true),
                        ),
                      )),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _qa(
      BuildContext c, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
              radius: 26,
              backgroundColor: Theme.of(c).colorScheme.primaryContainer,
              child: Icon(icon,
                  color: Theme.of(c).colorScheme.onPrimaryContainer)),
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  void _go(Widget w) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => w));
}

class _DashData {
  final double sale;
  final double recovery;
  final int ordersCount;
  final double outstanding;
  final int pendingRem;
  final List<Shop> routeShops;
  final List<OrderHead> recent;
  final int shopCount;
  final int productCount;
  _DashData(
      {required this.sale,
      required this.recovery,
      required this.ordersCount,
      required this.outstanding,
      required this.pendingRem,
      required this.routeShops,
      required this.recent,
      required this.shopCount,
      required this.productCount});
}
