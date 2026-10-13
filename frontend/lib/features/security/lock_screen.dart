import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/api_client.dart';
import '../../core/services/auth_store.dart';

/// Écran de verrouillage de l'application
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pinController = TextEditingController();
  String? _error;
  bool _verifying = false;
  bool _showKeypad = true;
  late List<String> _pinDigits = [];

  @override
  void initState() {
    super.initState();
    _pinController.clear();
    _error = null;
    _pinDigits = [];
  }

  // Ajouter un chiffre au PIN
  void _addDigit(String digit) {
    setState(() {
      if (_pinDigits.length < 4) {
        _pinDigits.add(digit);
        _pinController.text += digit;
      }
    });
  }

  // Supprimer le dernier chiffre
  void _removeDigit() {
    setState(() {
      if (_pinDigits.isNotEmpty) {
        _pinDigits.removeLast();
        _pinController.text = _pinDigits.join();
      }
    });
  }

  Future<void> _verifyPin() async {
    setState(() => _verifying = true);
    final result = await ApiClient.instance.post(
      '/auth/pin/verify',
      body: {'pin': _pinController.text},
    );
    if (!mounted) return;
    setState(() => _verifying = false);
    if (result.success) {
      // PIN correct → déverrouiller l'état global puis fermer l'écran.
      if (!mounted) return;
      context.read<AuthStore>().unlock();
      Navigator.pop(context);
    } else {
      setState(() => _error = 'PIN incorrect');
      // Effacer et secouer
      _pinDigits.clear();
      _pinController.clear();
      // TODO: animation shake
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    // Verrouillage automatique (inactivité) : pas d'échappatoire sans PIN.
    final canDismiss = context.watch<AuthStore>().isManualLock;
    return PopScope(
      canPop: canDismiss,
      child: Scaffold(
        body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icône verrouillage
                  Icon(
                    Icons.lock_outlined,
                    size: 100,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 24),
                  // Titre
                  Text(
                    S.t('verrouillage_verrouille', locale),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Message d'erreur
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                  ],
                  // Champ PIN
                  TextField(
                    controller: _pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24),
                    decoration: InputDecoration(
                      labelText: S.t('code_pin', locale),
                      hintText: '0000',
                      border: const OutlineInputBorder(),
                      suffixIcon: _showKeypad
                          ? _buildKeypad()
                          : null,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Bouton Vérifier
                  _verifying
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _verifyPin,
                          child: Text(S.t('verifier', locale)),
                        ),
                  const SizedBox(height: 16),
                  // Bouton Changer d'utilisateur : déconnexion complète.
                  TextButton(
                    onPressed: () async {
                      final nav = Navigator.of(context);
                      await context.read<AuthStore>().signOut();
                      nav.pop();
                    },
                    child: Text(S.t('changer_utilisateur', locale)),
                  ),
                  if (canDismiss) ...[
                    const SizedBox(height: 16),
                    // Bouton Annuler : uniquement pour un verrouillage manuel
                    // (l'utilisateur a choisi de verrouiller, il peut revenir).
                    TextButton(
                      onPressed: () {
                        context.read<AuthStore>().unlock();
                        Navigator.pop(context);
                      },
                      child: Text(S.t('annuler', locale)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
  }

  // Clavier PIN
  Widget _buildKeypad() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _keypadButton('1'),
        _keypadButton('2'),
        _keypadButton('3'),
        const SizedBox(width: 8),
        _keypadButton('4'),
        _keypadButton('5'),
        _keypadButton('6'),
        const SizedBox(width: 8),
        _keypadButton('7'),
        _keypadButton('8'),
        _keypadButton('9'),
        const SizedBox(width: 8),
        _keypadButton('C'), // Clear
        const SizedBox(width: 8),
        _keypadButton('0'),
        _keypadButton('←'), // Backspace
      ],
    );
  }

  Widget _keypadButton(String label) {
    final isBackspace = label == '←';
    final isClear = label == 'C';
    return SizedBox(
      width: 56,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          if (isBackspace) {
            _removeDigit();
          } else if (isClear) {
            _pinDigits.clear();
            _pinController.clear();
          } else {
            _addDigit(label);
          }
        },
        child: Text(
          label,
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}