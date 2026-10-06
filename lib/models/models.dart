class RoutePlan {
  int? id;
  String name;
  int dayOfWeek; // 1=Mon .. 7=Sun, 0=any day
  RoutePlan({this.id, required this.name, required this.dayOfWeek});

  factory RoutePlan.fromMap(Map<String, Object?> m) => RoutePlan(
        id: m['id'] as int?,
        name: m['name'] as String,
        dayOfWeek: m['day_of_week'] as int,
      );

  Map<String, Object?> toMap() =>
      {'id': id, 'name': name, 'day_of_week': dayOfWeek};
}

class Shop {
  int? id;
  String name;
  String ownerName;
  String phone;
  String address;
  int? routeId;
  String? routeName;
  Shop(
      {this.id,
      required this.name,
      this.ownerName = '',
      this.phone = '',
      this.address = '',
      this.routeId,
      this.routeName});

  factory Shop.fromMap(Map<String, Object?> m) => Shop(
        id: m['id'] as int?,
        name: m['name'] as String,
        ownerName: (m['owner_name'] as String?) ?? '',
        phone: (m['phone'] as String?) ?? '',
        address: (m['address'] as String?) ?? '',
        routeId: m['route_id'] as int?,
        routeName: m['route_name'] as String?,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'owner_name': ownerName,
        'phone': phone,
        'address': address,
        'route_id': routeId,
      };
}

class Product {
  int? id;
  String name;
  String brand;
  String unit;
  double rate;
  double stockQty;
  Product(
      {this.id,
      required this.name,
      this.brand = '',
      this.unit = '',
      this.rate = 0,
      this.stockQty = 0});

  factory Product.fromMap(Map<String, Object?> m) => Product(
        id: m['id'] as int?,
        name: m['name'] as String,
        brand: (m['brand'] as String?) ?? '',
        unit: (m['unit'] as String?) ?? '',
        rate: ((m['rate'] as num?) ?? 0).toDouble(),
        stockQty: ((m['stock_qty'] as num?) ?? 0).toDouble(),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'brand': brand,
        'unit': unit,
        'rate': rate,
        'stock_qty': stockQty,
      };
}

class OrderHead {
  int? id;
  int shopId;
  String date; // yyyy-MM-dd
  String createdAt;
  String status; // booked | delivered
  double total;
  String notes;
  String? shopName;
  OrderHead(
      {this.id,
      required this.shopId,
      required this.date,
      required this.createdAt,
      this.status = 'booked',
      this.total = 0,
      this.notes = '',
      this.shopName});

  factory OrderHead.fromMap(Map<String, Object?> m) => OrderHead(
        id: m['id'] as int?,
        shopId: m['shop_id'] as int,
        date: m['date'] as String,
        createdAt: (m['created_at'] as String?) ?? '',
        status: (m['status'] as String?) ?? 'booked',
        total: ((m['total'] as num?) ?? 0).toDouble(),
        notes: (m['notes'] as String?) ?? '',
        shopName: m['shop_name'] as String?,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'shop_id': shopId,
        'date': date,
        'created_at': createdAt,
        'status': status,
        'total': total,
        'notes': notes,
      };
}

class OrderItem {
  int? id;
  int orderId;
  int productId;
  String productName;
  double qty;
  double rate;
  double amount;
  OrderItem(
      {this.id,
      required this.orderId,
      required this.productId,
      required this.productName,
      required this.qty,
      required this.rate,
      required this.amount});

  factory OrderItem.fromMap(Map<String, Object?> m) => OrderItem(
        id: m['id'] as int?,
        orderId: m['order_id'] as int,
        productId: m['product_id'] as int,
        productName: (m['product_name'] as String?) ?? '',
        qty: ((m['qty'] as num?) ?? 0).toDouble(),
        rate: ((m['rate'] as num?) ?? 0).toDouble(),
        amount: ((m['amount'] as num?) ?? 0).toDouble(),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'order_id': orderId,
        'product_id': productId,
        'product_name': productName,
        'qty': qty,
        'rate': rate,
        'amount': amount,
      };
}

class Payment {
  int? id;
  int shopId;
  String date;
  double amount;
  String mode; // cash | online
  String notes;
  String? shopName;
  Payment(
      {this.id,
      required this.shopId,
      required this.date,
      required this.amount,
      this.mode = 'cash',
      this.notes = '',
      this.shopName});

  factory Payment.fromMap(Map<String, Object?> m) => Payment(
        id: m['id'] as int?,
        shopId: m['shop_id'] as int,
        date: m['date'] as String,
        amount: ((m['amount'] as num?) ?? 0).toDouble(),
        mode: (m['mode'] as String?) ?? 'cash',
        notes: (m['notes'] as String?) ?? '',
        shopName: m['shop_name'] as String?,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'shop_id': shopId,
        'date': date,
        'amount': amount,
        'mode': mode,
        'notes': notes,
      };
}

class Reminder {
  int? id;
  int shopId;
  String title;
  double amount;
  String dueDate; // yyyy-MM-dd
  int isDone; // 0/1
  String? shopName;
  String? shopPhone;
  Reminder(
      {this.id,
      required this.shopId,
      this.title = '',
      this.amount = 0,
      required this.dueDate,
      this.isDone = 0,
      this.shopName,
      this.shopPhone});

  factory Reminder.fromMap(Map<String, Object?> m) => Reminder(
        id: m['id'] as int?,
        shopId: m['shop_id'] as int,
        title: (m['title'] as String?) ?? '',
        amount: ((m['amount'] as num?) ?? 0).toDouble(),
        dueDate: m['due_date'] as String,
        isDone: (m['is_done'] as int?) ?? 0,
        shopName: m['shop_name'] as String?,
        shopPhone: m['shop_phone'] as String?,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'shop_id': shopId,
        'title': title,
        'amount': amount,
        'due_date': dueDate,
        'is_done': isDone,
      };
}

class StockMove {
  int? id;
  int productId;
  String date;
  String type; // load | return
  double qty;
  StockMove(
      {this.id,
      required this.productId,
      required this.date,
      required this.type,
      required this.qty});

  Map<String, Object?> toMap() => {
        'id': id,
        'product_id': productId,
        'date': date,
        'type': type,
        'qty': qty,
      };
}

/// Combined ledger entry for the shop detail ledger tab.
class LedgerEntry {
  final String date;
  final String kind; // 'order' | 'payment'
  final String label;
  final double amount; // + for order, - for payment
  final int refId;
  LedgerEntry(
      {required this.date,
      required this.kind,
      required this.label,
      required this.amount,
      required this.refId});
}
