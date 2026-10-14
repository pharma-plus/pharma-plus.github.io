import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/api_client.dart';
import '../../core/services/api_list.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/status_chip.dart';
import '../shell/shell_nav.dart';

/// Employés : effectif, fiches, contrats, primes et évaluations.
class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key});

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  final _search = TextEditingController();
  Timer? _debounce;
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
      ApiClient.instance.get(
        '/employees',
        query: {
          'limit': 100,
          if (_search.text.trim().isNotEmpty) 'q': _search.text.trim(),
        },
      ),
      ApiClient.instance.get('/employees/summary'),
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
      _items = ApiList.of(list.data);
      final sd = summary.data;
      _summary = summary.success && sd is Map
          ? (sd is Map<String, dynamic> ? sd : Map<String, dynamic>.from(sd))
          : null;
      _loading = false;
    });
  }

  void _debouncedLoad() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const ShellBackButton(),
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
              onChanged: (_) => _debouncedLoad(),
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
              ? AppColors.brandGold.withValues(alpha: 0.30)
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
  late final _cnss =
      TextEditingController(text: '${widget.employee?['cnss'] ?? ''}');
  late final _address =
      TextEditingController(text: '${widget.employee?['address'] ?? ''}');
  String? _contractType;
  DateTime? _hireDate;
  bool _saving = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _contractType = widget.employee?['contract_type'] as String?;
    final hd = widget.employee?['hire_date'];
    if (hd != null) _hireDate = DateTime.tryParse('$hd');
  }

  @override
  void dispose() {
    for (final c in [_first, _last, _position, _phone, _email, _cin, _salary, _cnss, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_first.text.trim().isEmpty ||
        _last.text.trim().isEmpty ||
        _position.text.trim().isEmpty) {
      setState(() =>
          _validationError = 'Prénom, nom et fonction sont obligatoires.');
      return;
    }
    setState(() {
      _saving = true;
      _validationError = null;
    });
    final body = {
      'firstName': _first.text.trim(),
      'lastName': _last.text.trim(),
      'position': _position.text.trim(),
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
      'cin': _cin.text.trim().isEmpty ? null : _cin.text.trim(),
      'salary': double.tryParse(_salary.text) ?? 0,
      'contractType': _contractType,
      if (_cnss.text.trim().isNotEmpty) 'cnss': _cnss.text.trim(),
      if (_address.text.trim().isNotEmpty) 'address': _address.text.trim(),
      if (_hireDate != null)
        'hireDate': _hireDate!.toIso8601String().substring(0, 10),
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

  /// Construit une rangée de 2 champs côte à côte (PC) ou empilés (mobile).
  Widget _row2(Widget a, Widget b, bool wide) {
    if (!wide) {
      return Column(children: [a, const SizedBox(height: 12), b]);
    }
    return Row(children: [
      Expanded(child: a),
      const SizedBox(width: 12),
      Expanded(child: b),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    final wide = MediaQuery.of(context).size.width >= 700;
    return Dialog(
      backgroundColor: AppColors.pharmaSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.employee == null ? 'Nouvel employé' : 'Modifier l\'employé',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.pharmaText),
                ),
                const SizedBox(height: 16),
                _row2(
                  TextField(
                      controller: _first,
                      decoration: InputDecoration(
                          labelText: S.t('firstName', locale))),
                  TextField(
                      controller: _last,
                      decoration: InputDecoration(
                          labelText: S.t('lastName', locale))),
                  wide,
                ),
                const SizedBox(height: 12),
                _row2(
                  TextField(
                      controller: _position,
                      decoration: InputDecoration(
                          labelText: S.t('position', locale))),
                  TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration:
                          InputDecoration(labelText: S.t('phone', locale))),
                  wide,
                ),
                const SizedBox(height: 12),
                _row2(
                  TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration:
                          InputDecoration(labelText: S.t('email', locale))),
                  TextField(
                      controller: _cin,
                      decoration: InputDecoration(labelText: S.t('cin', locale))),
                  wide,
                ),
                const SizedBox(height: 12),
                _row2(
                  TextField(
                      controller: _cnss,
                      decoration: const InputDecoration(labelText: 'CNSS')),
                  TextField(
                      controller: _address,
                      decoration:
                          const InputDecoration(labelText: 'Adresse')),
                  wide,
                ),
                const SizedBox(height: 12),
                _row2(
                  TextField(
                      controller: _salary,
                      keyboardType: TextInputType.number,
                      decoration:
                          InputDecoration(labelText: S.t('salary', locale))),
                  DropdownButtonFormField<String>(
                    initialValue: _contractType,
                    decoration: InputDecoration(
                        labelText: S.t('contractType', locale)),
                    items: ['cdi', 'cdd', 'stage', 'interim']
                        .map((c) => DropdownMenuItem(
                            value: c, child: Text(S.t(c, locale))))
                        .toList(),
                    onChanged: (v) => setState(() => _contractType = v),
                  ),
                  wide,
                ),
                const SizedBox(height: 12),
                // Date d'embauche
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _hireDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setState(() => _hireDate = d);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                        labelText: 'Date d\'embauche',
                        suffixIcon: Icon(Icons.calendar_today, size: 18)),
                    child: Text(
                      _hireDate != null
                          ? '${_hireDate!.day.toString().padLeft(2, '0')}/${_hireDate!.month.toString().padLeft(2, '0')}/${_hireDate!.year}'
                          : 'Sélectionner une date',
                      style: TextStyle(
                        color: _hireDate != null
                            ? AppColors.pharmaText
                            : AppColors.pharmaMuted,
                      ),
                    ),
                  ),
                ),
                if (_validationError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _validationError!,
                    style: const TextStyle(color: AppColors.danger, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: Text(S.t('cancel', locale)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GradientButton(
                      label: S.t('save', locale),
                      icon: Icons.check,
                      loading: _saving,
                      onPressed: _save,
                    ),
                  ),
                ]),
              ],
            ),
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
        .get('/employees/${widget.employeeId}');
    if (!mounted) return;
    if (result.success) {
      final d = result.data;
      setState(() => _employee = d is Map<String, dynamic> ? d : (d is Map ? Map<String, dynamic>.from(d) : null));
    }
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
