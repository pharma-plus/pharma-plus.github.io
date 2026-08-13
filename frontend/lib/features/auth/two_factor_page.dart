import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/models/user.dart';
import '../../core/services/api_client.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/glass_card.dart';

class TwoFactorPage extends StatefulWidget {
  final String token;
  const TwoFactorPage({super.key, required this.token});

  @override
  State<TwoFactorPage> createState() => _TwoFactorPageState();
}

class _TwoFactorPageState extends State<TwoFactorPage> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _controller.text.trim();
    if (code.length != 6) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ApiClient.instance.post<Map<String, dynamic>>(
      '/auth/verify-2fa',
      body: {'twoFactorToken': widget.token, 'code': code},
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      setState(() => _error = result.error?.message ?? '2FA');
      return;
    }
    final data = result.data!;
    await context.read<AuthStore>().saveSession(
          accessToken: data['accessToken'] as String,
          refreshToken: data['refreshToken'] as String,
          user: User.fromJson(data['user'] as Map<String, dynamic>),
        );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return Scaffold(
      appBar: AppBar(title: Text(S.t('twoFactorTitle', locale))),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: GlassCard(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      gradient: AppColors.greenGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_moon,
                        color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    S.t('twoFactorHint', locale),
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 26,
                        letterSpacing: 10,
                        fontWeight: FontWeight.w800),
                    decoration: const InputDecoration(counterText: ''),
                    onSubmitted: (_) => _verify(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.danger, fontWeight: FontWeight.w600),
                    ),
                  ],
                  const SizedBox(height: 24),
                  GradientButton(
                    label: S.t('verify', locale),
                    loading: _loading,
                    onPressed: _verify,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
