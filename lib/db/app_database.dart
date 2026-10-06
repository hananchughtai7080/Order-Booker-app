import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';

String todayStr() => DateFormat('yyyy-MM-dd').format(DateTime.now());
String nowStr() => DateTime.now().toIso8601String();

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<String> get dbPath async {
    final dir = await getDatabasesPath();
    return p.join(dir, 'order_booker.db');
  }

  Future<Database> _open() async {
    final path = await dbPath;
    return openDatabase(path, version: 1, onCreate: (d, v) async {
      await d.execute('''
        CREATE TABLE routes(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          day_of_week INTEGER NOT NULL DEFAULT 0
        )''');
      await d.execute('''
        CREATE TABLE shops(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          owner_name TEXT NOT NULL DEFAULT '',
          phone TEXT NOT NULL DEFAULT '',
          address TEXT NOT NULL DEFAULT '',
          route_id INTEGER,
          FOREIGN KEY(route_id) REFERENCES routes(id)
        )''');
      await d.execute('''
        CREATE TABLE products(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          brand TEXT NOT NULL DEFAULT '',
          unit TEXT NOT NULL DEFAULT '',
          rate REAL NOT NULL DEFAULT 0,
          stock_qty REAL NOT NULL DEFAULT 0
        )''');
      await d.execute('''
        CREATE TABLE orders(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          shop_id INTEGER NOT NULL,
          date TEXT NOT NULL,
          created_at TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'booked',
          total REAL NOT NULL DEFAULT 0,
          notes TEXT NOT NULL DEFAULT '',
          FOREIGN KEY(shop_id) REFERENCES shops(id)
        )''');
      await d.execute('''
        CREATE TABLE order_items(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          order_id INTEGER NOT NULL,
          product_id INTEGER NOT NULL,
          product_name TEXT NOT NULL DEFAULT '',
          qty REAL NOT NULL DEFAULT 0,
          rate REAL NOT NULL DEFAULT 0,
          amount REAL NOT NULL DEFAULT 0,
          FOREIGN KEY(order_id) REFERENCES orders(id)
        )''');
      await d.execute('''
        CREATE TABLE payments(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          shop_id INTEGER NOT NULL,
          date TEXT NOT NULL,
          amount REAL NOT NULL DEFAULT 0,
          mode TEXT NOT NULL DEFAULT 'cash',
          notes TEXT NOT NULL DEFAULT '',
          FOREIGN KEY(shop_id) REFERENCES shops(id)
        )''');
      await d.execute('''
        CREATE TABLE reminders(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          shop_id INTEGER NOT NULL,
          title TEXT NOT NULL DEFAULT '',
          amount REAL NOT NULL DEFAULT 0,
          due_date TEXT NOT NULL,
          is_done INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY(shop_id) REFERENCES shops(id)
        )''');
      await d.execute('''
        CREATE TABLE stock_moves(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          date TEXT NOT NULL,
          type TEXT NOT NULL,
          qty REAL NOT NULL DEFAULT 0,
          FOREIGN KEY(product_id) REFERENCES products(id)
        )''');
    });
  }

  // ---------- routes ----------
  Future<int> insertRoute(RoutePlan r) async =>
      (await db).insert('routes', r.toMap()..remove('id'));
  Future<int> updateRoute(RoutePlan r) async => (await db)
      .update('routes', r.toMap()..remove('id'), where: 'id=?', whereArgs: [r.id]);
  Future<int> deleteRoute(int id) async =>
      (await db).delete('routes', where: 'id=?', whereArgs: [id]);
  Future<List<RoutePlan>> getRoutes() async {
    final rows = await (await db).query('routes', orderBy: 'name');
    return rows.map(RoutePlan.fromMap).toList();
  }

  Future<int> countShopsOnRoute(int routeId) async {
    final r = await (await db)
        .rawQuery('SELECT COUNT(*) c FROM shops WHERE route_id=?', [routeId]);
    return (r.first['c'] as int?) ?? 0;
  }

  // ---------- shops ----------
  Future<int> insertShop(Shop s) async =>
      (await db).insert('shops', s.toMap()..remove('id'));
  Future<int> updateShop(Shop s) async => (await db)
      .update('shops', s.toMap()..remove('id'), where: 'id=?', whereArgs: [s.id]);
  Future<int> deleteShop(int id) async {
    final d = await db;
    await d.delete('order_items',
        where: 'order_id IN (SELECT id FROM orders WHERE shop_id=?)',
        whereArgs: [id]);
    await d.delete('orders', where: 'shop_id=?', whereArgs: [id]);
    await d.delete('payments', where: 'shop_id=?', whereArgs: [id]);
    await d.delete('reminders', where: 'shop_id=?', whereArgs: [id]);
    return d.delete('shops', where: 'id=?', whereArgs: [id]);
  }

  Future<List<Shop>> getShops({String search = ''}) async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT s.*, r.name AS route_name FROM shops s
      LEFT JOIN routes r ON r.id = s.route_id
      ${search.isEmpty ? '' : 'WHERE s.name LIKE ? OR s.owner_name LIKE ? OR s.phone LIKE ?'}
      ORDER BY s.name
    ''', search.isEmpty ? [] : ['%$search%', '%$search%', '%$search%']);
    return rows.map(Shop.fromMap).toList();
  }

  Future<List<Shop>> getShopsForDay(int weekday) async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT s.*, r.name AS route_name FROM shops s
      LEFT JOIN routes r ON r.id = s.route_id
      WHERE r.day_of_week = ? OR r.day_of_week = 0 OR s.route_id IS NULL
      ORDER BY s.name
    ''', [weekday]);
    return rows.map(Shop.fromMap).toList();
  }

  Future<Shop?> getShop(int id) async {
    final rows = await (await db).rawQuery('''
      SELECT s.*, r.name AS route_name FROM shops s
      LEFT JOIN routes r ON r.id = s.route_id WHERE s.id=?
    ''', [id]);
    if (rows.isEmpty) return null;
    return Shop.fromMap(rows.first);
  }

  // ---------- products ----------
  Future<int> insertProduct(Product pr) async =>
      (await db).insert('products', pr.toMap()..remove('id'));
  Future<int> updateProduct(Product pr) async => (await db).update(
      'products', pr.toMap()..remove('id'),
      where: 'id=?', whereArgs: [pr.id]);
  Future<int> deleteProduct(int id) async =>
      (await db).delete('products', where: 'id=?', whereArgs: [id]);
  Future<List<Product>> getProducts() async {
    final rows =
        await (await db).query('products', orderBy: 'brand, name');
    return rows.map(Product.fromMap).toList();
  }

  Future<Product?> getProduct(int id) async {
    final rows =
        await (await db).query('products', where: 'id=?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  Future<void> adjustStock(int productId, double delta) async {
    final d = await db;
    await d.rawUpdate(
        'UPDATE products SET stock_qty = stock_qty + ? WHERE id=?',
        [delta, productId]);
  }

  Future<void> addStockMove(StockMove m) async {
    final d = await db;
    await d.insert('stock_moves', m.toMap()..remove('id'));
    await adjustStock(m.productId, m.type == 'load' ? m.qty : -m.qty);
  }

  // ---------- orders ----------
  Future<int> insertOrder(OrderHead o, List<OrderItem> items) async {
    final d = await db;
    final orderId = await d.insert('orders', o.toMap()..remove('id'));
    for (final it in items) {
      it.orderId = orderId;
      await d.insert('order_items', it.toMap()..remove('id'));
      await adjustStock(it.productId, -it.qty);
    }
    return orderId;
  }

  Future<int> deleteOrder(int id) async {
    final d = await db;
    final items = await d.query('order_items', where: 'order_id=?', whereArgs: [id]);
    for (final m in items) {
      await adjustStock(m['product_id'] as int, ((m['qty'] as num)).toDouble());
    }
    await d.delete('order_items', where: 'order_id=?', whereArgs: [id]);
    return d.delete('orders', where: 'id=?', whereArgs: [id]);
  }

  Future<int> updateOrderStatus(int id, String status) async =>
      (await db).update('orders', {'status': status},
          where: 'id=?', whereArgs: [id]);

  Future<List<OrderHead>> getOrders(
      {int? shopId, String? from, String? to, int limit = 200}) async {
    final d = await db;
    final where = <String>[];
    final args = <Object?>[];
    if (shopId != null) {
      where.add('o.shop_id=?');
      args.add(shopId);
    }
    if (from != null) {
      where.add('o.date>=?');
      args.add(from);
    }
    if (to != null) {
      where.add('o.date<=?');
      args.add(to);
    }
    final rows = await d.rawQuery('''
      SELECT o.*, s.name AS shop_name FROM orders o
      JOIN shops s ON s.id=o.shop_id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY o.date DESC, o.id DESC LIMIT $limit
    ''', args);
    return rows.map(OrderHead.fromMap).toList();
  }

  Future<List<OrderItem>> getOrderItems(int orderId) async {
    final rows = await (await db)
        .query('order_items', where: 'order_id=?', whereArgs: [orderId]);
    return rows.map(OrderItem.fromMap).toList();
  }

  // ---------- payments ----------
  Future<int> insertPayment(Payment pay) async =>
      (await db).insert('payments', pay.toMap()..remove('id'));
  Future<int> deletePayment(int id) async =>
      (await db).delete('payments', where: 'id=?', whereArgs: [id]);

  Future<List<Payment>> getPayments({int? shopId, int limit = 200}) async {
    final rows = await (await db).rawQuery('''
      SELECT p.*, s.name AS shop_name FROM payments p
      JOIN shops s ON s.id=p.shop_id
      ${shopId == null ? '' : 'WHERE p.shop_id=?'}
      ORDER BY p.date DESC, p.id DESC LIMIT $limit
    ''', shopId == null ? [] : [shopId]);
    return rows.map(Payment.fromMap).toList();
  }

  // ---------- reminders ----------
  Future<int> insertReminder(Reminder r) async =>
      (await db).insert('reminders', r.toMap()..remove('id'));
  Future<int> updateReminder(Reminder r) async => (await db).update(
      'reminders', r.toMap()..remove('id'),
      where: 'id=?', whereArgs: [r.id]);
  Future<int> deleteReminder(int id) async =>
      (await db).delete('reminders', where: 'id=?', whereArgs: [id]);

  Future<List<Reminder>> getReminders({bool pendingOnly = false}) async {
    final rows = await (await db).rawQuery('''
      SELECT r.*, s.name AS shop_name, s.phone AS shop_phone FROM reminders r
      JOIN shops s ON s.id=r.shop_id
      ${pendingOnly ? 'WHERE r.is_done=0' : ''}
      ORDER BY r.due_date ASC
    ''');
    return rows.map(Reminder.fromMap).toList();
  }

  // ---------- summaries ----------
  Future<double> _sum(String sql, List<Object?> args) async {
    final r = await (await db).rawQuery(sql, args);
    return ((r.first['t'] as num?) ?? 0).toDouble();
  }

  Future<double> shopBalance(int shopId) async {
    final billed =
        await _sum('SELECT SUM(total) t FROM orders WHERE shop_id=?', [shopId]);
    final paid =
        await _sum('SELECT SUM(amount) t FROM payments WHERE shop_id=?', [shopId]);
    return billed - paid;
  }

  Future<double> totalOutstanding() async {
    final billed = await _sum('SELECT SUM(total) t FROM orders', []);
    final paid = await _sum('SELECT SUM(amount) t FROM payments', []);
    return billed - paid;
  }

  Future<double> salesOn(String date) async =>
      _sum('SELECT SUM(total) t FROM orders WHERE date=?', [date]);
  Future<double> recoveryOn(String date) async =>
      _sum('SELECT SUM(amount) t FROM payments WHERE date=?', [date]);
  Future<int> ordersCountOn(String date) async {
    final r = await (await db)
        .rawQuery('SELECT COUNT(*) c FROM orders WHERE date=?', [date]);
    return (r.first['c'] as int?) ?? 0;
  }

  Future<int> pendingRemindersCount() async {
    final r = await (await db).rawQuery(
        'SELECT COUNT(*) c FROM reminders WHERE is_done=0 AND due_date<=?',
        [todayStr()]);
    return (r.first['c'] as int?) ?? 0;
  }

  Future<List<LedgerEntry>> shopLedger(int shopId) async {
    final d = await db;
    final orders = await d.query('orders',
        where: 'shop_id=?', whereArgs: [shopId], orderBy: 'date ASC, id ASC');
    final pays = await d.query('payments',
        where: 'shop_id=?', whereArgs: [shopId], orderBy: 'date ASC, id ASC');
    final list = <LedgerEntry>[];
    for (final o in orders) {
      list.add(LedgerEntry(
          date: o['date'] as String,
          kind: 'order',
          label: 'Order #${o['id']}',
          amount: ((o['total'] as num?) ?? 0).toDouble(),
          refId: o['id'] as int));
    }
    for (final pmt in pays) {
      list.add(LedgerEntry(
          date: pmt['date'] as String,
          kind: 'payment',
          label: 'Payment (${pmt['mode']})',
          amount: -((pmt['amount'] as num?) ?? 0).toDouble(),
          refId: pmt['id'] as int));
    }
    list.sort((a, b) {
      final c = a.date.compareTo(b.date);
      return c != 0 ? c : a.refId.compareTo(b.refId);
    });
    return list;
  }

  Future<List<Shop>> shopsWithBalance() async {
    final shops = await getShops();
    return shops;
  }
}
