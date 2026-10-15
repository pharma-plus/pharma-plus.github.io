import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/api_client.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/services/api_list.dart';

/// Page interface pour le rôle Médecin (5 permissions limitées).
class DoctorPage extends StatefulWidget {
  const DoctorPage({super.key});

  @override
  State<DoctorPage> createState() => _DoctorPageState();
}

class _DoctorPageState extends State<DoctorPage> {
  late List<Map<String, dynamic>> _medications;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMedications();
  }

  Future<void> _loadMedications(
      {String? dci, String? laboratory, String? q}) async {
    setState(() => _loading = true);
    try {
      final params = <String, String>{};
      if (dci != null && dci.isNotEmpty) params['dci'] = dci;
      if (laboratory != null && laboratory.isNotEmpty) params['laboratory'] = laboratory;
      if (q != null && q.isNotEmpty) params['q'] = q;

      final result = await ApiClient.instance.get(
        '/medications',
        query: params.isEmpty ? null : params,
      );
      if (!mounted) return;
      if (!result.success) {
        setState(() {
          _error = result.error?.message;
          _loading = false;
        });
        return;
      }
      setState(() {
        _medications = ApiList.of(result.data ?? []);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _showMedicationDetail(Map<String, dynamic> med) async {
    // Ouvrir le détail d'un médicament (mode lecture seule pour le médecin)
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('${med['name'] ?? 'Médicament'}'),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.medication_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${med['name'] ?? 'Non renseigné'}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'DCI : ${med['dci'] ?? 'Non renseigné'}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Laboratoire : ${med['laboratory'] ?? 'Non renseigné'}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Dosage : ${med['dosage'] ?? 'Non renseigné'}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Forme : ${med['form'] ?? 'Non renseigné'}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Prix : ${double.tryParse(med['price']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0'} MAD',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(S.t('fermer', context.read<AuthStore>().locale)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Dialogue de recherche (nom, DCI, substance, dosage, forme, labo, EAN).
  Future<void> _openSearch() async {
    final ctrl = TextEditingController();
    final q = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechercher un médicament'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Nom, DCI, substance, dosage, forme, labo, EAN…',
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Rechercher')),
        ],
      ),
    );
    ctrl.dispose();
    if (q == null) return;
    if (q.isEmpty) {
      await _loadMedications();
    } else {
      await _loadMedications(q: q);
      if (mounted && _medications.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Aucun résultat pour « $q ».')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    final user = context.watch<AuthStore>().user;
    final hasViewPermission = user?.hasPermission('catalog:view') ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(S.t('medecin_titre', locale)),
        actions: [
          if (hasViewPermission)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _openSearch,
            ),
        ],
      ),
      body: _buildBody(user, hasViewPermission, locale),
    );
  }

  Widget _buildBody(dynamic user, bool hasViewPermission, String locale) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_medications.isEmpty) {
      return Center(child: Text(S.t('noMedications', locale)));
    }

    return RefreshIndicator(
      onRefresh: () => _loadMedications(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _medications.length,
        itemBuilder: (context, index) {
          final m = _medications[index];
          return GlassCard(
            radius: BorderRadius.circular(16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onTap: () => _showMedicationDetail(m),
            child: Row(
              children: [
                // Icône médicament
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.medication,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${m['name'] ?? 'Non nommé'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'DCI : ${m['dci'] ?? 'Non renseigné'}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        'Laboratoire : ${m['laboratory'] ?? 'Non renseigné'}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      if (m['presentation'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Présentation : ${m['presentation']}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ),
                // Indicateur "Non disponible"
                if (m['name'] == null || m['name'] == '')
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.remove_circle_outline,
                      color: Colors.red,
                      size: 16,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}