import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/app_database.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'shop_detail_screen.dart';

class ShopsScreen extends StatefulWidget {
  final bool openAdd;
  const ShopsScreen({super.key, this.openAdd = false});
  @override
  State<ShopsScreen> createState() => _ShopsScreenState();
}

class _ShopsScreenState extends State<ShopsScreen> {
  String _search = '';
  late Future<List<Shop>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    if (widget.openAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showForm(null));
    }
  }

  Future<List<Shop>> _load() =>
      AppDatabase.instance.getShops(search: _search);

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(st.s('shops'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(null),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: st.s('searchShops'),
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) {
                _search = v;
                _reload();
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Shop>>(
              future: _future,
              builder: (c, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final shops = snap.data!;
                if (shops.isEmpty) {
                  return EmptyView(text: st.s('searchShops'));
                }
                return ListView.builder(
                  itemCount: shops.length,
                  itemBuilder: (c, i) {
                    final s = shops[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: ListTile(
                        leading: const CircleAvatar(
                            child: Icon(Icons.store)),
                        title: Text(s.name),
                        subtitle: Text(
                            '${s.ownerName}${s.routeName != null ? ' • ${s.routeName}' : ''}${s.phone.isNotEmpty ? '\n${s.phone}' : ''}'),
                        isThreeLine: s.phone.isNotEmpty,
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') _showForm(s);
                            if (v == 'delete') _delete(s);
                          },
                          itemBuilder: (c) => [
                            PopupMenuItem(
                                value: 'edit',
                                child: Text(st.s('edit'))),
                            PopupMenuItem(
                                value: 'delete',
                                child: Text(st.s('delete'),
                                    style: const TextStyle(
                                        color: Colors.red))),
                          ],
                        ),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    ShopDetailScreen(shopId: s.id!))),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(Shop s) async {
    if (await confirmDelete(context)) {
      await AppDatabase.instance.deleteShop(s.id!);
      context.read<AppState>().refresh();
      _reload();
    }
  }

  Future<void> _showForm(Shop? existing) async {
    final st = context.read<AppState>();
    final name = TextEditingController(text: existing?.name ?? '');
    final owner = TextEditingController(text: existing?.ownerName ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final address = TextEditingController(text: existing?.address ?? '');
    final routes = await AppDatabase.instance.getRoutes();
    int? routeId = existing?.routeId;
    final formKey = GlobalKey<FormState>();
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
        title: Text(existing == null ? st.s('newShop') : st.s('editShop')),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                    controller: name,
                    decoration: fieldDec(context, st.s('shopName')),
                    validator: (v) => req(v, st)),
                const SizedBox(height: 10),
                TextFormField(
                    controller: owner,
                    decoration: fieldDec(context, st.s('ownerName'))),
                const SizedBox(height: 10),
                TextFormField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: fieldDec(context, st.s('phone'))),
                const SizedBox(height: 10),
                TextFormField(
                    controller: address,
                    decoration: fieldDec(context,
                        '${st.s('address')} (${st.s('optional')})')),
                const SizedBox(height: 10),
                DropdownButtonFormField<int?>(
                  initialValue: routeId,
                  decoration: fieldDec(context, st.s('route')),
                  items: [
                    DropdownMenuItem<int?>(
                        value: null, child: Text(st.s('noRoute'))),
                    ...routes.map((r) => DropdownMenuItem<int?>(
                        value: r.id, child: Text(r.name))),
                  ],
                  onChanged: (v) => setD(() => routeId = v),
                ),
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
              final shop = Shop(
                id: existing?.id,
                name: name.text.trim(),
                ownerName: owner.text.trim(),
                phone: phone.text.trim(),
                address: address.text.trim(),
                routeId: routeId,
              );
              if (existing == null) {
                await AppDatabase.instance.insertShop(shop);
              } else {
                await AppDatabase.instance.updateShop(shop);
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
