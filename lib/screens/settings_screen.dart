import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _target;

  @override
  void initState() {
    super.initState();
    final st = context.read<AppState>();
    _target = TextEditingController(
        text: st.dailyTarget > 0 ? '${st.dailyTarget.round()}' : '');
  }

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(st.s('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(st.s('language'),
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Card(
            child: RadioGroup<String>(
              groupValue: st.lang,
              onChanged: (v) =>
                  context.read<AppState>().setLang(v!),
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: Text(st.s('english')),
                    value: 'en',
                  ),
                  const RadioListTile<String>(
                    title: Text('اردو'),
                    value: 'ur',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(st.s('dailyTarget'),
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _target,
                      keyboardType: TextInputType.number,
                      decoration:
                          fieldDec(context, st.s('dailyTarget')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final v =
                          double.tryParse(_target.text.trim()) ?? 0;
                      context
                          .read<AppState>()
                          .setDailyTarget(v);
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text(st.s('stockUpdated'))));
                    },
                    child: Text(st.s('save')),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(st.s('about'),
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(st.s('aboutText')),
                  const SizedBox(height: 8),
                  const Text('Order Booker v1.0.0',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
