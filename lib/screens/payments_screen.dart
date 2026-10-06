import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../db/app_database.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

class PaymentsScreen extends StatefulWidget {
  final int? presetShopId;
  const PaymentsScreen({super.key, this.presetShopId});
  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  late Future<List<Payment>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    if (widget.presetShopId != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _showForm(widget.presetShopId));
    }
  }

  Future<List<Payment>> _load() => AppDatabase.instance.getPayments();
  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(st.s('payments'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(null),
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<Payment>>(
        future: _future,
        builder: (c, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return EmptyView(text: st.s('payments'), icon: Icons.payments);
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (c, i) {
              final p = list[i];
              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                      backgroundColor: Colors.green[100],
                      child: const Icon(Icons.payments,
                          color: Colors.green)),
                  title: Text(p.shopName ?? ''),
                  subtitle: Text(
                      '${p.date} • ${p.mode == 'cash' ? st.s('cash') : st.s('online')}${p.notes.isNotEmpty ? ' • ${p.notes}' : ''}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Money(p.amount,
                          bold: true, color: Colors.green[800]),
                      IconButton(
                        icon: const Icon(Icons.delete,
                            color: Colors.red, size: 20),
                        onPressed: () async {
                          if (await confirmDelete(context)) {
                            await AppDatabase.instance
                                .deletePayment(p.id!);
                            context.read<AppState>().refresh();
                            _reload();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showForm(int? presetShopId) async {
    final st = context.read<AppState>();
    final shops = await AppDatabase.instance.getShops();
    if (shops.isEmpty || !mounted) return;
    int? shopId = presetShopId ?? shops.first.id;
    // prefill outstanding as hint
    double bal = 0;
    if (shopId != null) bal = await AppDatabase.instance.shopBalance(shopId);
    final amount = TextEditingController(
        text: bal > 0 ? '${bal.round()}' : '');
    final notes = TextEditingController();
    DateTime date = DateTime.now();
    String mode = 'cash';
    final formKey = GlobalKey<FormState>();
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: Text(st.s('newPayment')),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: shopId,
                    decoration: fieldDec(context, st.s('selectShop')),
                    items: shops
                        .map((s) => DropdownMenuItem(
                            value: s.id, child: Text(s.name)))
                        .toList(),
                    onChanged: (v) async {
                      shopId = v;
                      if (v != null) {
                        final b = await AppDatabase.instance
                            .shopBalance(v);
                        setD(() => amount.text =
                            b > 0 ? '${b.round()}' : '');
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                      controller: amount,
                      keyboardType: TextInputType.number,
                      decoration:
                          fieldDec(context, st.s('paymentAmount')),
                      validator: (v) => reqNum(v, st)),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(st.s('paymentDate')),
                    subtitle: Text(DateFormat('d MMM yyyy',
                            st.isUrdu ? 'ur' : 'en')
                        .format(date)),
                    trailing: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final d = await pickDate(context, date);
                        if (d != null) setD(() => date = d);
                      },
                    ),
                  ),
                  RadioGroup<String>(
                    groupValue: mode,
                    onChanged: (v) => setD(() => mode = v!),
                    child: Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: Text(st.s('cash')),
                            value: 'cash',
                            dense: true,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: Text(st.s('online')),
                            value: 'online',
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextFormField(
                      controller: notes,
                      decoration: fieldDec(context,
                          '${st.s('notes')} (${st.s('optional')})')),
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
                if (shopId == null ||
                    !formKey.currentState!.validate()) return;
                await AppDatabase.instance.insertPayment(Payment(
                    shopId: shopId!,
                    date: DateFormat('yyyy-MM-dd').format(date),
                    amount: double.parse(amount.text.trim()),
                    mode: mode,
                    notes: notes.text.trim()));
                if (c.mounted) Navigator.pop(c);
                st.refresh();
                _reload();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(st.s('paymentSaved'))));
                }
              },
              child: Text(st.s('save')),
            ),
          ],
        ),
      ),
    );
  }
}
