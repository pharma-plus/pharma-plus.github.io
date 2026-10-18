import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/models/user.dart';
import '../../core/services/api_client.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';

/// Écran de verrouillage de l'application
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  String? _error;
  bool _verifying = false;
  bool _pinNotSet = false;
  String _newPin = '';
  String _confirmPin = '';
  int _setupStep = 0; // 0=verify, 1=enter new, 2=confirm
  // Mode « Changer d'utilisateur » : le prochain employé s'identifie
  // par identifiant + PIN propre (caisse partagée).
  bool _switchMode = false;
  final TextEditingController _identCtrl = TextEditingController();

  static const int _pinLength = 4;

  @override
  void dispose() {
    _identCtrl.dispose();
    super.dispose();
  }

  void _addDigit(String digit) {
    if (_verifying) return;
    setState(() {
      _error = null;
      if (_setupStep == 0) {
        if (_pin.length < _pinLength) {
          _pin += digit;
          if (_pin.length == _pinLength) _autoVerify();
        }
      } else if (_setupStep == 1) {
        if (_newPin.length < _pinLength) _newPin += digit;
      } else if (_setupStep == 2) {
        if (_confirmPin.length < _pinLength) _confirmPin += digit;
      }
    });
  }

  void _removeDigit() {
    setState(() {
      _error = null;
      if (_setupStep == 0 && _pin.isNotEmpty) {
        _pin = _pin.substring(0, _pin.length - 1);
      } else if (_setupStep == 1 && _newPin.isNotEmpty) {
        _newPin = _newPin.substring(0, _newPin.length - 1);
      } else if (_setupStep == 2 && _confirmPin.isNotEmpty) {
        _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
      }
    });
  }

  void _clearAll() {
    setState(() {
      _pin = '';
      _newPin = '';
      _confirmPin = '';
      _error = null;
    });
  }

  Future<void> _autoVerify() async {
    if (_pin.length != _pinLength) return;
    if (_switchMode) {
      await _switchUser();
    } else {
      await _verifyPin();
    }
  }

  /// Changement d'employé : identifiant (e-mail ou nom d'utilisateur) +
  /// PIN de l'employé. Établit une NOUVELLE session pour l'employé B
  /// sans mot de passe et sans fermer la session générale de la pharmacie.
  Future<void> _switchUser() async {
    if (_pin.length != _pinLength) return;
    final ident = _identCtrl.text.trim();
    if (ident.isEmpty) {
      setState(() {
        _error = 'Saisissez votre identifiant (e-mail ou nom d\'utilisateur).';
        _pin = '';
      });
      return;
    }
    setState(() => _verifying = true);
    final result = await ApiClient.instance.post(
      '/auth/switch-user',
      body: {'identifier': ident, 'pin': _pin},
      timeout: const Duration(seconds: 30),
    );
    if (!mounted) return;
    setState(() => _verifying = false);
    if (result.success && result.data is Map) {
      final map = Map<String, dynamic>.from(result.data as Map);
      final store = context.read<AuthStore>();
      await store.saveSession(
        accessToken: map['accessToken'] as String,
        refreshToken: map['refreshToken'] as String,
        user: User.fromSession(map),
      );
      if (!mounted) return;
      store.unlock();
      Navigator.pop(context);
      return;
    }
    final code = result.error?.code;
    setState(() {
      if (code == 'ACCOUNT_LOCKED') {
        _error = result.error?.message ?? 'Compte verrouillé — réessayez plus tard.';
      } else if (code == 'ACCOUNT_INACTIVE') {
        _error = result.error?.message ?? 'Compte désactivé.';
      } else if (code == 'PIN_NOT_SET') {
        _error = 'Aucun PIN configuré pour cet identifiant.';
      } else if (code == 'TWOFA_REQUIRED') {
        _error = 'Compte à double facteur — connexion par mot de passe requise.';
      } else if (code == 'SESSION_FAILED') {
        _error = 'Établissement de session impossible — réessayez.';
      } else if (code == 'NETWORK_ERROR' || result.statusCode == 0) {
        _error = 'Connexion au serveur impossible — réessayez.';
      } else {
        _error = 'Identifiant ou PIN incorrect.';
      }
      _pin = '';
    });
  }

  Future<void> _verifyPin() async {
    if (_pin.length != _pinLength) return;
    setState(() => _verifying = true);
    final result = await ApiClient.instance.post(
      '/auth/pin/verify',
      body: {'pin': _pin},
    );
    if (!mounted) return;
    setState(() => _verifying = false);
    if (result.success) {
      context.read<AuthStore>().unlock();
      Navigator.pop(context);
    } else {
      final code = result.error?.code;
      if (code == 'PIN_NOT_SET') {
        // Aucun PIN défini → proposer la définition immédiate.
        setState(() {
          _pinNotSet = true;
          _setupStep = 1;
          _pin = '';
          _error = 'Aucun PIN configuré — définissez votre code.';
        });
      } else if (code == 'ACCOUNT_LOCKED') {
        setState(
            () => _error = 'Trop de tentatives — réessayez dans quelques minutes.');
        _pin = '';
      } else {
        setState(() => _error = 'PIN incorrect');
        _pin = '';
      }
    }
  }

  Future<void> _saveNewPin() async {
    if (_newPin.length != _pinLength) {
      setState(() => _error = 'Le PIN doit contenir $_pinLength chiffres.');
      return;
    }
    if (_confirmPin != _newPin) {
      setState(() {
        _error = 'Les deux codes ne correspondent pas.';
        _setupStep = 1;
        _newPin = '';
        _confirmPin = '';
      });
      return;
    }
    setState(() => _verifying = true);
    final result = await ApiClient.instance.put(
      '/auth/pin',
      body: {'pin': _newPin},
    );
    if (!mounted) return;
    setState(() => _verifying = false);
    if (result.success) {
      // PIN créé → déverrouiller.
      context.read<AuthStore>().unlock();
      Navigator.pop(context);
    } else {
      setState(() {
        _error = result.error?.message ?? 'Erreur lors de la définition du PIN.';
        _setupStep = 1;
        _newPin = '';
        _confirmPin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    final canDismiss = context.watch<AuthStore>().isManualLock;
    return PopScope(
      canPop: canDismiss,
      child: Scaffold(
        backgroundColor: AppColors.pharmaBg,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _switchMode
                        ? Icons.swap_horiz_rounded
                        : _pinNotSet && _setupStep > 0
                            ? Icons.pin_outlined
                            : Icons.lock_outlined,
                    size: 80,
                    color: AppColors.pharmaGold,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _switchMode
                        ? S.t('changer_utilisateur', locale)
                        : _pinNotSet && _setupStep > 0
                            ? (_setupStep == 1
                                ? 'Définissez votre code PIN'
                                : 'Confirmez votre code PIN')
                            : S.t('verrouillage_verrouille', locale),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.pharmaText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_switchMode) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Identifiez le prochain employé (identifiant + PIN).',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.pharmaMuted),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _identCtrl,
                      enabled: !_verifying,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username],
                      style: const TextStyle(color: AppColors.pharmaText),
                      decoration: InputDecoration(
                        labelText: 'Identifiant (e-mail ou nom d\'utilisateur)',
                        labelStyle:
                            const TextStyle(color: AppColors.pharmaMuted),
                        prefixIcon: const Icon(Icons.person_outline,
                            color: AppColors.pharmaMuted),
                        filled: true,
                        fillColor: AppColors.pharmaSurface2,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) {
                        if (_pin.length == _pinLength) _switchUser();
                      },
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Affichage des points PIN
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pinLength, (i) {
                      final filled = _setupStep == 0
                          ? i < _pin.length
                          : _setupStep == 1
                              ? i < _newPin.length
                              : i < _confirmPin.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled
                              ? AppColors.pharmaGold
                              : Colors.grey[700],
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                            color: AppColors.danger, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_verifying) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                  ],
                  // Clavier PIN
                  _buildKeypad(),
                  const SizedBox(height: 20),
                  if (_pinNotSet && _setupStep == 2)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _verifying ? null : _saveNewPin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emerald,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Enregistrer le PIN'),
                      ),
                    ),
                  const SizedBox(height: 12),
                  // Changer d'utilisateur (identifiant + PIN du prochain employé)
                  if (_switchMode) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_verifying || _pin.length != _pinLength)
                            ? null
                            : _switchUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emerald,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Identifier cet employé'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: _verifying
                          ? null
                          : () {
                              setState(() {
                                _switchMode = false;
                                _pin = '';
                                _error = null;
                              });
                            },
                      child: const Text(
                        'Retour au PIN',
                        style: TextStyle(color: AppColors.pharmaMuted),
                      ),
                    ),
                    TextButton(
                      onPressed: _verifying
                          ? null
                          : () async {
                              final nav = Navigator.of(context);
                              await context.read<AuthStore>().signOut();
                              nav.pop();
                            },
                      child: const Text(
                        'Se déconnecter complètement',
                        style: TextStyle(
                            color: AppColors.pharmaMuted, fontSize: 12),
                      ),
                    ),
                  ] else
                    TextButton(
                      onPressed: _verifying
                          ? null
                          : () {
                              setState(() {
                                _switchMode = true;
                                _pinNotSet = false;
                                _setupStep = 0;
                                _pin = '';
                                _error = null;
                              });
                            },
                      child: Text(
                        S.t('changer_utilisateur', locale),
                        style: const TextStyle(color: AppColors.pharmaMuted),
                      ),
                    ),
                  if (canDismiss && !_switchMode) ...[
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () {
                        context.read<AuthStore>().unlock();
                        Navigator.pop(context);
                      },
                      child: Text(
                        S.t('annuler', locale),
                        style: const TextStyle(color: AppColors.pharmaMuted),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        for (final row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['C', '0', '←'],
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final label in row) ...[
                  if (label != '1' && label != '4' && label != '7' && label != 'C')
                    const SizedBox(width: 12),
                  _keypadButton(label),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _keypadButton(String label) {
    final isAction = label == '←' || label == 'C';
    return SizedBox(
      width: 72,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          if (label == '←') {
            _removeDigit();
          } else if (label == 'C') {
            _clearAll();
          } else {
            _addDigit(label);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isAction ? Colors.grey[800] : AppColors.pharmaSurface2,
          foregroundColor: AppColors.pharmaText,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
