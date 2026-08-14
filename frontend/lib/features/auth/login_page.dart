import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/models/user.dart';
import '../../core/services/api_client.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/glass_card.dart';
import 'two_factor_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final locale = context.read<AuthStore>().locale;
    final result = await ApiClient.instance.post<Map<String, dynamic>>(
      '/auth/login',
      body: {
        'email': _email.text.trim(),
        'password': _password.text,
        'device': {'name': 'Flutter', 'type': 'mobile', 'userAgent': 'pmg-app'},
      },
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      final network =
          result.error?.code == 'NETWORK_ERROR' || result.statusCode == 0;
      setState(() {
        _error = network
            ? 'Impossible de joindre le serveur. '
                'Vérifiez l\'URL de l\'API dans les paramètres (icône ⚙).'
            : S.format('invalidCredentials', locale);
      });
      return;
    }

    final data = result.data!;
    if (data['requireTwoFactor'] == true) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              TwoFactorPage(token: data['twoFactorToken'] as String),
        ),
      );
      return;
    }

    await context.read<AuthStore>().saveSession(
          accessToken: data['accessToken'] as String,
          refreshToken: data['refreshToken'] as String,
          user: User.fromJson(data['user'] as Map<String, dynamic>),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.menu, Color(0xFF12401B), Color(0xFF1B5E20)],
              ),
            ),
            child: SafeArea(
              child: wide ? _buildWide() : _buildNarrow(),
            ),
          );
        },
      ),
    );
  }

  // ---- Layout mobile / tablette : carte centrée -------------------------
  Widget _buildNarrow() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: GlassCard(
            radius: BorderRadius.circular(28),
            padding: const EdgeInsets.all(28),
            child: _buildForm(),
          ),
        ),
      ),
    );
  }

  // ---- Layout web : panneau marque + formulaire -------------------------
  Widget _buildWide() {
    final locale = context.watch<AuthStore>().locale;
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Container(
            padding: const EdgeInsets.all(56),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF071A0B),
                  Color(0xFF0A2A0F),
                  Color(0xFF12401B),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _BrandMark(size: 92),
                const SizedBox(height: 40),
                const Text(
                  'PHARMA MAROC GOLD',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'ENTERPRISE V2.0',
                  style: TextStyle(
                    fontSize: 13,
                    letterSpacing: 6,
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),
                _Features(locale: locale),
                const Spacer(),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: AppColors.goldGradient,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      S.t('tagline', locale),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: GlassCard(
                  radius: BorderRadius.circular(28),
                  padding: const EdgeInsets.all(32),
                  child: _buildForm(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    final locale = context.watch<AuthStore>().locale;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Logo(),
          const SizedBox(height: 24),
          Text(
            S.t('login', locale),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            S.t('signInSubtitle', locale),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: S.t('email', locale),
              prefixIcon: const Icon(Icons.mail_outline),
            ),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return S.t('email', locale);
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                return S.t('email', locale);
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: S.t('password', locale),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? S.t('password', locale) : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            _ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 24),
          GradientButton(
            label: S.t('signIn', locale),
            icon: Icons.login,
            loading: _loading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  final double size;
  const _BrandMark({this.size = 84});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.goldGradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xAAFFB300),
            blurRadius: size / 3,
            offset: Offset(0, size / 8),
          ),
        ],
      ),
      child: Icon(Icons.local_pharmacy,
          size: size * 0.52, color: const Color(0xFF3E2A00)),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _BrandMark(),
        SizedBox(height: 16),
        Text(
          'PHARMA MAROC GOLD',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: AppColors.accent,
          ),
        ),
        Text(
          'ENTERPRISE V2.0',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 4,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

class _Features extends StatelessWidget {
  final String locale;
  const _Features({required this.locale});

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        S.t('featPosTitle', locale),
        Icons.point_of_sale,
        S.t('featPosSub', locale)
      ),
      (
        S.t('featStockTitle', locale),
        Icons.inventory_2_outlined,
        S.t('featStockSub', locale)
      ),
      (
        S.t('featReportingTitle', locale),
        Icons.insights,
        S.t('featReportingSub', locale)
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (title, icon, sub) in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.accent, size: 22),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      sub,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  color: AppColors.danger, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
