// PMG-LAYOUT-TUNING

// Page de connexion PHARMA+ — conforme à la maquette « connexion photo 4 ».
import 'package:flutter/foundation.dart' show kIsWeb;
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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  bool _remember = true;
  String? _error;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.08),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  ));

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('pmg_email');
    if (saved != null && saved.isNotEmpty && mounted) {
      setState(() => _emailController.text = saved);
    }
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
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'device': {
          'name': 'Flutter',
          'type': 'mobile',
          'userAgent': 'pmg-app'
        },
      },
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      final network =
          result.error?.code == 'NETWORK_ERROR' || result.statusCode == 0;
      final starting = result.error?.code == 'SERVER_STARTING';
      final isValidation = result.statusCode == 422 ||
          result.error?.code == 'VALIDATION_ERROR';
      setState(() {
        _error = network
            ? (starting
                ? 'Le serveur démarre, veuillez patienter quelques secondes.'
                : 'Impossible de joindre le serveur. Vérifiez l\'URL de l\'API dans les paramètres (icône ⚙).')
            : isValidation
                ? 'Saisie invalide : vérifiez votre identifiant (nom d\'utilisateur ou e-mail) et votre mot de passe (8 caractères minimum).'
                : S.format('invalidCredentials', locale);
      });
      return;
    }

    if (_remember) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pmg_email', _emailController.text.trim());
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pmg_email');
    }

    final data = result.data!;
    if (data['requireTwoFactor'] == true) {
      if (!mounted) return;
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
    final isSplit = MediaQuery.of(context).size.width >= 1080;
    if (isSplit) {
      // Maquette desktop : scène pharmacie à gauche, formulaire à droite.
      return Scaffold(
        body: Stack(
          children: [
            FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: _buildSplit(),
              ),
            ),
            const _ThemeToggle(),
          ],
        ),
      );
    }

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
                  child: isWide ? _buildWideCard() : _buildMobileCard(),
                ),
              ),
            ),
            const _ThemeToggle(),
          ],
        ),
      ),
    );
  }

  Widget _buildWideCard() {
    // Carte centrée et compacte : tient dans une seule vue à l'ouverture.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: const EdgeInsets.fromLTRB(26, 20, 26, 18),
            decoration: BoxDecoration(
              color: const Color(0xFF041C18).withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: const Color(0xFFD7AE4F),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 30,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: _buildForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileCard() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            decoration: BoxDecoration(
              color: const Color(0xFF041C18).withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: const Color(0xFFD7AE4F),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 26,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: _buildForm(),
          ),
        ),
      ),
    );
  }

  /// Maquette desktop : à gauche la grande scène pharmacie premium (zone
  /// de marque), à droite la carte de connexion PHARMA+.
  Widget _buildSplit() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 11,
          child: _buildScene(),
        ),
        Expanded(
          flex: 9,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF03100D).withValues(alpha: 0.97),
              border: Border(
                left: BorderSide(
                  color: AppColors.goldBorderStrong,
                  width: 1,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
            alignment: Alignment.center,
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: _buildForm(splitLayout: true),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Grande scène pharmacie premium — image, logo, PHARMA+, tagline.
  Widget _buildScene() {
    return Stack(
      fit: StackFit.expand,
      children: [
        kIsWeb
            ? Image.network(
                'images/pharma_login_background.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const ColoredBox(color: Color(0xFF03100D)),
              )
            : Image.asset(
                'assets/images/pharma_login_background.webp',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const ColoredBox(color: Color(0xFF03100D)),
              ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF02100C).withValues(alpha: 0.82),
                const Color(0xFF03100D).withValues(alpha: 0.60),
                const Color(0xFF06251D).withValues(alpha: 0.85),
              ],
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo officiel complet : le nom PHARMA+ et la signature
                // sont deja dans l'asset — aucun texte répété en dessous.
                const PharmaFullLogo(width: 360),
                const SizedBox(height: 16),
                const Text(
                  'PHARMACIE PREMIUM',
                  style: TextStyle(
                    color: AppColors.pharmaGold,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForm({bool splitLayout = false}) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (splitLayout) ...[
            const SizedBox(height: 2),
            const Center(child: PharmaFullLogo(width: 185)),
            const SizedBox(height: 14),
            const Center(
              child: Text(
                'Bienvenue',
                style: TextStyle(
                  color: Color(0xFFE9C873),
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Center(
              child: Text(
                'Connectez-vous à votre espace',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13.5),
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            const SizedBox(height: 2),
            const Center(child: PharmaFullLogo(width: 205)),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Bienvenue',
                style: TextStyle(
                  color: Color(0xFFE9C873),
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Center(
              child: Text(
                'Connectez-vous à votre espace professionnel',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: _fieldDecoration(
              hintText: 'Nom d\'utilisateur',
              icon: Icons.person_outline,
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) {
                return 'Veuillez saisir votre nom d\'utilisateur ou votre e-mail';
              }
              final isEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
              final isUsername = RegExp(r'^[a-zA-Z0-9._-]{3,40}$').hasMatch(text);
              if (!isEmail && !isUsername) {
                return 'Nom d\'utilisateur ou adresse e-mail invalide';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: _fieldDecoration(
              hintText: 'Mot de passe',
              icon: Icons.lock_outline,
              suffix: IconButton(
                splashRadius: 18,
                icon: Icon(
                  _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.emeraldLight,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (value) {
              final text = value ?? '';
              if (text.isEmpty) return 'Veuillez saisir votre mot de passe';
              if (text.length < 8) {
                return 'Le mot de passe contient au moins 8 caractères';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _remember = !_remember),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _remember,
                        activeColor: AppColors.emerald,
                        side: const BorderSide(color: Colors.white70),
                        onChanged: (value) =>
                            setState(() => _remember = value ?? false),
                      ),
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
              ),
              TextButton(
                onPressed: () {},
                child: const Text(
                  'Mot de passe oublié ?',
                  style: TextStyle(
                    color: AppColors.emeraldLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            _ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD7AE4F),
              foregroundColor: const Color(0xFF07201B),
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF07201B),
                    ),
                  )
                : const Icon(Icons.login_rounded),
            label: const Text(
              'SE CONNECTER',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'ou',
              style: TextStyle(
                color: Colors.white38,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _loading ? null : _submit,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.pin_outlined),
            label: const Text(
              'Connexion avec code PIN',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Votre santé, notre priorité',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              'v2.0.0',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFF0A221E),
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.white38),
      prefixIcon: Icon(icon, color: AppColors.emeraldLight),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.emerald, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.6),
      ),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final isDark = auth.themeMode != ThemeMode.light;

    return Positioned(
      top: 18,
      right: 18,
      child: Material(
        color: Colors.white.withValues(alpha: 0.06),
        shape: const CircleBorder(),
        child: IconButton(
          onPressed: () => auth.setThemeMode(
            isDark ? ThemeMode.light : ThemeMode.dark,
          ),
          tooltip: 'Thème',
          icon: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            color: Colors.white,
          ),
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
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

