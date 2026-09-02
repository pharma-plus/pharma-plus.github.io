import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/api_client.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/status_chip.dart';

/// Employés : effectif, fiches, contrats, primes et évaluations.
class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key});

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _summary;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final results = await Future.wait([
      ApiClient.instance.get<Map<String, dynamic>>(
        '/employees',
        query: {
          'limit': 100,
          if (_search.text.trim().isNotEmpty) 'q': _search.text.trim(),
        },
      ),
      ApiClient.instance.get<Map<String, dynamic>>('/employees/summary'),
    ]);
    if (!mounted) return;
    final list = results[0];
    final summary = results[1];
    if (!list.success) {
      setState(() {
        _loading = false;
        _error = list.error?.message;
      });
      return;
    }
    setState(() {
      _items = (list.data?['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      _summary = summary.success ? summary.data : null;
      _loading = false;
    });
  }

  Future<void> _edit(Map<String, dynamic>? employee) async {
    final locale = context.read<AuthStore>().locale;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EmployeeForm(employee: employee),
    );
    if (saved == true) {
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.t('employeeCreated', locale))),
        );
      }
    }
  }

  void _showDetail(Map<String, dynamic> employee) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EmployeeDetail(
          employeeId: employee['id'] as String,
          onEdit: () {
            Navigator.pop(context);
            _edit(employee);
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    final s = _summary;
    return Scaffold(
      appBar: AppBar(
        title: Text(S.t('employees', locale)),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(null),
        icon: const Icon(Icons.person_add_alt),
        label: Text(S.t('newEmployee', locale)),
      ),
      body: Column(
        children: [
          if (s != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: StatsChip(
                        icon: Icons.groups,
                        label: S.t('activeCount', locale),
                        value: Fmt.number(
                            (s['active_count'] as num?)?.toDouble() ?? 0)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatsChip(
                        icon: Icons.badge_outlined,
                        label: S.t('totalEmployees', locale),
                        value: Fmt.number(
                            (s['total_count'] as num?)?.toDouble() ?? 0)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatsChip(
                        icon: Icons.payments_outlined,
                        label: S.t('monthlyMass', locale),
                        value: Fmt.money(
                            (s['monthly_mass'] as num?)?.toDouble() ?? 0)),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              onChanged: (_) => _load(),
              decoration: InputDecoration(
                hintText: S.t('search', locale),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _items.isEmpty
                        ? Center(child: Text(S.t('noEmployees', locale)))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                              itemCount: _items.length,
                              itemBuilder: (context, i) {
                                final e = _items[i];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: GlassCard(
                                    radius: BorderRadius.circular(16),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    onTap: () => _showDetail(e),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundColor: AppColors.primary
                                              .withValues(alpha: 0.1),
                                          child: Text(
                                            '${e['first_name'] ?? ''}'
                                                    .isNotEmpty
                                                ? '${e['first_name']}'[0]
                                                    .toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.primary),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                  '${e['first_name'] ?? ''} ${e['last_name'] ?? ''}',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700)),
                                              Text('${e['position'] ?? ''}',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey)),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            StatusChip(
                                              label: '${e['status']}',
                                              color:
                                                  statusColor('${e['status']}'),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                                Fmt.money((e['salary'] as num?)
                                                        ?.toDouble() ??
                                                    0),
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 13)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class StatsChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const StatsChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.surfaceDark
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.dividerDark
              : Colors.white,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeForm extends StatefulWidget {
  final Map<String, dynamic>? employee;

  const _EmployeeForm({this.employee});

  @override
  State<_EmployeeForm> createState() => _EmployeeFormState();
}

class _EmployeeFormState extends State<_EmployeeForm> {
  late final _first =
      TextEditingController(text: '${widget.employee?['first_name'] ?? ''}');
  late final _last =
      TextEditingController(text: '${widget.employee?['last_name'] ?? ''}');
  late final _position =
      TextEditingController(text: '${widget.employee?['position'] ?? ''}');
  late final _phone =
      TextEditingController(text: '${widget.employee?['phone'] ?? ''}');
  late final _email =
      TextEditingController(text: '${widget.employee?['email'] ?? ''}');
  late final _cin =
      TextEditingController(text: '${widget.employee?['cin'] ?? ''}');
  late final _salary =
      TextEditingController(text: '${widget.employee?['salary'] ?? 0}');
  String? _contractType;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _contractType = widget.employee?['contract_type'] as String?;
  }

  @override
  void dispose() {
    for (final c in [_first, _last, _position, _phone, _email, _cin, _salary]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_first.text.trim().isEmpty ||
        _last.text.trim().isEmpty ||
        _position.text.trim().isEmpty) {
      return;
    }
    setState(() => _saving = true);
    final body = {
      'firstName': _first.text.trim(),
      'lastName': _last.text.trim(),
      'position': _position.text.trim(),
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
      'cin': _cin.text.trim().isEmpty ? null : _cin.text.trim(),
      'salary': double.tryParse(_salary.text) ?? 0,
      'contractType': _contractType,
    };
    final result = widget.employee == null
        ? await ApiClient.instance.post('/employees', body: body)
        : await ApiClient.instance
            .put('/employees/${widget.employee!['id']}', body: body);
    if (!mounted) return;
    if (result.success) {
      Navigator.pop(context, true);
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error?.readableMessage ?? 'Erreur')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  widget.employee == null
                      ? S.t('newEmployee', locale)
                      : '${widget.employee!['first_name']} ${widget.employee!['last_name']}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                        controller: _first,
                        decoration: InputDecoration(
                            labelText: S.t('firstName', locale))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                        controller: _last,
                        decoration: InputDecoration(
                            labelText: S.t('lastName', locale))),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: _position,
                  decoration:
                      InputDecoration(labelText: S.t('position', locale))),
              const SizedBox(height: 12),
              TextField(
                  controller: _phone,
                  decoration: InputDecoration(labelText: S.t('phone', locale))),
              const SizedBox(height: 12),
              TextField(
                  controller: _email,
                  decoration: InputDecoration(labelText: S.t('email', locale))),
              const SizedBox(height: 12),
              TextField(
                  controller: _cin,
                  decoration: InputDecoration(labelText: S.t('cin', locale))),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                        controller: _salary,
                        keyboardType: TextInputType.number,
                        decoration:
                            InputDecoration(labelText: S.t('salary', locale))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _contractType,
                      decoration: InputDecoration(
                          labelText: S.t('contractType', locale)),
                      items: ['cdi', 'cdd', 'stage', 'interim']
                          .map((c) => DropdownMenuItem(
                              value: c, child: Text(S.t(c, locale))))
                          .toList(),
                      onChanged: (v) => setState(() => _contractType = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GradientButton(
                label: S.t('save', locale),
                icon: Icons.check,
                loading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmployeeDetail extends StatefulWidget {
  final String employeeId;
  final VoidCallback onEdit;

  const _EmployeeDetail({required this.employeeId, required this.onEdit});

  @override
  State<_EmployeeDetail> createState() => _EmployeeDetailState();
}

class _EmployeeDetailState extends State<_EmployeeDetail> {
  Map<String, dynamic>? _employee;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await ApiClient.instance
        .get<Map<String, dynamic>>('/employees/${widget.employeeId}');
    if (!mounted) return;
    if (result.success) setState(() => _employee = result.data);
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    final e = _employee;
    if (e == null) {
      return const SafeArea(
          child: Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      ));
    }
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${e['first_name']} ${e['last_name']}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit_outlined)),
              ],
            ),
            row(S.t('position', locale), '${e['position'] ?? '—'}'),
            row(S.t('branch', locale), '${e['branch_name'] ?? '—'}'),
            row(S.t('phone', locale), '${e['phone'] ?? '—'}'),
            row(S.t('email', locale), '${e['email'] ?? '—'}'),
            row(S.t('cin', locale), '${e['cin'] ?? '—'}'),
            row(S.t('salary', locale),
                Fmt.money((e['salary'] as num?)?.toDouble() ?? 0)),
            row(
                S.t('contractType', locale),
                e['contract_type'] != null
                    ? S.t('${e['contract_type']}', locale)
                    : '—'),
            const Divider(height: 24),
            if ((e['bonuses'] as List? ?? const []).isNotEmpty) ...[
              Text(S.t('bonuses', locale),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              for (final b in e['bonuses'] as List? ?? const [])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading:
                      const Icon(Icons.card_giftcard, color: AppColors.accent),
                  title: Text('${b['reason'] ?? '—'}'),
                  subtitle: Text(
                      Fmt.shortDate(DateTime.tryParse('${b['bonus_date']}'))),
                  trailing: Text(
                      Fmt.money((b['amount'] as num?)?.toDouble() ?? 0),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
            ],
            if ((e['evaluations'] as List? ?? const []).isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(S.t('evaluations', locale),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              for (final ev in e['evaluations'] as List? ?? const [])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.star, color: AppColors.accent),
                  title: Text('${ev['score']}/5 · ${ev['comments'] ?? ''}'),
                ),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: (e['attendance'] as List? ?? const []).isEmpty
                  ? Center(child: Text(S.t('noAttendance', locale)))
                  : ListView(
                      children: [
                        for (final a in e['attendance'] as List? ?? const [])
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: StatusChip(
                                label: '${a['status']}',
                                color: statusColor('${a['status']}')),
                            title: Text(Fmt.shortDate(
                                DateTime.tryParse('${a['date']}'))),
                            trailing: Text(
                                '${S.t('hoursWorked', locale)}: ${a['hours_worked'] ?? 0}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
