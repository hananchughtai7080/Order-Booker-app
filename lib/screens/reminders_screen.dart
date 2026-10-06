import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../db/app_database.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});
  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  late Future<List<Reminder>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Reminder>> _load() => AppDatabase.instance.getReminders();
  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final today = todayStr();
    return Scaffold(
      appBar: AppBar(title: Text(st.s('reminders'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<Reminder>>(
        future: _future,
        builder: (c, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return EmptyView(
                text: st.s('noReminders'), icon: Icons.notifications);
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (c, i) {
              final r = list[i];
              final done = r.isDone == 1;
              final overdue = !done && r.dueDate.compareTo(today) < 0;
              final dueToday = !done && r.dueDate == today;
              final status = done
                  ? st.s('completed')
                  : overdue
                      ? st.s('overdue')
                      : dueToday
                          ? st.s('dueToday')
                          : st.s('upcoming');
              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
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
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(r.shopName ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                Text(
                                    '${r.title.isEmpty ? st.s('reminderFor') : r.title} • $status',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: overdue
                                            ? Colors.red
                                            : Colors.grey[700],
                                        decoration: done
                                            ? TextDecoration.lineThrough
                                            : null)),
                                Text(
                                    '${st.s('dueDate')}: ${r.dueDate}${r.amount > 0 ? ' • Rs ${fmtMoney(r.amount)}' : ''}',
                                    style:
                                        const TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        children: [
                          if (!done) ...[
                            if ((r.shopPhone ?? '').isNotEmpty) ...[
                              TextButton.icon(
                                icon: const Icon(Icons.chat, size: 16),
                                label: Text(st.s('sendWhatsApp')),
                                onPressed: () => _send(r, st,
                                    ShareService.whatsapp),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.sms, size: 16),
                                label: Text(st.s('sendSms')),
                                onPressed: () =>
                                    _send(r, st, ShareService.sms),
                              ),
                            ],
                            TextButton(
                                onPressed: () => _toggle(r, true),
                                child: Text(st.s('markDone'))),
                          ] else
                            TextButton(
                                onPressed: () => _toggle(r, false),
                                child: Text(st.s('reopen'))),
                          TextButton(
                            onPressed: () async {
                              if (await confirmDelete(context)) {
                                await AppDatabase.instance
                                    .deleteReminder(r.id!);
                                context.read<AppState>().refresh();
                                _reload();
                              }
                            },
                            child: Text(st.s('delete'),
                                style: const TextStyle(
                                    color: Colors.red)),
                          ),
                        ],
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

  Future<void> _toggle(Reminder r, bool done) async {
    r.isDone = done ? 1 : 0;
    await AppDatabase.instance.updateReminder(r);
    context.read<AppState>().refresh();
    _reload();
  }

  void _send(Reminder r, AppState st,
      Future<void> Function(String, String) sender) {
    final msg = st
        .s('reminderMsgDue')
        .replaceAll('{shop}', r.shopName ?? '')
        .replaceAll('{amount}', fmtMoney(r.amount))
        .replaceAll('{date}', r.dueDate);
    sender(r.shopPhone ?? '', msg);
  }

  Future<void> _showForm() async {
    final st = context.read<AppState>();
    final shops = await AppDatabase.instance.getShops();
    if (shops.isEmpty || !mounted) return;
    int? shopId = shops.first.id;
    double bal =
        await AppDatabase.instance.shopBalance(shopId!);
    final title = TextEditingController();
    final amount =
        TextEditingController(text: bal > 0 ? '${bal.round()}' : '');
    DateTime due = DateTime.now();
    final formKey = GlobalKey<FormState>();
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: Text(st.s('newReminder')),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: shopId,
                    decoration:
                        fieldDec(context, st.s('selectShop')),
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
                      controller: title,
                      decoration: fieldDec(context,
                          '${st.s('reminderFor')} (${st.s('optional')})')),
                  const SizedBox(height: 10),
                  TextFormField(
                      controller: amount,
                      keyboardType: TextInputType.number,
                      decoration:
                          fieldDec(context, st.s('reminderAmount')),
                      validator: (v) => reqNum(v, st)),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(st.s('dueDate')),
                    subtitle: Text(DateFormat('d MMM yyyy',
                            st.isUrdu ? 'ur' : 'en')
                        .format(due)),
                    trailing: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final d = await pickDate(context, due);
                        if (d != null) setD(() => due = d);
                      },
                    ),
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
                if (shopId == null ||
                    !formKey.currentState!.validate()) return;
                await AppDatabase.instance.insertReminder(Reminder(
                    shopId: shopId!,
                    title: title.text.trim(),
                    amount: double.parse(amount.text.trim()),
                    dueDate:
                        DateFormat('yyyy-MM-dd').format(due)));
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
