import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../db/app_database.dart';
import '../models/models.dart';

String fmtMoney(double v) {
  final n = v.round();
  return NumberFormat('#,##0', 'en_US').format(n);
}

/// Pakistan phone -> international format for wa.me
String normalizePhone(String raw) {
  var d = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.startsWith('0')) d = '92${d.substring(1)}';
  return d;
}

class ShareService {
  static Future<void> whatsapp(String phone, String message) async {
    final to = normalizePhone(phone);
    final uri = Uri.parse('https://wa.me/$to?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> sms(String phone, String message) async {
    final uri = Uri.parse('sms:$phone?body=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  static Future<void> call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  static Future<void> shareFiles(List<String> paths, String text) async {
    await Share.shareXFiles(paths.map((e) => XFile(e)).toList(), text: text);
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> notifyDueReminders(
      List<Reminder> due, String Function(String) tr) async {
    if (due.isEmpty) return;
    final over = due.where((r) => r.dueDate.compareTo(todayStr()) < 0).length;
    final body = over > 0
        ? '$over ${tr('overdue')}, ${due.length - over} ${tr('dueToday')}'
        : '${due.length} ${tr('dueToday')}';
    await _plugin.show(
      1001,
      tr('notificationTitle'),
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders',
          'Reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}

String _safe(String s) => s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();

/// Exports CSV files organized as:
/// OrderBooker/<RouteName>/<yyyy-MM-dd>/<ShopName>_orders.csv (+ _ledger.csv)
/// plus <yyyy-MM-dd>_summary.csv in each date folder.
class ExportService {
  static Future<List<String>> exportFolders(String from, String to) async {
    final db = AppDatabase.instance;
    final docs = await getApplicationDocumentsDirectory();
    final base = Directory(p.join(docs.path, 'OrderBooker'));
    final created = <String>[];

    final orders = await db.getOrders(from: from, to: to, limit: 100000);
    if (orders.isEmpty) return created;

    // group by route/date/shop
    final shops = {for (final s in await db.getShops()) s.id: s};
    final Map<String, List<OrderHead>> byDateShop = {};
    for (final o in orders) {
      byDateShop.putIfAbsent('${o.date}|${o.shopId}', () => []).add(o);
    }

    final csvConv = const ListToCsvConverter();
    for (final entry in byDateShop.entries) {
      final parts = entry.key.split('|');
      final date = parts[0];
      final shopId = int.parse(parts[1]);
      final shop = shops[shopId];
      final shopName = _safe(shop?.name ?? 'Shop$shopId');
      final routeName = _safe(shop?.routeName ?? 'NoRoute');
      final dir = Directory(p.join(base.path, routeName, date, shopName));
      await dir.create(recursive: true);

      // orders csv with items
      final rows = <List<dynamic>>[
        ['OrderID', 'Date', 'Shop', 'Product', 'Qty', 'Rate', 'Amount', 'Status']
      ];
      double shopTotal = 0;
      for (final o in entry.value) {
        final items = await db.getOrderItems(o.id!);
        for (final it in items) {
          rows.add([
            o.id,
            o.date,
            shop?.name ?? '',
            it.productName,
            it.qty,
            it.rate,
            it.amount,
            o.status
          ]);
        }
        shopTotal += o.total;
      }
      rows.add(['', '', '', '', '', '', 'TOTAL', shopTotal]);
      final f1 = File(p.join(dir.path, '${shopName}_orders.csv'));
      await f1.writeAsString(csvConv.convert(rows));
      created.add(f1.path);

      // ledger csv
      final bal = await db.shopBalance(shopId);
      final ledger = await db.shopLedger(shopId);
      final lrows = <List<dynamic>>[
        ['Date', 'Type', 'Detail', 'Debit(+)/Credit(-)', 'BalanceSoFar']
      ];
      double run = 0;
      for (final e in ledger) {
        run += e.amount;
        lrows.add([e.date, e.kind, e.label, e.amount, run]);
      }
      lrows.add(['', '', 'OUTSTANDING', '', bal]);
      final f2 = File(p.join(dir.path, '${shopName}_ledger.csv'));
      await f2.writeAsString(csvConv.convert(lrows));
      created.add(f2.path);
    }

    // per-date summary
    final Map<String, List<OrderHead>> byDate = {};
    for (final o in orders) {
      byDate.putIfAbsent(o.date, () => []).add(o);
    }
    for (final e in byDate.entries) {
      final sale = e.value.fold<double>(0, (a, b) => a + b.total);
      // find the date dir (first route dir containing this date)
      final dateDirs = base
          .listSync(recursive: true)
          .whereType<Directory>()
          .where((d) => p.basename(d.path) == e.key);
      for (final dd in dateDirs) {
        final f = File(p.join(dd.path, '${e.key}_summary.csv'));
        final pays = await db.recoveryOn(e.key);
        await f.writeAsString(csvConv.convert([
          ['Date', 'Orders', 'Sale(Rs)', 'Recovery(Rs)'],
          [e.key, e.value.length, sale, pays],
        ]));
        created.add(f.path);
      }
    }
    return created;
  }

  static Future<String> backupDatabase() async {
    final docs = await getApplicationDocumentsDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final dest = File(p.join(docs.path, 'OrderBooker_backup_$stamp.db'));
    await File(await AppDatabase.instance.dbPath).copy(dest.path);
    return dest.path;
  }

  static Future<void> restoreDatabase(String backupPath) async {
    final dbFile = File(await AppDatabase.instance.dbPath);
    await File(backupPath).copy(dbFile.path);
  }
}
