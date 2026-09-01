import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/l10n/strings.dart';
import '../../core/models/user.dart';
import '../../core/services/api_client.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/pharma_background.dart';
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
    // Connection check disabled - auto-retry on failure
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

  // ---- Layout web : maquette premium PHARMA+ -----------------------
  Widget _buildWide() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF071A1B),
            Color(0xFF0A1619),
            Color(0xFF071A20),
          ],
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 24, 32, 18),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          top: 40,
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.emerald.withValues(alpha: 0.12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.emerald.withValues(alpha: 0.25),
                                  blurRadius: 35,
                                )
                              ],
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 18),
                              Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      AppColors.emerald.withValues(alpha: 0.45),
                                      AppColors.emerald.withValues(alpha: 0.12),
                                      Colors.transparent,
                                    ],
                                    radius: 1.1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.emerald.withValues(alpha: 0.25),
                                      blurRadius: 50,
                                    )
                                  ],
                                ),
                                child: Center(
                                  child: Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFF2BFF96),
                                          Color(0xFF00A960),
                                        ],
                                      ),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.25),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.emerald.withValues(alpha: 0.45),
                                          blurRadius: 18,
                                        )
                                      ],
                                    ),
                                    child: const PharmaPlusLogo(size: 108),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),
                              ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Color(0xFFE4FFF7),
                                    Color(0xFF7BFFBF),
                                    Color(0xFF1DE28B),
                                  ],
                                ).createShader(bounds),
                                child: const Text(
                                  'PHARMA+',
                                  style: TextStyle(
                                    fontSize: 94,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -6,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 7),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: AppColors.emerald.withValues(alpha: 0.7),
                                    width: 1.4,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.emerald.withValues(alpha: 0.3),
                                      blurRadius: 12,
                                    )
                                  ],
                                ),
                                child: const Text(
                                  'LOGICIEL DE PHARMACIE',
                                  style: TextStyle(
                                    color: AppColors.emeraldLight,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 3,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 40),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 60),
                                child: Text(
                                  'Gérez votre pharmacie avec intelligence\net simplicité',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w600,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 62),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  _BadgeFeature(
                                    icon: Icons.verified_user_rounded,
                                    text: 'Sécurisé',
                                    sub: 'Vos données sont protégées',
                                  ),
                                  SizedBox(width: 18),
                                  _BadgeFeature(
                                    icon: Icons.speed_rounded,
                                    text: 'Rapide',
                                    sub: 'Performance optimale',
                                  ),
                                  SizedBox(width: 18),
                                  _BadgeFeature(
                                    icon: Icons.sync_rounded,
                                    text: 'Moderne',
                                    sub: 'Interface intuitive',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Center(
                    child: Container(
                      width: 520,
                      margin: const EdgeInsets.only(right: 32, top: 20, bottom: 20),
                      padding: const EdgeInsets.fromLTRB(30, 28, 30, 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A1820).withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: AppColors.emerald.withValues(alpha: 0.35),
                          width: 1.4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 26,
                            offset: const Offset(0, 12),
                          )
                        ],
                      ),
                      child: _buildForm(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // FOOTER avec infos
          Container(
            height: 70,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.05),
                  width: 1,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      _FooterFeature(icon: Icons.verified_user_rounded, text: 'Sécurisé'),
                      SizedBox(width: 24),
                      _FooterFeature(icon: Icons.speed_rounded, text: 'Rapide'),
                      SizedBox(width: 24),
                      _FooterFeature(icon: Icons.check_circle_outline_rounded, text: 'Fiable'),
                      SizedBox(width: 24),
                      _FooterFeature(icon: Icons.dashboard_customize_rounded, text: 'Moderne'),
                      SizedBox(width: 24),
                      _FooterFeature(icon: Icons.headphones_rounded, text: 'Support'),
                      SizedBox(width: 24),
                      _FooterFeature(icon: Icons.language_rounded, text: 'Site web'),
                    ],
                  ),
                  Row(
                    children: [
                      const Text(
                        'Mode sombre',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: true,
                        activeColor: AppColors.emerald,
                        onChanged: (_) {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrow() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF071A1B),
            Color(0xFF0A1619),
            Color(0xFF071A20),
          ],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PharmaPlusLogo(size: 116),
              const SizedBox(height: 18),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFFE4FFF7),
                    Color(0xFF7BFFBF),
                    Color(0xFF1DE28B),
                  ],
                ).createShader(bounds),
                child: const Text(
                  'PHARMA+',
                  style: TextStyle(
                    fontSize: 54,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -3,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: AppColors.emerald.withValues(alpha: 0.7),
                    width: 1.3,
                  ),
                ),
                child: const Text(
                  'LOGICIEL DE PHARMACIE',
                  style: TextStyle(
                    color: AppColors.emeraldLight,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1820).withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: AppColors.emerald.withValues(alpha: 0.30),
                    width: 1.2,
                  ),
                ),
                child: _buildForm(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 52,
              height: 52,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2BFF96), Color(0xFF00A960)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.emerald.withValues(alpha: 0.35),
                    blurRadius: 18,
                  )
                ],
              ),
              child: const PharmaPlusLogo(size: 50),
            ),
          ),
          const Text(
            'Bienvenue sur PHARMA+',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Connectez-vous à votre espace',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 26),
          const Text(
            'Adresse e-mail',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 17, color: Colors.white),
            decoration: _fieldDecoration('', Icons.mail_outline),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'Adresse e-mail';
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                return 'Adresse e-mail';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Mot de passe',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Mot de passe oublié ?',
                style: TextStyle(
                  color: AppColors.emeraldLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            style: const TextStyle(fontSize: 17, color: Colors.white),
            decoration: _fieldDecoration(
              '',
              Icons.lock_outline,
              suffix: IconButton(
                icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Mot de passe' : null,
          ),
          const SizedBox(height: 18),
          InkWell(
            onTap: () => setState(() => _remember = !_remember),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: Checkbox(
                    value: _remember,
                    activeColor: AppColors.emerald,
                    side: const BorderSide(color: Colors.white70),
                    onChanged: (v) => setState(() => _remember = v ?? false),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Se souvenir de moi',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            _ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _loading ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.emerald,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.login_rounded),
            label: const Text(
              'Se connecter',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'ou',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: _submit,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
              padding: const EdgeInsets.symmetric(vertical: 17),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.pin_rounded),
            label: const Text(
              'Connexion avec code PIN',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Version 2.0.0',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white38,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }



  InputDecoration _fieldDecoration(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      hintText: label,
      hintStyle: const TextStyle(color: Colors.white38, fontSize: 15),
      prefixIcon: Icon(icon, color: AppColors.emeraldLight, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFF0E1B22),
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.emerald, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.danger, width: 1.6),
      ),
    );
  }
}

class _BadgeFeature extends StatelessWidget {
  final IconData icon;
  final String text;
  final String sub;

  const _BadgeFeature({
    required this.icon,
    required this.text,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.emerald.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppColors.emeraldLight),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                sub,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 9,
                ),
              ),
            ],
          )
        ],
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

class _FooterFeature extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FooterFeature({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.emeraldLight),
        const SizedBox(height: 2),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
