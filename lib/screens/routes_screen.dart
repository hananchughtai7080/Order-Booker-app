import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/app_database.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});
  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  late Future<List<RoutePlan>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<RoutePlan>> _load() => AppDatabase.instance.getRoutes();
  void _reload() => setState(() => _future = _load());

  String _dayName(AppState st, int d) {
    switch (d) {
      case 1:
        return st.s('dayMon');
      case 2:
        return st.s('dayTue');
      case 3:
        return st.s('dayWed');
      case 4:
        return st.s('dayThu');
      case 5:
        return st.s('dayFri');
      case 6:
        return st.s('daySat');
      case 7:
        return st.s('daySun');
      default:
        return st.s('anyDay');
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(st.s('routes'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(null),
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<RoutePlan>>(
        future: _future,
        builder: (c, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final routes = snap.data!;
          if (routes.isEmpty) {
            return EmptyView(
                text: st.s('routes'), icon: Icons.route);
          }
          return ListView.builder(
            itemCount: routes.length,
            itemBuilder: (c, i) {
              final r = routes[i];
              return FutureBuilder<int>(
                future:
                    AppDatabase.instance.countShopsOnRoute(r.id!),
                builder: (c, cs) => Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  child: ListTile(
                    leading: const CircleAvatar(
                        child: Icon(Icons.route)),
                    title: Text(r.name),
                    subtitle: Text(
                        '${st.s('dayOfWeek')}: ${_dayName(st, r.dayOfWeek)} • ${cs.data ?? 0} ${st.s('shopsOnRoute')}'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') _showForm(r);
                        if (v == 'delete') _delete(r);
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
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _delete(RoutePlan r) async {
    if (await confirmDelete(context)) {
      await AppDatabase.instance.deleteRoute(r.id!);
      context.read<AppState>().refresh();
      _reload();
    }
  }

  Future<void> _showForm(RoutePlan? existing) async {
    final st = context.read<AppState>();
    final name = TextEditingController(text: existing?.name ?? '');
    int day = existing?.dayOfWeek ?? 0;
    final formKey = GlobalKey<FormState>();
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: Text(
              existing == null ? st.s('newRoute') : st.s('editRoute')),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                    controller: name,
                    decoration:
                        fieldDec(context, st.s('routeName')),
                    validator: (v) => req(v, st)),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: day,
                  decoration:
                      fieldDec(context, st.s('dayOfWeek')),
                  items: [
                    for (int d = 0; d <= 7; d++)
                      DropdownMenuItem(
                          value: d,
                          child: Text(_dayName(st, d))),
                  ],
                  onChanged: (v) => setD(() => day = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text(st.s('cancel'))),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final r = RoutePlan(
                    id: existing?.id,
                    name: name.text.trim(),
                    dayOfWeek: day);
                if (existing == null) {
                  await AppDatabase.instance.insertRoute(r);
                } else {
                  await AppDatabase.instance.updateRoute(r);
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
