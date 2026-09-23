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

    final data = result.data;
    if (data is! Map) {
      setState(() => _error = 'Réponse inattendue du serveur. Veuillez réessayer.');
      return;
    }
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

  /// Maquette desktop / tablette : l'image complète fournie (scène + courbe or
  /// + panneau vert sombre, tout inclus) remplit TOUTE la carte. On pose
  /// dessus uniquement le contenu : cards à gauche, formulaire à droite.
  Widget _buildSplit() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Fond : image JPEG légère (courbe et fond sombre déjà intégrés).
        kIsWeb
            ? Image.network(
                'images/pharma_login_full.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const ColoredBox(color: Color(0xFF03100D)),
              )
            : Image.asset(
                'assets/images/pharma_login_full.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const ColoredBox(color: Color(0xFF03100D)),
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
              child: _buildFormPanel(transparent: true),
            ),
          ],
        ),
      ],
    );
  }

  /// Maquette smartphone : formulaire seul, centré, sur le panneau sombre.
  Widget _buildMobile() {
    return _buildFormPanel();
  }

  /// Panneau droit : sur desktop, transparent (l'image de fond fournit déjà le
  /// panneau vert sombre et la courbe) ; sur mobile, carte translucide sombre.
  Widget _buildFormPanel({bool transparent = false}) {
    return Container(
      margin: transparent
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(0, 12, 12, 12),
      decoration: transparent
          ? null
          : BoxDecoration(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.zero,
                right: Radius.circular(20),
              ),
              border: Border.all(
                color: const Color(0xFF2FB563).withValues(alpha: 0.22),
                width: 1,
              ),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A2B1F),
                  Color(0xFF04160F),
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
  /// les 3 atouts (Sécurisé / Performant / Support) en BAS de l'image,
  /// au niveau du bas du comptoir, alignés à gauche.
  Widget _buildScene() {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(48, 0, 8, 26),
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

  /// Card atout : dorée avec effet 3D (dégradé or, liseré clair en haut,
  /// ombre portée profonde dessous pour le relief).
  Widget _sceneFeature({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: 132,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        // Dégradé or vertical : sombre en haut -> clair au centre -> sombre,
        // pour donner l'illusion d'un volume bombé éclairé au milieu.
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.45, 1.0],
          colors: [
            Color(0xFF8A6A1F),
            Color(0xFFF0D68A),
            Color(0xFFA87F24),
          ],
        ),
        // Liseré clair en haut (arête éclairée) + bord or sombre.
        border: Border.all(color: const Color(0xFF6E5212), width: 1),
        boxShadow: const [
          // Ombre portée : la card « flotte » au-dessus du sol.
          BoxShadow(
            color: Color(0xB2000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
          // Lueur dorée diffuse autour de la card.
          BoxShadow(
            color: Color(0x55E9C873),
            blurRadius: 14,
            offset: Offset(0, 0),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF123527).withValues(alpha: 0.85),
              border: Border.all(
                color: const Color(0xFFFFF3CE).withValues(alpha: 0.8),
                width: 1,
              ),
            ),
            child: Icon(icon, color: const Color(0xFFFFF3CE), size: 20),
          ),
          const SizedBox(height: 7),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF3A2A05),
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF5C4410),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 2),
          // Bloc de marque officiel complet (symbole + PHARMA+ + signature),
          // identique au splash / dashboard. Les textes sont DÉJÀ dans l'image.
          const Center(child: PharmaFullLogo(width: 230)),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
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
                  else ...[
                    const Text(
                      'SE CONNECTER',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.arrow_forward, size: 18),
                  ],
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

