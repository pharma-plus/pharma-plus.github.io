import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/api_client.dart';
import '../../core/services/api_list.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/shared/app_search_field.dart';
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
  // Filtre d'état : actifs (défaut) | archivés | tous
  String _statusFilter = 'active';

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
          if (_statusFilter != 'all') 'status': _statusFilter,
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
      builder: (_) => EmployeeForm(employee: employee),
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

  /// Archivage logique / restauration d'un employé (soft-delete).
  Future<void> _setStatus(
      Map<String, dynamic> e, String status, String confirmLabel) async {
    final locale = context.read<AuthStore>().locale;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(confirmLabel),
        content: Text('« ${e['first_name'] ?? ''} ${e['last_name'] ?? ''} ». '
            'L\'historique (ventes, pointages) est conservé.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(S.t('cancel', locale))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(confirmLabel)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final r = await ApiClient.instance
        .patch('/employees/${e['id']}', body: {'status': status});
    if (!mounted) return;
    if (r.success) {
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(status == 'archived'
                ? 'Employé archivé.'
                : 'Employé rétabli comme actif.')));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              r.error?.readableMessage ?? 'Erreur lors de la mise à jour')));
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
            child: AppSearchField(
              controller: _search,
              hint: S.t('search', locale),
              showFilterButton: false,
              debounceDuration: Duration.zero,
              onChanged: (_) => _debouncedLoad(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Actifs'),
                  selected: _statusFilter == 'active',
                  onSelected: (_) => setState(() {
                    _statusFilter = 'active';
                    _load();
                  }),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Archivés'),
                  selected: _statusFilter == 'archived',
                  onSelected: (_) => setState(() {
                    _statusFilter = 'archived';
                    _load();
                  }),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Tous'),
                  selected: _statusFilter == 'all',
                  onSelected: (_) => setState(() {
                    _statusFilter = 'all';
                    _load();
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
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
                                        const SizedBox(width: 4),
                                        PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert,
                                              size: 20),
                                          onSelected: (v) {
                                            if (v == 'archive') {
                                              _setStatus(e, 'archived',
                                                  'Archiver cet employé ?');
                                            } else if (v == 'restore') {
                                              _setStatus(e, 'active',
                                                  'Rétablir cet employé ?');
                                            }
                                          },
                                          itemBuilder: (_) => [
                                            if ('${e['status']}' != 'archived')
                                              const PopupMenuItem(
                                                  value: 'archive',
                                                  child: Text('Archiver')),
                                            if ('${e['status']}' == 'archived')
                                              const PopupMenuItem(
                                                  value: 'restore',
                                                  child: Text('Rétablir')),
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

/// Formulaire employé (création/édition + compte utilisateur lié) —
/// public pour tests widget.
class EmployeeForm extends StatefulWidget {
  final Map<String, dynamic>? employee;

  const EmployeeForm({super.key, this.employee});

  @override
  State<EmployeeForm> createState() => EmployeeFormState();
}

class EmployeeFormState extends State<EmployeeForm> {
  final _formKey = GlobalKey<FormState>();
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

  // ── Option « Créer également un compte utilisateur » (création) ──
  bool _createAccount = false;
  final _accountPass = TextEditingController();
  String? _accountRoleId;
  List<Map<String, dynamic>> _roles = [];

  @override
  void initState() {
    super.initState();
    _contractType = widget.employee?['contract_type'] as String?;
    final hd = widget.employee?['hire_date'];
    if (hd != null) _hireDate = DateTime.tryParse('$hd');
    if (widget.employee == null) _loadRoles();
  }

  Future<void> _loadRoles() async {
    final r = await ApiClient.instance.get('/roles', query: {'limit': 50});
    if (!mounted || !r.success) return;
    final list = ApiList.of(r.data ?? []);
    setState(() {
      _roles = list;
      // Rôle par défaut : caissier/vendeur s'il existe, sinon le premier.
      final preferred = list.firstWhere(
        (x) {
          final n = '${x['name'] ?? ''}'.toLowerCase();
          return n.contains('caiss') || n.contains('vendeur');
        },
        orElse: () => const <String, dynamic>{},
      );
      _accountRoleId = (preferred.isNotEmpty
              ? preferred['id']
              : (list.isNotEmpty ? list.first['id'] : null))
          ?.toString();
    });
  }

  @override
  void dispose() {
    _accountPass.dispose();
    for (final c in [
      _first,
      _last,
      _position,
      _phone,
      _email,
      _cin,
      _salary,
      _cnss,
      _address
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    /* Validation par champ (messages i18n sous champ) avant tout appel
       API — y compris les règles du compte utilisateur optionnel. */
    if (!(_formKey.currentState?.validate() ?? false)) return;
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
      if (_cnss.text.trim().isNotEmpty) 'cnss': _cnss.text.trim(),
      if (_address.text.trim().isNotEmpty) 'address': _address.text.trim(),
      if (_hireDate != null)
        'hireDate': _hireDate!.toIso8601String().substring(0, 10),
    };
    final result = widget.employee == null
        ? await ApiClient.instance.post('/employees', body: body)
        : await ApiClient.instance
            .patch('/employees/${widget.employee!['id']}', body: body);
    if (!mounted) return;
    if (!result.success) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error?.readableMessage ?? 'Erreur')),
      );
      return;
    }
    // Option « Créer également un compte utilisateur » (creation seule) :
    // on rattache ensuite le compte a l'employe via employees.user_id.
    String? accountMsg;
    if (widget.employee == null && _createAccount) {
      accountMsg = await _createLinkedAccount(result);
      if (!mounted) return;
    }
    if (accountMsg != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(accountMsg)));
    }
    Navigator.pop(context, true);
  }

  /// Crée le compte utilisateur (POST /users + employee_id) puis laisse
  /// l'employé créer l'association. En cas d'échec, l'employé reste créé
  /// (message d'avertissement affiché par l'appelant).
  Future<String?> _createLinkedAccount(ApiResult<dynamic> empRes) async {
    final empData = resultDataRow(empRes);
    final empId = empData?['id']?.toString();
    if (empId == null) {
      return 'Employé créé — compte utilisateur non créé (id employé absent).';
    }
    final ures = await ApiClient.instance.post('/users', body: {
      'first_name': _first.text.trim(),
      'last_name': _last.text.trim(),
      'email': _email.text.trim(),
      'password': _accountPass.text,
      'role_id': _accountRoleId,
      'employee_id': empId,
    });
    if (ures.success) {
      return 'Employé et compte utilisateur créés (login : ${_email.text.trim()}).';
    }
    return 'Employé créé — compte utilisateur NON créé : ${ures.error?.readableMessage ?? 'erreur'}';
  }

  /// Extrait la ligne créée d'une réponse PostgREST brute (liste) ou wrappée.
  Map<String, dynamic>? resultDataRow(ApiResult<dynamic>? res) {
    final d = res?.data;
    if (d is List && d.isNotEmpty && d.first is Map) {
      return Map<String, dynamic>.from(d.first as Map);
    }
    if (d is Map) return Map<String, dynamic>.from(d);
    return null;
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
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.employee == null
                        ? 'Nouvel employé'
                        : 'Modifier l\'employé',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.pharmaText),
                  ),
                  const SizedBox(height: 16),
                  _row2(
                    TextFormField(
                        controller: _first,
                        textInputAction: TextInputAction.next,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: InputDecoration(
                            labelText: S.t('firstName', locale)),
                        validator: (v) =>
                            validateRequired(v, S.t('requiredField', locale))),
                    TextFormField(
                        controller: _last,
                        textInputAction: TextInputAction.next,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration:
                            InputDecoration(labelText: S.t('lastName', locale)),
                        validator: (v) =>
                            validateRequired(v, S.t('requiredField', locale))),
                    wide,
                  ),
                  const SizedBox(height: 12),
                  _row2(
                    TextFormField(
                        controller: _position,
                        textInputAction: TextInputAction.next,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration:
                            InputDecoration(labelText: S.t('position', locale)),
                        validator: (v) =>
                            validateRequired(v, S.t('requiredField', locale))),
                    TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration:
                            InputDecoration(labelText: S.t('phone', locale)),
                        validator: (v) =>
                            validatePhone(v, S.t('invalidPhone', locale))),
                    wide,
                  ),
                  const SizedBox(height: 12),
                  _row2(
                    TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration:
                            InputDecoration(labelText: S.t('email', locale)),
                        validator: (v) {
                          if (widget.employee == null && _createAccount) {
                            return validateRequired(
                                v, S.t('requiredField', locale));
                          }
                          return validateEmail(v, S.t('invalidEmail', locale));
                        }),
                    TextField(
                        controller: _cin,
                        decoration:
                            InputDecoration(labelText: S.t('cin', locale))),
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
                            InputDecoration(labelText: S.t('address', locale))),
                    wide,
                  ),
                  const SizedBox(height: 12),
                  _row2(
                    TextFormField(
                        controller: _salary,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration:
                            InputDecoration(labelText: S.t('salary', locale)),
                        validator: (v) => validateNonNegativeNumber(
                            v, S.t('invalidNumber', locale))),
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
                  if (widget.employee == null) ...[
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      value: _createAccount,
                      onChanged: (v) =>
                          setState(() => _createAccount = v ?? false),
                      title:
                          const Text('Créer également un compte utilisateur'),
                      subtitle: const Text(
                          'Login : email ci-dessus · PIN à définir après la création',
                          style: TextStyle(fontSize: 12)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    if (_createAccount) ...[
                      const SizedBox(height: 8),
                      _row2(
                        TextFormField(
                          controller: _accountPass,
                          obscureText: true,
                          textInputAction: TextInputAction.next,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          decoration: const InputDecoration(
                              labelText: 'Mot de passe du compte (min. 8)'),
                          validator: (v) {
                            if (!_createAccount) return null;
                            if (v == null || v.trim().isEmpty) {
                              return S.t('requiredField', locale);
                            }
                            if (v.trim().length < 8) {
                              return S.t('passwordMin8', locale);
                            }
                            return null;
                          },
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: _accountRoleId,
                          decoration: const InputDecoration(
                              labelText: 'Rôle du compte'),
                          validator: (v) => (_createAccount && v == null)
                              ? S.t('requiredField', locale)
                              : null,
                          items: _roles
                              .map((r) => DropdownMenuItem(
                                  value: '${r['id']}',
                                  child: Text('${r['name']}')))
                              .toList(),
                          onChanged: (v) => setState(() => _accountRoleId = v),
                        ),
                        wide,
                      ),
                    ],
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
    final result =
        await ApiClient.instance.get('/employees/${widget.employeeId}');
    if (!mounted) return;
    if (result.success) {
      final d = result.data;
      setState(() => _employee = d is Map<String, dynamic>
          ? d
          : (d is Map ? Map<String, dynamic>.from(d) : null));
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
