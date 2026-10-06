import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/services.dart';
import '../state/app_state.dart';

String t(BuildContext c, String key) => c.watch<AppState>().s(key);
String ts(BuildContext c, String key) => c.read<AppState>().s(key);

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const StatCard(
      {super.key,
      required this.title,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(value,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionTitle({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  final String text;
  final IconData icon;
  const EmptyView({super.key, required this.text, this.icon = Icons.inbox});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

Future<bool> confirmDelete(BuildContext context) async {
  final s = context.read<AppState>();
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(s.s('deleteConfirmTitle')),
      content: Text(s.s('deleteConfirmBody')),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(s.s('no'))),
        TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(s.s('yes'),
                style: const TextStyle(color: Colors.red))),
      ],
    ),
  );
  return ok == true;
}

class Money extends StatelessWidget {
  final double value;
  final double size;
  final Color? color;
  final bool bold;
  const Money(this.value,
      {super.key, this.size = 14, this.color, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Text('Rs ${fmtMoney(value)}',
        style: TextStyle(
            fontSize: size,
            color: color,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal));
  }
}

Future<DateTime?> pickDate(BuildContext context, DateTime initial) {
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2020),
    lastDate: DateTime(2040),
  );
}

InputDecoration fieldDec(BuildContext context, String label) =>
    InputDecoration(labelText: label, border: const OutlineInputBorder());

String? req(String? v, AppState s) =>
    (v == null || v.trim().isEmpty) ? s.s('fieldRequired') : null;

String? reqNum(String? v, AppState s) {
  if (v == null || v.trim().isEmpty) return s.s('fieldRequired');
  if (double.tryParse(v.trim()) == null) return s.s('invalidNumber');
  return null;
}
