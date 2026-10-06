import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/services.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();
  bool _busy = false;
  String _lastMsg = '';
  List<String> _lastFiles = [];

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final fmt =
        DateFormat('d MMM yyyy', st.isUrdu ? 'ur' : 'en');
    return Scaffold(
      appBar: AppBar(title: Text(st.s('reports'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(st.s('reportsDesc')),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(
                              '${st.s('fromDate')}: ${fmt.format(_from)}')),
                      TextButton(
                        onPressed: () async {
                          final d = await pickDate(context, _from);
                          if (d != null) setState(() => _from = d);
                        },
                        child: Text(st.s('edit')),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                          child:
                              Text('${st.s('toDate')}: ${fmt.format(_to)}')),
                      TextButton(
                        onPressed: () async {
                          final d = await pickDate(context, _to);
                          if (d != null) setState(() => _to = d);
                        },
                        child: Text(st.s('edit')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : _export,
                      icon: const Icon(Icons.folder),
                      label: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text(st.s('exportFolders'))),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed:
                          (_busy || _lastFiles.isEmpty) ? null : _share,
                      icon: const Icon(Icons.share),
                      label: Text(st.s('shareExports')),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: _busy ? null : _backup,
                    icon: const Icon(Icons.backup),
                    label: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(st.s('backupDb'))),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _restore,
                    icon: const Icon(Icons.restore),
                    label: Text(st.s('restoreDb')),
                  ),
                ],
              ),
            ),
          ),
          if (_lastMsg.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              color: Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_lastMsg,
                    style: const TextStyle(fontSize: 13)),
              ),
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  Future<void> _export() async {
    final st = context.read<AppState>();
    setState(() {
      _busy = true;
      _lastMsg = '';
    });
    try {
      final from = DateFormat('yyyy-MM-dd').format(_from);
      final to = DateFormat('yyyy-MM-dd').format(_to);
      final files = await ExportService.exportFolders(from, to);
      setState(() {
        _lastFiles = files;
        _lastMsg = files.isEmpty
            ? st.s('exportEmpty')
            : '${st.s('exportDone')}\n${files.length} files → Phone storage / OrderBooker / <${st.s('route')}> / <date> / <${st.s('shops')}> ';
      });
      st.refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    final st = context.read<AppState>();
    await ShareService.shareFiles(_lastFiles, st.s('appTitle'));
  }

  Future<void> _backup() async {
    final st = context.read<AppState>();
    setState(() => _busy = true);
    try {
      final path = await ExportService.backupDatabase();
      setState(() => _lastMsg = st.s('backupDone'));
      await ShareService.shareFiles([path], st.s('backupDb'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final st = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(st.s('restoreDb')),
        content: Text(st.s('restoreConfirm')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(st.s('no'))),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(st.s('yes'),
                  style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    final res = await FilePicker.platform.pickFiles();
    final path = res?.files.single.path;
    if (path == null) return;
    setState(() => _busy = true);
    try {
      await ExportService.restoreDatabase(path);
      setState(() => _lastMsg = st.s('restoreDone'));
      st.refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
