import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/app_database.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

class ProductsScreen extends StatefulWidget {
  final bool openAdd;
  const ProductsScreen({super.key, this.openAdd = false});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  late Future<List<Product>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    if (widget.openAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showForm(null));
    }
  }

  Future<List<Product>> _load() => AppDatabase.instance.getProducts();
  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(st.s('products'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(null),
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<Product>>(
        future: _future,
        builder: (c, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final products = snap.data!;
          if (products.isEmpty) {
            return EmptyView(text: st.s('products'));
          }
          final Map<String, List<Product>> byBrand = {};
          for (final p in products) {
            final b = p.brand.isEmpty ? st.s('brandOther') : p.brand;
            byBrand.putIfAbsent(b, () => []).add(p);
          }
          return ListView(
            children: byBrand.entries.map((e) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(e.key,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                  ...e.value.map((p) => Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        child: ListTile(
                          leading: const CircleAvatar(
                              child: Icon(Icons.inventory_2)),
                          title: Text(p.name),
                          subtitle: Text(
                              '${st.s('priceRate')}: Rs ${fmtMoney(p.rate)}${p.unit.isNotEmpty ? ' / ${p.unit}' : ''}\n${st.s('stock')}: ${p.stockQty}'),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'edit') _showForm(p);
                              if (v == 'load') _stockMove(p, 'load');
                              if (v == 'return') _stockMove(p, 'return');
                              if (v == 'delete') _delete(p);
                            },
                            itemBuilder: (c) => [
                              PopupMenuItem(
                                  value: 'edit',
                                  child: Text(st.s('edit'))),
                              PopupMenuItem(
                                  value: 'load',
                                  child: Text(st.s('loadStock'))),
                              PopupMenuItem(
                                  value: 'return',
                                  child: Text(st.s('returnStock'))),
                              PopupMenuItem(
                                  value: 'delete',
                                  child: Text(st.s('delete'),
                                      style: const TextStyle(
                                          color: Colors.red))),
                            ],
                          ),
                        ),
                      )),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Future<void> _delete(Product p) async {
    if (await confirmDelete(context)) {
      await AppDatabase.instance.deleteProduct(p.id!);
      context.read<AppState>().refresh();
      _reload();
    }
  }

  Future<void> _stockMove(Product p, String type) async {
    final st = context.read<AppState>();
    final qty = TextEditingController();
    final formKey = GlobalKey<FormState>();
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
            '${type == 'load' ? st.s('loadStock') : st.s('returnStock')}: ${p.name}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: qty,
            keyboardType: TextInputType.number,
            decoration: fieldDec(context, st.s('stockQty')),
            validator: (v) => reqNum(v, st),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text(st.s('cancel'))),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              await AppDatabase.instance.addStockMove(StockMove(
                  productId: p.id!,
                  date: todayStr(),
                  type: type,
                  qty: double.parse(qty.text.trim())));
              if (c.mounted) Navigator.pop(c);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(st.s('stockUpdated'))));
              }
              _reload();
            },
            child: Text(st.s('save')),
          ),
        ],
      ),
    );
  }

  Future<void> _showForm(Product? existing) async {
    final st = context.read<AppState>();
    final name = TextEditingController(text: existing?.name ?? '');
    final unit = TextEditingController(text: existing?.unit ?? '');
    final rate =
        TextEditingController(text: existing == null ? '' : '${existing.rate}');
    String brand = existing?.brand ?? st.s('brandAlSaudia');
    final brands = [st.s('brandAlSaudia'), st.s('brandSmartCare'), st.s('brandOther')];
    if (!brands.contains(brand)) brand = st.s('brandOther');
    final formKey = GlobalKey<FormState>();
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
        title:
            Text(existing == null ? st.s('newProduct') : st.s('editProduct')),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                    controller: name,
                    decoration:
                        fieldDec(context, st.s('productName')),
                    validator: (v) => req(v, st)),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: brand,
                  decoration: fieldDec(context, st.s('brand')),
                  items: brands
                      .map((b) =>
                          DropdownMenuItem(value: b, child: Text(b)))
                      .toList(),
                  onChanged: (v) => setD(() => brand = v!),
                ),
                const SizedBox(height: 10),
                TextFormField(
                    controller: unit,
                    decoration: fieldDec(context,
                        '${st.s('unit')} (${st.s('optional')})')),
                const SizedBox(height: 10),
                TextFormField(
                    controller: rate,
                    keyboardType: TextInputType.number,
                    decoration: fieldDec(context, st.s('priceRate')),
                    validator: (v) => reqNum(v, st)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text(st.s('cancel'))),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final p = Product(
                id: existing?.id,
                name: name.text.trim(),
                brand: brand,
                unit: unit.text.trim(),
                rate: double.parse(rate.text.trim()),
                stockQty: existing?.stockQty ?? 0,
              );
              if (existing == null) {
                await AppDatabase.instance.insertProduct(p);
              } else {
                await AppDatabase.instance.updateProduct(p);
              }
              if (c.mounted) Navigator.pop(c);
              st.refresh();
              _reload();
            },
            child: Text(st.s('save')),
          ),
        ],
        ),
      ),
    );
  }
}
