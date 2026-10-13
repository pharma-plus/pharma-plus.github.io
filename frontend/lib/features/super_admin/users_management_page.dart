import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/api_client.dart';
import '../../core/services/api_list.dart';
import '../../core/services/auth_store.dart';

/// Page de gestion des utilisateurs (super-admin)
class UsersManagementPage extends StatefulWidget {
  const UsersManagementPage({super.key});

  @override
  State<UsersManagementPage> createState() => _UsersManagementState();
}

class _UsersManagementState extends State<UsersManagementPage> {
  late List<Map<String, dynamic>> _users;
  bool _loading = true;
  String? _error;
  String? _filterStatus;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final result = await ApiClient.instance.get(
        '/users',
        query: {
          'limit': 100,
          if (_filterStatus != null) 'status': _filterStatus,
        },
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
        _users = ApiList.of(result.data ?? []);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    final user = context.watch<AuthStore>().user;

    return Scaffold(
      appBar: AppBar(
        title: Text(S.t('gestion_utilisateurs', locale)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: Ouvrir le formulaire d'ajout d'utilisateur
            },
          ),
        ],
      ),
      body: _buildBody(user),
    );
  }

  Widget _buildBody(dynamic user) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_users.isEmpty) {
      return const Center(child: Text('Aucun utilisateur trouvé'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final u = _users[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            title: Text(u['name']?.toString() ?? 'Non nommé'),
            subtitle: Text('Role: ${u['role']?.toString() ?? 'Non défini'}'),
            trailing: PopupMenuButton<String>(
              onSelected: (String value) {
                // TODO: Gérer les actions (modifier, supprimer)
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<String>(
                  value: 'modifier',
                  child: Text('Modifier'),
                ),
                const PopupMenuItem<String>(
                  value: 'supprimer',
                  child: Text('Supprimer'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
