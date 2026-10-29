
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const SquadVibeApp());
}

class SquadVibeApp extends StatelessWidget {
  const SquadVibeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SquadVibe',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF100B1F),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9B5CFF),
          brightness: Brightness.dark,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF211833),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      home: const AuthPage(),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  final pseudo = TextEditingController();

  bool isLogin = true;
  bool loading = false;
  bool obscure = true;
  String message = '';

  Future<void> submit() async {
    final mail = email.text.trim();
    final pass = password.text;
    final name = pseudo.text.trim();

    if (mail.isEmpty || pass.isEmpty ||
        (!isLogin && name.isEmpty)) {
      setState(() => message = 'Remplis tous les champs.');
      return;
    }

    if (!isLogin && pass.length < 6) {
      setState(() =>
          message = 'Le mot de passe doit contenir au moins 6 caractères.');
      return;
    }

    setState(() {
      loading = true;
      message = '';
    });

    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: mail,
          password: pass,
        );
      } else {
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: mail,
          password: pass,
        );

        await credential.user?.sendEmailVerification();

        if (mounted) {
          setState(() {
            message =
                'Compte créé ! Vérifie ta boîte mail pour confirmer ton adresse.';
            isLogin = true;
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          message = switch (e.code) {
            'email-already-in-use' => 'Cette adresse est déjà utilisée.',
            'invalid-email' => 'Adresse e-mail invalide.',
            'weak-password' => 'Choisis un mot de passe plus solide.',
            'user-not-found' => 'Aucun compte trouvé avec cet e-mail.',
            'wrong-password' || 'invalid-credential' =>
              'E-mail ou mot de passe incorrect.',
            'network-request-failed' =>
              'Vérifie ta connexion Internet.',
            'too-many-requests' =>
              'Trop de tentatives. Réessaie plus tard.',
            _ => 'Erreur : ${e.message ?? e.code}',
          };
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => message =
            'Firebase n’est pas encore correctement configuré.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    pseudo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.bolt_rounded,
                    size: 68,
                    color: Color(0xFFB58AFF),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'SQUADVIBE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isLogin
                        ? 'Content de te revoir !'
                        : 'Crée ton compte et rejoins tes amis.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 32),
                  if (!isLogin) ...[
                    TextField(
                      controller: pseudo,
                      maxLength: 20,
                      decoration: const InputDecoration(
                        labelText: 'Ton pseudo',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Adresse e-mail',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: password,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => obscure = !obscure),
                        icon: Icon(obscure
                            ? Icons.visibility
                            : Icons.visibility_off),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: loading ? null : submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      backgroundColor: const Color(0xFF8B4DFF),
                    ),
                    child: loading
                        ? const CircularProgressIndicator()
                        : Text(isLogin
                            ? 'Se connecter'
                            : 'Créer mon compte'),
                  ),
                  TextButton(
                    onPressed: loading
                        ? null
                        : () => setState(() {
                              isLogin = !isLogin;
                              message = '';
                            }),
                    child: Text(isLogin
                        ? 'Pas encore de compte ? Inscris-toi'
                        : 'Déjà un compte ? Connecte-toi'),
                  ),
                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFD0B6FF)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
