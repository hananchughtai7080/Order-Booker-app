import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/app_database.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'new_order_screen.dart';
import 'payments_screen.dart';

class ShopDetailScreen extends StatefulWidget {
  final int shopId;
  const ShopDetailScreen({super.key, required this.shopId});
  @override
  State<ShopDetailScreen> createState() => _ShopDetailScreenState();
}

class _ShopDetailScreenState extends State<ShopDetailScreen> {
  late Future<_Detail> _future;

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
    if (mounted) setState(() => _future = _load());
  }

  Future<_Detail> _load() async {
    final db = AppDatabase.instance;
    final shop = (await db.getShop(widget.shopId))!;
    final balance = await db.shopBalance(widget.shopId);
    final orders = await db.getOrders(shopId: widget.shopId);
    final ledger = await db.shopLedger(widget.shopId);
    final reminders =
        (await db.getReminders()).where((r) => r.shopId == widget.shopId).toList();
    final billed = orders.fold<double>(0, (a, o) => a + o.total);
    return _Detail(
        shop: shop,
        balance: balance,
        orders: orders,
        ledger: ledger,
        reminders: reminders,
        billed: billed);
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(st.s('shops'))),
      body: FutureBuilder<_Detail>(
        future: _future,
        builder: (c, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final d = snap.data!;
          final s = d.shop;
          return DefaultTabController(
            length: 3,
            child: NestedScrollView(
              headerSliverBuilder: (c, _) => [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                                radius: 26, child: Icon(Icons.store, size: 28)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(s.name,
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold)),
                                  if (s.ownerName.isNotEmpty)
                                    Text(s.ownerName),
                                  if (s.phone.isNotEmpty) Text(s.phone),
                                  if (s.routeName != null)
                                    Text('${st.s('route')}: ${s.routeName}',
                                        style: const TextStyle(
                                            color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Card(
                          color: d.balance > 0
                              ? Colors.orange[50]
                              : Colors.green[50],
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceAround,
                              children: [
                                _bal(st.s('totalBilled'), d.billed),
                                _bal(st.s('totalPaid'),
                                    d.billed - d.balance),
                                _bal(
                                    st.s('outstanding'),
                                    d.balance,
                                    color: d.balance > 0
                                        ? Colors.red
                                        : Colors.green),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => NewOrderScreen(
                                          presetShopId: s.id))),
                              icon: const Icon(Icons.add_shopping_cart,
                                  size: 18),
                              label: Text(st.s('newOrder')),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => PaymentsScreen(
                                          presetShopId: s.id))),
                              icon: const Icon(Icons.payments, size: 18),
                              label: Text(st.s('addPayment')),
                            ),
                            if (s.phone.isNotEmpty) ...[
                              OutlinedButton.icon(
                                onPressed: () => _sendReminder(s, d.balance,
                                    ShareService.whatsapp),
                                icon: const Icon(Icons.chat, size: 18),
                                label: Text(st.s('sendWhatsApp')),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _sendReminder(s, d.balance,
                                    ShareService.sms),
                                icon:
                                    const Icon(Icons.sms, size: 18),
                                label: Text(st.s('sendSms')),
                              ),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    ShareService.call(s.phone),
                                icon: const Icon(Icons.call, size: 18),
                                label: Text(st.s('callNow')),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabBarDelegate(
                    TabBar(tabs: [
                      Tab(text: st.s('tabOrders')),
                      Tab(text: st.s('tabLedger')),
                      Tab(text: st.s('tabReminders')),
                    ]),
                  ),
                ),
              ],
              body: TabBarView(
                children: [
                  _ordersTab(d, st),
                  _ledgerTab(d, st),
                  _remindersTab(d, st),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _bal(String label, double v, {Color? color}) => Column(
        children: [
          Money(v, bold: true, size: 16, color: color),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      );

  Widget _ordersTab(_Detail d, AppState st) {
    if (d.orders.isEmpty) {
      return EmptyView(text: st.s('noOrdersYet'));
    }
    return ListView.builder(
      itemCount: d.orders.length,
      itemBuilder: (c, i) {
        final o = d.orders[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ExpansionTile(
            leading: const Icon(Icons.receipt_long),
            title: Text('${st.s('order')} #${o.id} • ${o.date}'),
            subtitle: Text(o.status == 'delivered'
                ? st.s('statusDelivered')
                : st.s('statusBooked')),
            trailing: Money(o.total, bold: true),
            children: [
              _OrderItemsList(orderId: o.id!),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (o.status != 'delivered')
                      TextButton(
                        onPressed: () async {
                          await AppDatabase.instance
                              .updateOrderStatus(o.id!, 'delivered');
                          st.refresh();
                        },
                        child: Text(st.s('markDelivered')),
                      ),
                    TextButton(
                      onPressed: () async {
                        if (await confirmDelete(context)) {
                          await AppDatabase.instance.deleteOrder(o.id!);
                          st.refresh();
                        }
                      },
                      child: Text(st.s('delete'),
                          style: const TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _ledgerTab(_Detail d, AppState st) {
    if (d.ledger.isEmpty) return EmptyView(text: st.s('ledgerEmpty'));
    double run = 0;
    // oldest first so the running balance reads chronologically
    final rows = d.ledger;
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (c, i) {
        final e = rows[i];
        run += e.amount;
        final isOrder = e.kind == 'order';
        return ListTile(
          dense: true,
          leading: Icon(isOrder ? Icons.shopping_cart : Icons.payments,
              color: isOrder ? Colors.orange : Colors.green),
          title: Text('${e.date} • ${e.label}'),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Money(e.amount,
                  bold: true,
                  color: isOrder ? Colors.orange[800] : Colors.green[700]),
              Text('${st.s('balance')}: Rs ${fmtMoney(run)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        );
      },
    );
  }

  Widget _remindersTab(_Detail d, AppState st) {
    if (d.reminders.isEmpty) return EmptyView(text: st.s('noReminders'));
    final today = todayStr();
    return ListView.builder(
      itemCount: d.reminders.length,
      itemBuilder: (c, i) {
        final r = d.reminders[i];
        final done = r.isDone == 1;
        final overdue = !done && r.dueDate.compareTo(today) < 0;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            leading: Icon(
                done
                    ? Icons.check_circle
                    : overdue
                        ? Icons.warning
                        : Icons.notifications,
                color: done
                    ? Colors.green
                    : overdue
                        ? Colors.red
                        : Colors.amber[800]),
            title: Text(
                r.title.isEmpty ? st.s('reminderFor') : r.title,
                style: TextStyle(
                    decoration: done ? TextDecoration.lineThrough : null)),
            subtitle: Text(
                '${st.s('dueDate')}: ${r.dueDate}${r.amount > 0 ? ' • Rs ${fmtMoney(r.amount)}' : ''}'),
            trailing: done
                ? null
                : TextButton(
                    onPressed: () async {
                      r.isDone = 1;
                      await AppDatabase.instance.updateReminder(r);
                      st.refresh();
                    },
                    child: Text(st.s('markDone')),
                  ),
          ),
        );
      },
    );
  }

  void _sendReminder(Shop s, double balance,
      Future<void> Function(String, String) sender) {
    final st = context.read<AppState>();
    final msg = st
        .s('reminderMsgDue')
        .replaceAll('{shop}', s.name)
        .replaceAll('{amount}', fmtMoney(balance))
        .replaceAll('{date}', todayStr());
    sender(s.phone, msg);
  }
}

class _OrderItemsList extends StatelessWidget {
  final int orderId;
  const _OrderItemsList({required this.orderId});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<OrderItem>>(
      future: AppDatabase.instance.getOrderItems(orderId),
      builder: (c, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        return Column(
          children: snap.data!
              .map((it) => ListTile(
                    dense: true,
                    title: Text(it.productName),
                    subtitle: Text(
                        '${it.qty} x Rs ${fmtMoney(it.rate)}'),
                    trailing: Money(it.amount),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);
  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(color: Theme.of(context).scaffoldBackgroundColor, child: tabBar);
  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      false;
}

class _Detail {
  final Shop shop;
  final double balance;
  final List<OrderHead> orders;
  final List<LedgerEntry> ledger;
  final List<Reminder> reminders;
  final double billed;
  _Detail(
      {required this.shop,
      required this.balance,
      required this.orders,
      required this.ledger,
      required this.reminders,
      required this.billed});
}
