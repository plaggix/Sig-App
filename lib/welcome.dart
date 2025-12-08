import 'package:flutter/material.dart';
import 'login_page.dart';
import 'register_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/acceuil.jpg'),
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
        child: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.4),
                  Colors.white.withOpacity(0.2),
                  Colors.black.withOpacity(0.1),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isPortrait = constraints.maxHeight > constraints.maxWidth;
                final isTablet = constraints.maxWidth > 600;

                if (isTablet) {
                  return _buildTabletLayout(context);
                } else {
                  return _buildMobileLayout(isPortrait, context);
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(bool isPortrait, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Espace flexible pour pousser le contenu vers le centre
          if (isPortrait) const Spacer(flex: 2),

          // Logo et texte
          _buildWelcomeContent(context),

          // Espace entre le contenu et les boutons
          const Spacer(flex: 1),

          // Boutons
          _buildButtonSection(isPortrait, context),

          if (!isPortrait) const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Colonne gauche - Contenu
          Expanded(
            flex: 2,
            child: _buildWelcomeContent(context),
          ),

          // Colonne droite - Boutons
          Expanded(
            flex: 1,
            child: _buildButtonSection(false, context),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeContent(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Logo avec animation
        _buildAnimatedLogo(),

        const SizedBox(height: 24),

        // Titre avec animation
        _buildAnimatedTitle(context),

        const SizedBox(height: 16),

        // Description avec animation
        _buildAnimatedDescription(context),
      ],
    );
  }

  Widget _buildAnimatedLogo() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 800),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0.0, 50 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Image.asset(
        'assets/welcome1.png',
        height: 180,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildAnimatedTitle(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0.0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Text(
        'Bienvenue !',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: const Color(0xFF2E7D32),
          fontSize: 32,
        ),
      ),
    );
  }

  Widget _buildAnimatedDescription(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0.0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Text(
        'Gérez vos tâches facilement et restez organisé tout au long de la journée.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Colors.black87,
          height: 1.5,
          fontSize: 16,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildButtonSection(bool isPortrait, BuildContext context) {
    final buttonLayout = isPortrait ? Axis.vertical : Axis.horizontal;
    final mainButtonSpacing = isPortrait ? 12.0 : 15.0;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 700),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0.0, 40 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Flex(
        direction: buttonLayout,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WelcomeButton(
            text: 'Se connecter',
            isPrimary: true,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => LoginPage()),
              );
            },
          ),
          SizedBox(height: mainButtonSpacing, width: mainButtonSpacing),
          WelcomeButton(
            text: "S'inscrire",
            isPrimary: false,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => RegisterPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class WelcomeButton extends StatelessWidget {
  final String text;
  final bool isPrimary;
  final VoidCallback onPressed;

  const WelcomeButton({
    super.key,
    required this.text,
    required this.isPrimary,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: text,
      child: Material(
        borderRadius: BorderRadius.circular(12),
        color: isPrimary
            ? const Color(0xFF2E7D32)
            : Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          splashColor: isPrimary
              ? Colors.white.withOpacity(0.2)
              : const Color(0xFF2E7D32).withOpacity(0.1),
          highlightColor: isPrimary
              ? Colors.white.withOpacity(0.1)
              : const Color(0xFF2E7D32).withOpacity(0.05),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: isPrimary
                  ? null
                  : Border.all(
                color: const Color(0xFF2E7D32),
                width: 2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isPrimary ? Icons.login : Icons.person_add,
                  color: isPrimary ? Colors.white : const Color(0xFF2E7D32),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isPrimary ? Colors.white : const Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}