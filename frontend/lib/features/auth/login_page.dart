import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../core/l10n/strings.dart';
import '../../core/models/user.dart';
import '../../core/services/api_client.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/pharma_logo.dart';
import 'two_factor_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _remember = true;
  bool _online = true;
  String? _error;

  late final AnimationController _anim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));
  late final Animation<double> _fade =
      CurvedAnimation(parent: _anim, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
          begin: const Offset(0, 0.08), end: Offset.zero)
      .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    _loadRemembered();
    _checkConnection();
    _anim.forward();
  }

  Future<void> _loadRemembered() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('pmg_email');
    if (saved != null && saved.isNotEmpty) {
      _email.text = saved;
    }
  }

  Future<void> _checkConnection() async {
    final url = context.read<AuthStore>().baseUrl;
    try {
      final res = await http
          .get(Uri.parse('$url/health'))
          .timeout(const Duration(seconds: 4));
      if (!mounted) return;
      setState(() => _online = res.statusCode < 500);
    } catch (_) {
      if (!mounted) return;
      setState(() => _online = false);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
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
      final starting = result.error?.code == 'SERVER_STARTING';
      setState(() {
        _error = network
            ? (starting
                ? 'Le serveur démarre, veuillez patienter quelques secondes.'
                : 'Impossible de joindre le serveur. '
                    'Vérifiez l\'URL de l\'API dans les paramètres (icône ⚙).')
            : S.format('invalidCredentials', locale);
      });
      return;
    }

    if (_remember) {
      (await SharedPreferences.getInstance())
          .setString('pmg_email', _email.text.trim());
    } else {
      (await SharedPreferences.getInstance()).remove('pmg_email');
    }

    final data = result.data!;
    if (!mounted) return;
    if (data['requireTwoFactor'] == true) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              TwoFactorPage(token: data['twoFactorToken'] as String),
        ),
      );
      return;
    }

    if (!mounted) return;
    await context.read<AuthStore>().saveSession(
          accessToken: data['accessToken'] as String,
          refreshToken: data['refreshToken'] as String,
          user: User.fromJson(data['user'] as Map<String, dynamic>),
        );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.menu, Color(0xFF12401B), Color(0xFF1B5E20)],
          ),
        ),
        child: Stack(
          children: [
            _Backdrop(),
            SafeArea(
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: isWide ? _buildWide() : _buildNarrow(),
                ),
              ),
            ),
            _ThemeToggle(),
          ],
        ),
      ),
    );
  }

  // ---- Layout web : marque + formulaire -------------------------------
  Widget _buildWide() {
    final locale = context.watch<AuthStore>().locale;
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Stack(
            children: [
              const _FloatingMeds(),
              Container(
                padding: const EdgeInsets.all(56),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                const PharmaPlusLogo(full: true, size: 72),
                const SizedBox(height: 22),
                const Text(
                  'PHARMA+',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'LOGICIEL DE PHARMACIE',
                  style: TextStyle(
                    fontSize: 13,
                    letterSpacing: 6,
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  S.t('slogan', locale),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 28),
                _Features(locale: locale),
                const Spacer(),
                _Footer(locale: locale, online: _online),
              ],
            ),
          ),
        ],
        ),
        ),
        Expanded(
          flex: 3,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
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

  // ---- Layout mobile / tablette ---------------------------------------
  Widget _buildNarrow() {
    final locale = context.watch<AuthStore>().locale;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: GlassCard(
            radius: BorderRadius.circular(28),
            padding: const EdgeInsets.all(26),
            child: Column(
              children: [
                const PharmaPlusLogo(full: true, size: 52),
                const SizedBox(height: 16),
                Text(
                  S.t('slogan', locale),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 12),
                _buildForm(),
                const SizedBox(height: 16),
                _Footer(locale: locale, online: _online),
              ],
            ),
          ),
        ),
      ),
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
          const Center(child: PharmaPlusLogo(size: 46)),
          const SizedBox(height: 10),
          Text(
            S.t('welcome', locale),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            S.t('connectToSpace', locale),
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
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _remember = !_remember),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: Checkbox(
                          value: _remember,
                          visualDensity: VisualDensity.compact,
                          onChanged: (v) =>
                              setState(() => _remember = v ?? false),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          S.t('rememberMe', locale),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: _forgotPassword,
                child: Text(
                  S.t('forgotPassword', locale),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
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

  void _forgotPassword() {
    final locale = context.read<AuthStore>().locale;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(S.t('forgotPasswordHint', locale)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -120,
          left: -80,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.22),
            ),
          ),
        ),
        Positioned(
          bottom: -140,
          right: -60,
          child: Container(
            width: 360,
            height: 360,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.turquoise.withValues(alpha: 0.14),
            ),
          ),
        ),
        Positioned(
          top: 80,
          right: 120,
          child: Icon(Icons.medication,
              size: 120, color: Colors.white.withValues(alpha: 0.04)),
        ),
        Positioned(
          bottom: 120,
          left: 90,
          child: Icon(Icons.local_pharmacy,
              size: 150, color: Colors.white.withValues(alpha: 0.04)),
        ),
      ],
    );
  }
}

/// Éléments médicaux 3D flottants (capsules) pour la zone de marque.
class _FloatingMeds extends StatelessWidget {
  const _FloatingMeds();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const _Pill(top: 70, left: 30, size: 96, color: AppColors.turquoise,
            opacity: 0.12, rotate: 0.5),
        const _Pill(top: 230, right: 50, size: 72, color: AppColors.accent,
            opacity: 0.09, rotate: -0.4),
        const _Pill(bottom: 150, left: 110, size: 120, color: AppColors.primaryLight,
            opacity: 0.12, rotate: 0.2),
        const _Pill(bottom: 60, right: 150, size: 64, color: Colors.white,
            opacity: 0.07, rotate: -0.6),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final double size;
  final Color color;
  final double opacity;
  final double rotate;

  const _Pill({
    this.top,
    this.left,
    this.right,
    this.bottom,
    required this.size,
    required this.color,
    required this.opacity,
    required this.rotate,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Transform.rotate(
        angle: rotate,
        child: Container(
          width: size,
          height: size * 0.5,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size),
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: opacity),
                color.withValues(alpha: opacity * 0.4),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: opacity * 0.6),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final isDark = auth.themeMode != ThemeMode.light;
    return Positioned(
      top: 16,
      right: 16,
      child: Material(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        child: IconButton(
          icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode,
              color: Colors.white),
          tooltip: 'Thème',
          onPressed: () => auth.setThemeMode(
              isDark ? ThemeMode.light : ThemeMode.dark),
        ),
      ),
    );
  }
}

class _Features extends StatelessWidget {
  final String locale;
  const _Features({required this.locale});

  @override
  Widget build(BuildContext context) {
    final items = [
      (S.t('featPosTitle', locale), Icons.point_of_sale, S.t('featPosSub', locale)),
      (S.t('featStockTitle', locale), Icons.inventory_2_outlined, S.t('featStockSub', locale)),
      (S.t('featReportingTitle', locale), Icons.insights, S.t('featReportingSub', locale)),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      Text(sub,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  final String locale;
  final bool online;
  const _Footer({required this.locale, required this.online});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 6,
      children: [
        const Text('PHARMA+',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white70)),
        const Text('• v2.0.0',
            style: TextStyle(fontSize: 12, color: Colors.white54)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: online ? AppColors.success : AppColors.danger,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${S.t('connectionStatus', locale)}: ${online ? S.t('online', locale) : S.t('offline', locale)}',
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
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
