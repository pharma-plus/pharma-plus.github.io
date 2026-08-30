import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
import '../../core/widgets/pharma_background.dart';
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
      body: PharmaBackground(
        overlayOpacity: 0.45,
        child: Stack(
          children: [
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
                padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 48, top: 8, right: 64),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const PharmaPlusLogo(full: true, size: 110),
                            const SizedBox(height: 6),
                            Text(
                              'LOGICIEL DE PHARMACIE',
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                fontSize: 15,
                                letterSpacing: 5,
                                height: 0.5,
                                color: AppColors.turquoiseLight,
                                fontWeight: FontWeight.w900,
                                shadows: [
                                  Shadow(
                                    color: AppColors.turquoise,
                                    blurRadius: 14,
                                    offset: Offset(0, 2),
                                  ),
                                  Shadow(
                                    color: Color(0x2EFFFFFF),
                                    blurRadius: 28,
                                    offset: Offset(0, 5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    _FeaturesWithSlogan(locale: locale),
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
                  padding: const EdgeInsets.all(36),
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
            padding: const EdgeInsets.all(30),
            child: Column(
              children: [
                const PharmaPlusLogo(full: true, size: 120),
                const SizedBox(height: 14),
                Text(
                  S.t('slogan', locale),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const SizedBox(height: 14),
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
          const SizedBox(height: 14),
          Text(
            S.t('welcome', locale),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
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
          const SizedBox(height: 30),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 18),
            decoration:
                _fieldDecoration(S.t('email', locale), Icons.mail_outline),
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
            style: const TextStyle(fontSize: 18),
            decoration: _fieldDecoration(
              S.t('password', locale),
              Icons.lock_outline,
              suffix: IconButton(
                icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? S.t('password', locale) : null,
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 26),
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

  InputDecoration _fieldDecoration(String label, IconData icon, {Widget? suffix}) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.turquoise),
      suffixIcon: suffix,
      filled: true,
      fillColor: cs.surface.withValues(alpha: 0.5),
      contentPadding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
      labelStyle: const TextStyle(fontSize: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.turquoise, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cs.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cs.error, width: 1.8),
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

/// Fond 3D : halos verts, grille en perspective, vignette de profondeur,
/// et icônes pharmaceutiques discrètes.
class _Backdrop3D extends StatelessWidget {
  const _Backdrop3D();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: kIsWeb
              ? Image.network(
                  'images/pharma_login_background.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                )
              : Image.asset(
                  'assets/images/pharma_login_background.webp',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
        ),
        Positioned.fill(
          child: ColoredBox(color: Color(0xB3000B08)),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppColors.menu.withValues(alpha: 0.12),
                  AppColors.menu.withValues(alpha: 0.78),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -140,
          left: -100,
          child: Container(
            width: 380,
            height: 380,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.28),
            ),
          ),
        ),
        Positioned(
          bottom: -160,
          right: -80,
          child: Container(
            width: 420,
            height: 420,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.turquoise.withValues(alpha: 0.16),
            ),
          ),
        ),
        const _GridBackdrop(),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.15,
                colors: [
                  Colors.transparent,
                  AppColors.menu.withValues(alpha: 0.55),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 70,
          right: 120,
          child: Icon(Icons.medication,
              size: 140, color: Colors.white.withValues(alpha: 0.035)),
        ),
        Positioned(
          bottom: 110,
          left: 80,
          child: Icon(Icons.local_pharmacy,
              size: 170, color: Colors.white.withValues(alpha: 0.035)),
        ),
      ],
    );
  }
}

/// Grille technique subtile pour l'effet de profondeur 3D.
class _GridBackdrop extends StatelessWidget {
  const _GridBackdrop();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(
        painter: _GridPainter(Colors.white.withValues(alpha: 0.04)),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color color;
  const _GridPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1;
    const step = 46.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Écusson pharmacie (croix +) lumineux, rendu 3D.
class _PharmacyCross extends StatelessWidget {
  final double size;
  const _PharmacyCross({this.size = 56});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.turquoise.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.turquoise.withValues(alpha: 0.5),
            blurRadius: 32,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Center(
        child: SizedBox(
          width: size * 0.52,
          height: size * 0.52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: size * 0.18,
                height: size * 0.52,
                decoration: BoxDecoration(
                  color: AppColors.turquoiseLight,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              Container(
                width: size * 0.52,
                height: size * 0.18,
                decoration: BoxDecoration(
                  color: AppColors.turquoiseLight,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        ),
      ),
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
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: AppColors.turquoiseGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.turquoise.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
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

class _FeaturesWithSlogan extends StatelessWidget {
  final String locale;
  const _FeaturesWithSlogan({required this.locale});

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
        // Slogan complet au-dessus de l'icône Comptoir
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.t('slogan', locale),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.turquoiseLight,
                height: 1.5,
                shadows: [
                  Shadow(
                    color: AppColors.turquoise,
                    blurRadius: 20,
                    offset: Offset(0, 4),
                  ),
                  Shadow(
                    color: Color(0x2EFFFFFF),
                    blurRadius: 40,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: AppColors.turquoiseGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.turquoise.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(Icons.point_of_sale, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        S.t('featPosTitle', locale),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        S.t('featPosSub', locale),
                        style: const TextStyle(
                          color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Autres features
        for (int i = 1; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: AppColors.turquoiseGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.turquoise.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(items[i].$2, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(items[i].$1,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      Text(items[i].$3,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 14)),
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
