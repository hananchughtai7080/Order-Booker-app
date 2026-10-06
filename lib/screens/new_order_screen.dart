import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../db/app_database.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

class NewOrderScreen extends StatefulWidget {
  final int? presetShopId;
  const NewOrderScreen({super.key, this.presetShopId});
  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _OrderRow {
  Product? product;
  final qty = TextEditingController(text: '1');
  final rate = TextEditingController();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  List<Shop> _shops = [];
  List<Product> _products = [];
  int? _shopId;
  DateTime _date = DateTime.now();
  final List<_OrderRow> _rows = [_OrderRow()];
  final _notes = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final db = AppDatabase.instance;
    _shops = await db.getShops();
    _products = await db.getProducts();
    _shopId = widget.presetShopId ?? (_shops.isEmpty ? null : _shops.first.id);
    setState(() => _loading = false);
  }

  double get _total {
    double t = 0;
    for (final r in _rows) {
      final q = double.tryParse(r.qty.text) ?? 0;
      final rt = double.tryParse(r.rate.text) ?? 0;
      t += q * rt;
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    if (_loading) {
      return Scaffold(
          appBar: AppBar(title: Text(st.s('newOrder'))),
          body: const Center(child: CircularProgressIndicator()));
    }
    if (_shops.isEmpty || _products.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(st.s('newOrder'))),
        body: Center(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(st.s('getStartedBody'),
                    textAlign: TextAlign.center))),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(st.s('newOrder'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          DropdownButtonFormField<int>(
            initialValue: _shopId,
            decoration: fieldDec(context, st.s('selectShop')),
            items: _shops
                .map((s) => DropdownMenuItem(
                    value: s.id, child: Text(s.name)))
                .toList(),
            onChanged: (v) => setState(() => _shopId = v),
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title: Text(st.s('orderDate')),
            subtitle: Text(
                DateFormat('d MMM yyyy', st.isUrdu ? 'ur' : 'en')
                    .format(_date)),
            trailing: TextButton(
              onPressed: () async {
                final d = await pickDate(context, _date);
                if (d != null) setState(() => _date = d);
              },
              child: Text(st.s('edit')),
            ),
          ),
          SectionTitle(
              title: st.s('items'),
              trailing: IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green),
                  onPressed: () => setState(() => _rows.add(_OrderRow())))),
          ..._rows.asMap().entries.map((e) {
            final i = e.key;
            final r = e.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<Product>(
                            initialValue: r.product,
                            decoration:
                                fieldDec(context, st.s('selectProduct')),
                            items: _products
                                .map((p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(
                                        '${p.name} (${fmtMoney(p.rate)})',
                                        overflow:
                                            TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: (p) => setState(() {
                              r.product = p;
                              if (p != null) {
                                r.rate.text = '${p.rate}';
                              }
                            }),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete,
                              color: Colors.red),
                          onPressed: _rows.length > 1
                              ? () => setState(() => _rows.removeAt(i))
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: r.qty,
                            keyboardType: TextInputType.number,
                            decoration:
                                fieldDec(context, st.s('qty')),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: r.rate,
                            keyboardType: TextInputType.number,
                            decoration:
                                fieldDec(context, st.s('rate')),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 90,
                          child: Builder(builder: (_) {
                            final q =
                                double.tryParse(r.qty.text) ?? 0;
                            final rt =
                                double.tryParse(r.rate.text) ?? 0;
                            return Money(q * rt, bold: true);
                          }),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          TextField(
              controller: _notes,
              decoration: fieldDec(
                  context, '${st.s('notes')} (${st.s('optional')})')),
          const SizedBox(height: 16),
          Card(
            color: Colors.green[50],
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(st.s('total'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  Money(_total, size: 20, bold: true, color: Colors.green[800]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(st.s('save'),
                    style: const TextStyle(fontSize: 16))),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final st = context.read<AppState>();
    if (_shopId == null) return;
    final items = <OrderItem>[];
    for (final r in _rows) {
      if (r.product == null) continue;
      final q = double.tryParse(r.qty.text.trim()) ?? 0;
      final rt = double.tryParse(r.rate.text.trim()) ?? 0;
      if (q <= 0) continue;
      items.add(OrderItem(
          orderId: 0,
          productId: r.product!.id!,
          productName: r.product!.name,
          qty: q,
          rate: rt,
          amount: q * rt));
    }
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(st.s('orderItemsEmpty'))));
      return;
    }
    final total = items.fold<double>(0, (a, b) => a + b.amount);
    await AppDatabase.instance.insertOrder(
        OrderHead(
            shopId: _shopId!,
            date: DateFormat('yyyy-MM-dd').format(_date),
            createdAt: nowStr(),
            total: total,
            notes: _notes.text.trim()),
        items);
    st.refresh();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(st.s('orderSaved'))));
      Navigator.pop(context);
    }
  }
}
