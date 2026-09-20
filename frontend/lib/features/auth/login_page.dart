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
import '../../core/widgets/pharma_logo.dart';
import 'two_factor_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with TickerProviderStateMixin {
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

  /// Lumière animée qui descend le long de la courbe or (haut → bas, en boucle).
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _shimmer.dispose();
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
    final result = await ApiClient.instance.post(
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
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    if (map['requireTwoFactor'] == true) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              TwoFactorPage(token: map['twoFactorToken'] as String),
        ),
      );
      return;
    }

    if (!mounted) return;
    await context.read<AuthStore>().saveSession(
      accessToken: map['accessToken'] as String,
      refreshToken: map['refreshToken'] as String,
      user: User.fromSession(map),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSplit = MediaQuery.of(context).size.width >= 760;

    return Scaffold(
      backgroundColor: const Color(0xFF010503),
      body: Stack(
        children: [
          // Grande carte arrondie contenant scène + formulaire (maquette).
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFF092019),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: const Color(0xFF2FB563).withValues(alpha: 0.20),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.55),
                      blurRadius: 34,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: isSplit ? _buildSplit() : _buildMobile(),
                  ),
                ),
              ),
            ),
          ),
          const _ThemeToggle(),
        ],
      ),
    );
  }

  /// Maquette desktop / tablette : l'image de fond remplit TOUTE la carte
  /// (scène + formulaire, jusqu'à la ligne de séparation), le formulaire est
  /// un panneau translucide par-dessus, la courbe or les sépare.
  Widget _buildSplit() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Fond : scène pharmacie (comptoir centré) sur toute la carte.
        kIsWeb
            ? Image.network(
                'images/pharma_login_background.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const ColoredBox(color: Color(0xFF03100D)),
              )
            : Image.asset(
                'assets/images/pharma_login_background.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const ColoredBox(color: Color(0xFF03100D)),
              ),
        // Voile dégradé : scène visible à gauche, assombri vers la droite
        // pour que le fond continue derrière le formulaire jusqu'à la courbe.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                const Color(0xFF02100C).withValues(alpha: 0.30),
                const Color(0xFF03100D).withValues(alpha: 0.45),
                const Color(0xFF03100D).withValues(alpha: 0.80),
              ],
            ),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 11,
              child: _buildScene(),
            ),
            Expanded(
              flex: 9,
              child: _buildFormPanel(),
            ),
          ],
        ),
        // Courbe dorée animée à la frontière scène / formulaire (maquette).
        // ClipRect : la courbe ne doit jamais déborder sur les côtés de la carte.
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRect(
              child: CustomPaint(
                painter: _GoldCurvePainter(shimmer: _shimmer),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Maquette smartphone : formulaire seul, centré, sur le panneau sombre.
  Widget _buildMobile() {
    return _buildFormPanel();
  }

  /// Panneau droit : carte translucide (comme la maquette) — le fond de la
  /// scène continue derrière lui jusqu'à la courbe dorée.
  Widget _buildFormPanel() {
    return Container(
      // Collé à la courbe à gauche (pas de jour) — la photo de fond continue
      // derrière le panneau translucide jusqu'à la ligne animée.
      margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.horizontal(
          left: Radius.zero,
          right: Radius.circular(20),
        ),
        border: Border.all(
          color: const Color(0xFF2FB563).withValues(alpha: 0.22),
          width: 1,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0A2B1F).withValues(alpha: 0.78),
            const Color(0xFF04160F).withValues(alpha: 0.88),
          ],
        ),
      ),
      child: LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: _buildForm(),
                ),
              ),
            ),
          ),
        );
      },
      ),
    );
  }

  /// Contenu de la scène pharmacie (l'image de fond est dans _buildSplit) :
  /// les 3 atouts (Sécurisé / Performant / Support) ancrés EN BAS de l'image.
  Widget _buildScene() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(36, 0, 36, 34),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sceneFeature(
                icon: Icons.shield_outlined,
                title: 'Sécurisé',
                subtitle: 'Vos données sont protégées',
              ),
              const SizedBox(width: 26),
              _sceneFeature(
                icon: Icons.trending_up,
                title: 'Performant',
                subtitle: 'Gestion rapide et efficace',
              ),
              const SizedBox(width: 26),
              _sceneFeature(
                icon: Icons.person_outline,
                title: 'Support',
                subtitle: 'Accompagnement dédié',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sceneFeature({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFFE9C873), size: 26),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFFDCE7E2).withValues(alpha: 0.72),
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 2),
          const Center(child: PharmaPlusLogo(size: 72)),
          const SizedBox(height: 10),
          const Center(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'PHARMA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  TextSpan(
                    text: '+',
                    style: TextStyle(
                      color: Color(0xFF2FB563),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              'Gestion intelligente de votre pharmacie',
              style: TextStyle(
                color: Color(0xFF8FA39A),
                fontSize: 11.5,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Center(
            child: Text(
              'Bienvenue',
              style: TextStyle(
                color: Color(0xFFE9C873),
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 5),
          const Center(
            child: Text(
              'Connectez-vous à votre espace professionnel',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          const SizedBox(height: 22),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: _fieldDecoration(
              hintText: 'Email professionnel',
              icon: Icons.mail_outline,
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
                    color: Color(0xFFE9C873),
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
          const SizedBox(height: 16),
          // Bouton or dégradé maquette : texte centré + flèche à droite.
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFB4881F),
                  Color(0xFFE9C873),
                  Color(0xFFC9A24B),
                ],
              ),
            ),
            child: FilledButton(
              onPressed: _loading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: const Color(0xFF123527),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_loading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF123527),
                      ),
                    )
                  else
                    const Text(
                      'SE CONNECTER',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        letterSpacing: 0.6,
                      ),
                    ),
                  const Positioned(
                    right: 16,
                    child: Icon(Icons.arrow_forward, size: 18),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          // Séparateur « ou continuez avec » (maquette).
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.16),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'ou continuez avec',
                  style: TextStyle(
                    color: Color(0xFF8FA39A),
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Bouton Google (maquette).
          OutlinedButton(
            onPressed: _loading ? null : _showGoogleInfo,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF0B1410).withValues(alpha: 0.6),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomPaint(
                  painter: _GoogleLogoPainter(),
                  size: Size(18, 18),
                ),
                SizedBox(width: 10),
                Text(
                  'Continuer avec Google',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Pied : connexion sécurisée (maquette).
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline,
                color: Color(0xFFE9C873),
                size: 13,
              ),
              const SizedBox(width: 6),
              Text(
                'Connexion sécurisée avec chiffrement 256-bit SSL',
                style: TextStyle(
                  color: const Color(0xFF8FA39A).withValues(alpha: 0.85),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  void _showGoogleInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF123527),
        content: Text(
          'La connexion Google sera disponible prochainement. '
          'Utilisez votre email professionnel.',
          style: TextStyle(color: Colors.white),
        ),
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

/// Grande courbe dorée verticale — sépare la scène pharmacie du formulaire.
/// Version maquette élargie : trait plus large, halo doux, et une lumière
/// qui descend le long de la courbe (haut → bas) en boucle.
class _GoldCurvePainter extends CustomPainter {
  const _GoldCurvePainter({this.shimmer});

  final Animation<double>? shimmer;

  @override
  void paint(Canvas canvas, Size size) {
    // Frontière scène / formulaire (flex 11 / 9 => 55 %).
    // La courbe longe le bord gauche du panneau formulaire et bombée vers la
    // DROITE uniquement : elle ne déborde jamais sur l'image de la scène.
    final x = size.width * 0.55 + 2.0;
    const bulge = 34.0;
    final path = Path()
      ..moveTo(x, -4)
      ..cubicTo(
        x + bulge, size.height * 0.30,
        x + bulge, size.height * 0.70,
        x, size.height + 4,
      );

    final shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF8A6A1F),
        Color(0xFFF2D68A),
        Color(0xFFE9C873),
        Color(0xFF8A6A1F),
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    // Halo large (ligne élargie vs maquette).
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..color = const Color(0xFFE9C873).withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    // Corps doré élargi.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..shader = shader,
    );
    // Cœur clair.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xFFFFF3CE).withValues(alpha: 0.85),
    );

    // Lumière animée qui descend du haut vers le bas le long de la courbe.
    final shimmer = this.shimmer;
    if (shimmer != null) {
      final metric = path.computeMetrics().first;
      final window = metric.length * 0.22;
      final start = (metric.length + 2 * window) * shimmer.value - window;
      final a = start.clamp(0.0, metric.length).toDouble();
      final b = (start + window).clamp(0.0, metric.length).toDouble();
      if (b > a) {
        final beam = metric.extractPath(a, b);
        canvas.drawPath(
          beam,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 9
            ..color = const Color(0xFFFFE9A8).withValues(alpha: 0.50)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
        );
        canvas.drawPath(
          beam,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xFFFFF7DC).withValues(alpha: 0.95),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GoldCurvePainter oldDelegate) =>
      oldDelegate.shimmer?.value != shimmer?.value;
}

/// Logo Google « G » officiel (4 couleurs), dessiné en vectoriel.
class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.40;
    final stroke = size.width * 0.30;

    Paint arc(Color color) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = color;

    final box = Rect.fromCircle(center: center, radius: radius);

    // Bleu : arc droit + barre horizontale.
    canvas.drawArc(box, -0.785, 1.35, false, arc(const Color(0xFF4285F4)));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          center.dx,
          center.dy - stroke / 2,
          radius,
          stroke,
        ),
        Radius.circular(stroke / 2),
      ),
      arc(const Color(0xFF4285F4))..style = PaintingStyle.fill,
    );
    // Vert : bas. / Jaune : gauche. / Rouge : haut.
    canvas.drawArc(box, 0.65, 1.05, false, arc(const Color(0xFF34A853)));
    canvas.drawArc(box, 1.85, 1.15, false, arc(const Color(0xFFFBBC05)));
    canvas.drawArc(box, 3.05, 1.25, false, arc(const Color(0xFFEA4335)));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

