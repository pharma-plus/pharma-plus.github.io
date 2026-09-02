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

/// Ordonnances : saisie, suivi et délivrance.
class PrescriptionsPage extends StatefulWidget {
  const PrescriptionsPage({super.key});

  @override
  State<PrescriptionsPage> createState() => _PrescriptionsPageState();
}

class _PrescriptionsPageState extends State<PrescriptionsPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String? _statusFilter;

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
    final result = await ApiClient.instance.get<Map<String, dynamic>>(
      '/prescriptions',
      query: {
        'limit': 100,
        if (_statusFilter != null) 'status': _statusFilter,
      },
    );
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _loading = false;
        _error = result.error?.message;
      });
      return;
    }
    setState(() {
      _items = (result.data?['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      _loading = false;
    });
  }

  Future<void> _create() async {
    final locale = context.read<AuthStore>().locale;
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _PrescriptionForm(),
    );
    if (created == true) {
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.t('prescriptionCreated', locale))),
        );
      }
    }
  }

  void _showDetail(Map<String, dynamic> p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PrescriptionDetail(
          prescriptionId: p['id'] as String, onChanged: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    const statuses = [
      'received',
      'processing',
      'filled',
      'rejected',
      'archived'
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(S.t('prescriptions', locale)),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.note_add_outlined),
        label: Text(S.t('newPrescription', locale)),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                ChoiceChip(
                  label: Text(S.t('all', locale)),
                  selected: _statusFilter == null,
                  onSelected: (_) => setState(() {
                    _statusFilter = null;
                    _load();
                  }),
                ),
                for (final s in statuses)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      label: Text(s),
                      selected: _statusFilter == s,
                      onSelected: (_) => setState(() {
                        _statusFilter = s;
                        _load();
                      }),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _items.isEmpty
                        ? Center(child: Text(S.t('noPrescriptions', locale)))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                              itemCount: _items.length,
                              itemBuilder: (context, i) {
                                final p = _items[i];
                                final pending =
                                    (p['pending_items'] as num?)?.toInt() ?? 0;
                                final patient = '${p['patient_name'] ?? ''}'
                                        .isNotEmpty
                                    ? '${p['patient_name']}'
                                    : [p['customer_first'], p['customer_last']]
                                        .whereType<String>()
                                        .where((s) => s.isNotEmpty)
                                        .join(' ');
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: GlassCard(
                                    radius: BorderRadius.circular(16),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    onTap: () => _showDetail(p),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            gradient: AppColors.greenGradient,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                              Icons.description_outlined,
                                              color: Colors.white),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                  patient.isEmpty
                                                      ? '—'
                                                      : patient,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700)),
                                              Text(
                                                [
                                                  p['doctor_name'],
                                                  '${p['source']}'
                                                ]
                                                    .whereType<String>()
                                                    .where((s) => s.isNotEmpty)
                                                    .join(' · '),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            StatusChip(
                                              label: '${p['status']}',
                                              color:
                                                  statusColor('${p['status']}'),
                                            ),
                                            if (pending > 0)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 4),
                                                child: Text(
                                                  '${S.t('pendingItems', locale)}: $pending',
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: AppColors.warning),
                                                ),
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
          ),
        ],
      ),
    );
  }
}

class _PrescriptionForm extends StatefulWidget {
  const _PrescriptionForm();

  @override
  State<_PrescriptionForm> createState() => _PrescriptionFormState();
}

class _PrescriptionFormState extends State<_PrescriptionForm> {
  final _patient = TextEditingController();
  final _doctor = TextEditingController();
  final _notes = TextEditingController();
  List<Map<String, dynamic>> _medications = [];
  final List<_RxLine> _lines = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await ApiClient.instance.get<Map<String, dynamic>>(
      '/catalog/medications',
      query: {'limit': 200, 'status': 'available'},
    );
    if (!mounted) return;
    setState(() {
      _medications = (result.data?['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      _loading = false;
    });
  }

  Future<void> _save() async {
    final patient = _patient.text.trim();
    if (patient.isEmpty || _lines.isEmpty) return;
    setState(() => _saving = true);
    final result = await ApiClient.instance.post(
      '/prescriptions',
      body: {
        'patientName': patient,
        'doctorName': _doctor.text.trim().isEmpty ? null : _doctor.text.trim(),
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        'source': 'manual',
        'items': _lines
            .map((l) => {
                  'medicationId': l.medicationId,
                  'dosage': l.dosage,
                  'frequency': l.frequency,
                  'duration': l.duration,
                  'quantity': l.quantity,
                })
            .toList(),
      },
    );
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
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(S.t('newPrescription', locale),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _patient,
                      decoration: InputDecoration(
                          labelText: S.t('patientName', locale)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _doctor,
                      decoration:
                          InputDecoration(labelText: S.t('doctorName', locale)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notes,
                      maxLines: 2,
                      decoration:
                          InputDecoration(labelText: S.t('notes', locale)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(S.t('itemsRequired', locale),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => _lines.add(_RxLine())),
                          icon: const Icon(Icons.add),
                          label: Text(S.t('addItem', locale)),
                        ),
                      ],
                    ),
                    for (var i = 0; i < _lines.length; i++)
                      _RxLineEditor(
                        key: ValueKey(i),
                        medications: _medications,
                        line: _lines[i],
                        onChanged: () => setState(() {}),
                        onRemove: () => setState(() => _lines.removeAt(i)),
                      ),
                    const SizedBox(height: 20),
                    GradientButton(
                      label: S.t('create', locale),
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

class _RxLine {
  String? medicationId;
  String dosage = '';
  String frequency = '';
  String duration = '';
  double quantity = 1;
}

class _RxLineEditor extends StatelessWidget {
  final List<Map<String, dynamic>> medications;
  final _RxLine line;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _RxLineEditor({
    super.key,
    required this.medications,
    required this.line,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: line.medicationId,
                  isExpanded: true,
                  decoration: InputDecoration(
                      labelText: S.t('selectMedication', locale)),
                  items: medications
                      .map((m) => DropdownMenuItem(
                          value: m['id'] as String,
                          child: Text('${m['name']}',
                              overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) {
                    line.medicationId = v;
                    onChanged();
                  },
                ),
              ),
              IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close, color: AppColors.danger)),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: line.dosage,
                  decoration: InputDecoration(labelText: S.t('dosage', locale)),
                  onChanged: (v) => line.dosage = v,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: line.frequency,
                  decoration:
                      InputDecoration(labelText: S.t('frequency', locale)),
                  onChanged: (v) => line.frequency = v,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: line.duration,
                  decoration:
                      InputDecoration(labelText: S.t('duration', locale)),
                  onChanged: (v) => line.duration = v,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: '${line.quantity}',
                  keyboardType: TextInputType.number,
                  decoration:
                      InputDecoration(labelText: S.t('quantity', locale)),
                  onChanged: (v) => line.quantity = double.tryParse(v) ?? 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrescriptionDetail extends StatefulWidget {
  final String prescriptionId;
  final VoidCallback onChanged;

  const _PrescriptionDetail(
      {required this.prescriptionId, required this.onChanged});

  @override
  State<_PrescriptionDetail> createState() => _PrescriptionDetailState();
}

class _PrescriptionDetailState extends State<_PrescriptionDetail> {
  Map<String, dynamic>? _prescription;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await ApiClient.instance
        .get<Map<String, dynamic>>('/prescriptions/${widget.prescriptionId}');
    if (!mounted) return;
    if (result.success) {
      setState(() => _prescription = result.data);
    } else {
      setState(() => _error = result.error?.message);
    }
  }

  Future<void> _setStatus(String status) async {
    final result = await ApiClient.instance.post(
      '/prescriptions/${widget.prescriptionId}/status',
      body: {'status': status},
    );
    if (!mounted) return;
    if (result.success) {
      widget.onChanged();
      _load();
    }
  }

  Future<void> _dispense() async {
    final result = await ApiClient.instance
        .post('/prescriptions/${widget.prescriptionId}/dispense', body: {});
    if (!mounted) return;
    if (result.success) {
      widget.onChanged();
      _load();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(S.t('dispensedAll', context.read<AuthStore>().locale))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    if (_error != null) {
      return SafeArea(
          child:
              Padding(padding: const EdgeInsets.all(24), child: Text(_error!)));
    }
    final p = _prescription;
    if (p == null) {
      return const SafeArea(
          child: Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      ));
    }
    final pending = (p['items'] as List? ?? const [])
        .where((i) => (i as Map)['is_dispensed'] == false)
        .length;
    final patient = '${p['patient_name'] ?? ''}'.isNotEmpty
        ? '${p['patient_name']}'
        : [p['customer_first'], p['customer_last']]
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .join(' ');
    final editable = !['filled', 'archived'].contains('${p['status']}');
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(patient.isEmpty ? '—' : patient,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                StatusChip(
                    label: '${p['status']}',
                    color: statusColor('${p['status']}')),
              ],
            ),
            const SizedBox(height: 6),
            Text('${S.t('doctorName', locale)}: ${p['doctor_name'] ?? '—'}',
                style: const TextStyle(color: Colors.grey)),
            Text(Fmt.dateTime(DateTime.tryParse('${p['created_at']}')),
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  for (final item in p['items'] as List? ?? const [])
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(
                          item['is_dispensed'] == true
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: item['is_dispensed'] == true
                              ? AppColors.success
                              : AppColors.warning),
                      title: Text(
                          '${item['medication_name'] ?? S.t('medicationName', locale)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        [item['dosage'], item['frequency'], item['duration']]
                            .whereType<String>()
                            .where((s) => s.isNotEmpty)
                            .join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                          '× ${Fmt.number(double.tryParse('${item['quantity']}') ?? 0)}'),
                    ),
                  const SizedBox(height: 12),
                  if (pending > 0 && editable)
                    GradientButton(
                      label: '${S.t('dispense', locale)} ($pending)',
                      icon: Icons.local_pharmacy,
                      onPressed: _dispense,
                    ),
                  const SizedBox(height: 8),
                  if (editable)
                    Row(
                      children: [
                        for (final s in ['processing', 'rejected'])
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: OutlinedButton(
                                onPressed: () => _setStatus(s),
                                child: Text(
                                    s == 'processing'
                                        ? S.t('processing', locale)
                                        : S.t('rejected', locale),
                                    style: TextStyle(
                                        color: s == 'rejected'
                                            ? AppColors.danger
                                            : AppColors.warning)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  if (!editable)
                    Center(
                      child: TextButton(
                        onPressed: () => _setStatus('archived'),
                        child: Text(S.t('archived', locale)),
                      ),
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
