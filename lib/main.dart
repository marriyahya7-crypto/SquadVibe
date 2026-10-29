
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> main() async {
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
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) return const HomePage();
        return const AuthPage();
      },
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
    final normalizedName = name.toLowerCase();

    if (mail.isEmpty || pass.isEmpty ||
        (!isLogin && name.isEmpty)) {
      setState(() => message = 'Remplis tous les champs.');
      return;
    }

    if (!isLogin && !RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(name)) {
      setState(() => message =
          'Pseudo : 3 à 20 caractères, lettres, chiffres ou _.');
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
        final db = FirebaseFirestore.instance;
        final user = FirebaseAuth.instance.currentUser;

        final pseudoRef = db.collection('usernames').doc(normalizedName);
        final userRef = db.collection('users');

        final existing = await pseudoRef.get();
        if (existing.exists) {
          setState(() => message = 'Ce pseudo est déjà pris.');
          return;
        }

        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: mail,
          password: pass,
        );

        await db.runTransaction((transaction) async {
          final check = await transaction.get(pseudoRef);
          if (check.exists) {
            throw Exception('PSEUDO_TAKEN');
          }
          transaction.set(pseudoRef, {
            'uid': credential.user!.uid,
          });
          transaction.set(userRef.doc(credential.user!.uid), {
            'uid': credential.user!.uid,
            'pseudo': name,
            'email': mail,
            'createdAt': FieldValue.serverTimestamp(),
          });
        });

        await credential.user?.sendEmailVerification();

        if (mounted) {
          setState(() {
            message = 'Compte créé ! Vérifie tes e-mails.';
            isLogin = true;
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          message = switch (e.code) {
            'email-already-in-use' => 'Cette adresse e-mail est déjà utilisée.',
            'invalid-email' => 'Adresse e-mail invalide.',
            'weak-password' => 'Mot de passe trop faible.',
            'user-not-found' => 'Aucun compte trouvé avec cet e-mail.',
            'wrong-password' || 'invalid-credential' =>
              'E-mail ou mot de passe incorrect.',
            'network-request-failed' => 'Vérifie ta connexion Internet.',
            'too-many-requests' => 'Trop de tentatives. Réessaie plus tard.',
            _ => 'Erreur : ${e.message ?? e.code}',
          };
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          message = e.toString().contains('PSEUDO_TAKEN')
              ? 'Ce pseudo vient d’être pris. Choisis-en un autre.'
              : 'Erreur Firebase. Vérifie la configuration et les règles Firestore.';
        });
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
                  const Icon(Icons.bolt_rounded,
                      size: 68, color: Color(0xFFB58AFF)),
                  const SizedBox(height: 12),
                  const Text('SQUADVIBE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3)),
                  const SizedBox(height: 8),
                  Text(
                    isLogin ? 'Content de te revoir !' : 'Rejoins tes amis.',
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
                        onPressed: () => setState(() => obscure = !obscure),
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
                        : Text(isLogin ? 'Se connecter' : 'Créer mon compte'),
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
                    Text(message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFD0B6FF))),
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

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<String> getPseudo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Joueur';
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    return doc.data()?['pseudo'] as String? ?? 'Joueur';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SQUADVIBE'),
        actions: [
          IconButton(
            tooltip: 'Se déconnecter',
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: FutureBuilder<String>(
          future: getPseudo(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded,
                    size: 72, color: Color(0xFFB58AFF)),
                const SizedBox(height: 16),
                Text('Bienvenue sur SquadVibe, ${snapshot.data ?? 'Joueur'} !',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Ton espace est prêt.'),
              ],
            );
          },
        ),
      ),
    );
  }
}
