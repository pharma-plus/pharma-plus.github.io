import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/api_client.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/status_chip.dart';

/// Présences : pointage, congés et synthèse mensuelle.
class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<Map<String, dynamic>> _records = [];
  List<Map<String, dynamic>> _leaves = [];
  List<Map<String, dynamic>> _summary = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final now = DateTime.now();
    final month = now.toIso8601String().split('T').first.substring(0, 7);
    final results = await Future.wait([
      ApiClient.instance
          .get<Map<String, dynamic>>('/attendance', query: {'limit': 100}),
      ApiClient.instance.get<Map<String, dynamic>>('/attendance/leaves',
          query: {'limit': 100}),
      ApiClient.instance.get<Map<String, dynamic>>('/attendance/summary',
          query: {'month': month}),
    ]);
    if (!mounted) return;
    final records = results[0];
    final leaves = results[1];
    final summary = results[2];
    if (!records.success || !leaves.success || !summary.success) {
      setState(() {
        _loading = false;
        _error = (records.error ?? leaves.error ?? summary.error)?.message;
      });
      return;
    }
    setState(() {
      _records = (records.data?['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      _leaves = (leaves.data?['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      _summary = (summary.data?['rows'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      _loading = false;
    });
  }

  Future<void> _clock({required bool in_}) async {
    final locale = context.read<AuthStore>().locale;
    final result = await ApiClient.instance.get<Map<String, dynamic>>(
      '/employees',
      query: {'limit': 200, 'status': 'active'},
    );
    if (!mounted) return;
    final employees = (result.data?['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    if (employees.isEmpty) return;
    String? employeeId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(in_ ? S.t('clockIn', locale) : S.t('clockOut', locale)),
          content: DropdownButtonFormField<String>(
            initialValue: employeeId,
            decoration: InputDecoration(labelText: S.t('employee', locale)),
            items: employees
                .map((e) => DropdownMenuItem(
                    value: e['id'] as String,
                    child: Text(
                        '${e['first_name']} ${e['last_name']} · ${e['position']}')))
                .toList(),
            onChanged: (v) => setState(() => employeeId = v),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(S.t('cancel', locale))),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(S.t('confirm', locale))),
          ],
        ),
      ),
    );
    if (confirmed != true || employeeId == null) return;
    await ApiClient.instance.post(
      in_ ? '/attendance/clock-in' : '/attendance/clock-out',
      body: {'employeeId': employeeId},
    );
    if (mounted) {
      _load();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(in_ ? S.t('clockIn', locale) : S.t('clockOut', locale))),
      );
    }
  }

  Future<void> _requestLeave() async {
    final locale = context.read<AuthStore>().locale;
    final employeesResult = await ApiClient.instance.get<Map<String, dynamic>>(
      '/employees',
      query: {'limit': 200},
    );
    if (!mounted) return;
    final employees = (employeesResult.data?['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    if (employees.isEmpty) return;
    String? employeeId;
    String leaveType = 'annual';
    final start = TextEditingController();
    final end = TextEditingController();
    final reason = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(S.t('requestLeave', locale)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: employeeId,
                  decoration:
                      InputDecoration(labelText: S.t('employee', locale)),
                  items: employees
                      .map((e) => DropdownMenuItem(
                          value: e['id'] as String,
                          child: Text('${e['first_name']} ${e['last_name']}')))
                      .toList(),
                  onChanged: (v) => setState(() => employeeId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: leaveType,
                  decoration:
                      InputDecoration(labelText: S.t('leaveType', locale)),
                  items: ['annual', 'sick', 'maternity', 'unpaid', 'other']
                      .map((t) => DropdownMenuItem(
                          value: t, child: Text(S.t(t, locale))))
                      .toList(),
                  onChanged: (v) => setState(() => leaveType = v ?? 'annual'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: start,
                  readOnly: true,
                  decoration: InputDecoration(
                      labelText: S.t('startDate', locale),
                      suffixIcon: const Icon(Icons.event)),
                  onTap: () async {
                    final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2040));
                    if (picked != null) {
                      startDate = picked;
                      start.text = picked.toIso8601String().split('T').first;
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: end,
                  readOnly: true,
                  decoration: InputDecoration(
                      labelText: S.t('endDate', locale),
                      suffixIcon: const Icon(Icons.event)),
                  onTap: () async {
                    final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2040));
                    if (picked != null) {
                      endDate = picked;
                      end.text = picked.toIso8601String().split('T').first;
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: reason,
                    decoration:
                        InputDecoration(labelText: S.t('reason', locale))),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(S.t('cancel', locale))),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(S.t('save', locale))),
          ],
        ),
      ),
    );
    if (saved != true ||
        employeeId == null ||
        startDate == null ||
        endDate == null) {
      return;
    }
    await ApiClient.instance.post('/attendance/leaves', body: {
      'employeeId': employeeId,
      'leaveType': leaveType,
      'startDate': startDate!.toIso8601String().split('T').first,
      'endDate': endDate!.toIso8601String().split('T').first,
      'reason': reason.text.trim().isEmpty ? null : reason.text.trim(),
    });
    if (mounted) _load();
  }

  Future<void> _decideLeave(String id, String decision) async {
    await ApiClient.instance
        .post('/attendance/leaves/$id/decide', body: {'decision': decision});
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return Scaffold(
      appBar: AppBar(
        title: Text(S.t('attendance', locale)),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: S.t('attendance', locale)),
            Tab(text: S.t('leaves', locale)),
            Tab(text: S.t('monthlySummary', locale)),
          ],
        ),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _RecordsTab(
                      records: _records,
                      onClockIn: () => _clock(in_: true),
                      onClockOut: () => _clock(in_: false),
                    ),
                    _LeavesTab(
                        leaves: _leaves,
                        onRequest: _requestLeave,
                        onDecide: _decideLeave),
                    _SummaryTab(rows: _summary),
                  ],
                ),
    );
  }
}

class _RecordsTab extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final VoidCallback onClockIn;
  final VoidCallback onClockOut;

  const _RecordsTab(
      {required this.records,
      required this.onClockIn,
      required this.onClockOut});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onClockIn,
                  icon: const Icon(Icons.login),
                  label: Text(S.t('clockIn', locale)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onClockOut,
                  icon: const Icon(Icons.logout),
                  label: Text(S.t('clockOut', locale)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: records.isEmpty
              ? Center(child: Text(S.t('noAttendance', locale)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: records.length,
                  itemBuilder: (context, i) {
                    final a = records[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassCard(
                        radius: BorderRadius.circular(16),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            StatusChip(
                                label: '${a['status']}',
                                color: statusColor('${a['status']}')),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${a['first_name']} ${a['last_name']}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  Text('${a['position']}',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(Fmt.shortDate(
                                    DateTime.tryParse('${a['date']}'))),
                                Text(
                                  '${a['clock_in'] == null ? '—' : Fmt.time(DateTime.tryParse('${a['clock_in']}'))} → '
                                  '${a['clock_out'] == null ? '—' : Fmt.time(DateTime.tryParse('${a['clock_out']}'))}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _LeavesTab extends StatelessWidget {
  final List<Map<String, dynamic>> leaves;
  final VoidCallback onRequest;
  final Future<void> Function(String id, String decision) onDecide;

  const _LeavesTab(
      {required this.leaves, required this.onRequest, required this.onDecide});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onRequest,
              icon: const Icon(Icons.beach_access),
              label: Text(S.t('requestLeave', locale)),
            ),
          ),
        ),
        Expanded(
          child: leaves.isEmpty
              ? Center(child: Text(S.t('noResults', locale)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: leaves.length,
                  itemBuilder: (context, i) {
                    final l = leaves[i];
                    final isPending = '${l['status']}' == 'pending';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassCard(
                        radius: BorderRadius.circular(16),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                      '${l['first_name']} ${l['last_name']}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                ),
                                StatusChip(
                                    label: '${l['status']}',
                                    color: statusColor('${l['status']}')),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${S.t('${l['leave_type']}', locale)} · '
                              '${l['start_date']?.toString().substring(0, 10)} → '
                              '${l['end_date']?.toString().substring(0, 10)} · '
                              '${l['days']} ${S.t('workingDays', locale)}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                            if (isPending)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () =>
                                        onDecide('${l['id']}', 'rejected'),
                                    child: Text(S.t('rejected', locale),
                                        style: const TextStyle(
                                            color: AppColors.danger)),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        onDecide('${l['id']}', 'approved'),
                                    child: Text(S.t('approved', locale)),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SummaryTab extends StatelessWidget {
  final List<Map<String, dynamic>> rows;

  const _SummaryTab({required this.rows});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    if (rows.isEmpty) return Center(child: Text(S.t('noResults', locale)));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final r = rows[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            radius: BorderRadius.circular(16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${r['first_name']} ${r['last_name']}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        '${S.t('workingDays', locale)}: ${r['working_days'] ?? 0}'),
                    Text(
                        '${S.t('hoursWorked', locale)}: ${r['total_hours'] ?? 0}'),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${S.t('late', locale)}: ${r['late_days'] ?? 0}'),
                    Text('${S.t('absent', locale)}: ${r['absences'] ?? 0}'),
                    Text(
                        '${S.t('overtimeMinutes', locale)}: ${r['total_overtime_minutes'] ?? 0}'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
