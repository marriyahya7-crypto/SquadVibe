import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const purple = Color(0xFF9B5CFF);
const bg = Color(0xFF100B1F);
const panel = Color(0xFF211833);

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
      title: 'SquadVibe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: purple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
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
        if (snapshot.hasData) return const MainPage();
        return const LoginPage();
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  final pseudo = TextEditingController();
  bool register = false;
  bool loading = false;
  String error = '';

  Future<void> submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      loading = true;
      error = '';
    });

    try {
      final mail = email.text.trim();
      final pass = password.text;
      final name = pseudo.text.trim();
      final normalized = name.toLowerCase();

      if (mail.isEmpty || pass.isEmpty ||
          (register && name.isEmpty)) {
        throw Exception('Remplis tous les champs.');
      }

      if (register) {
        if (!RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(name)) {
          throw Exception('Pseudo : 3 à 20 lettres, chiffres ou _.');
        }
        if (pass.length < 6) {
          throw Exception('Mot de passe : 6 caractères minimum.');
        }

        final db = FirebaseFirestore.instance;
        final usernameRef = db.collection('usernames').doc(normalized);
        final userRef = db.collection('users');

        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: mail,
          password: pass,
        );

        try {
          await db.runTransaction((tx) async {
            final existing = await tx.get(usernameRef);
            if (existing.exists) {
              throw Exception('PSEUDO_TAKEN');
            }
            tx.set(usernameRef, {'uid': credential.user!.uid});
            tx.set(userRef.doc(credential.user!.uid), {
              'uid': credential.user!.uid,
              'pseudo': name,
              'email': mail,
              'createdAt': FieldValue.serverTimestamp(),
            });
          });
        } catch (_) {
          await credential.user?.delete();
          rethrow;
        }

        if (mounted) {
          setState(() {
            register = false;
            error = 'Compte créé ! Tu peux te connecter.';
          });
        }
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: mail,
          password: pass,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          error = switch (e.code) {
            'email-already-in-use' => 'Cette adresse est déjà utilisée.',
            'invalid-email' => 'Adresse e-mail invalide.',
            'weak-password' => 'Mot de passe trop faible.',
            'user-not-found' => 'Compte introuvable.',
            'wrong-password' || 'invalid-credential' =>
              'E-mail ou mot de passe incorrect.',
            'network-request-failed' => 'Vérifie Internet.',
            _ => 'Erreur : ${e.message ?? e.code}',
          };
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString().contains('PSEUDO_TAKEN')
              ? 'Ce pseudo est déjà pris.'
              : e.toString().replaceFirst('Exception: ', '');
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.bolt, size: 78, color: purple),
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
                  register ? 'Rejoins ta squad.' : 'Content de te revoir.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                if (register) ...[
                  TextField(
                    controller: pseudo,
                    maxLength: 20,
                    decoration: const InputDecoration(
                      labelText: 'Pseudo unique',
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Adresse e-mail',
                    prefixIcon: Icon(Icons.mail),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: loading ? null : submit,
                  child: loading
                      ? const CircularProgressIndicator()
                      : Text(register ? 'Créer mon compte' : 'Se connecter'),
                ),
                TextButton(
                  onPressed: loading
                      ? null
                      : () => setState(() {
                            register = !register;
                            error = '';
                          }),
                  child: Text(register
                      ? 'J’ai déjà un compte'
                      : 'Créer un compte'),
                ),
                if (error.isNotEmpty)
                  Text(error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFD0B6FF))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int tab = 0;

  final titles = ['Accueil', 'Amis', 'Messages', 'Profil'];

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomeTab(),
      const FriendsTab(),
      const SimpleTab(
        icon: Icons.chat_bubble_outline,
        title: 'Messages',
        subtitle: 'Tes conversations apparaîtront ici.',
      ),
      const ProfileTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.bolt, color: purple),
            const SizedBox(width: 8),
            Text('SQUADVIBE · ${titles[tab]}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Amis',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final name = snapshot.data?.data()?['pseudo'] ?? 'Joueur';
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7138C9), Color(0xFF34205A)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.bolt, size: 42),
                  const SizedBox(height: 16),
                  Text('Salut $name !',
                      style: const TextStyle(
                          fontSize: 27, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Ta squad, tes amis, ton univers.'),
                  const SizedBox(height: 20),
                  const Text('Bienvenue dans SquadVibe 🚀'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('TON ESPACE',
                style: TextStyle(
                    color: Colors.white60,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2)),
            const SizedBox(height: 12),
            const FeatureCard(
              icon: Icons.people,
              title: 'Trouve ta squad',
              subtitle: 'Recherche des joueurs et développe ton réseau.',
            ),
            const FeatureCard(
              icon: Icons.chat_bubble,
              title: 'Reste connecté',
              subtitle: 'Retrouve tes conversations au même endroit.',
            ),
            const FeatureCard(
              icon: Icons.shield,
              title: 'Ton compte',
              subtitle: 'Gère ton profil et protège tes informations.',
            ),
          ],
        );
      },
    );
  }
}

class FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: panel,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: purple.withValues(alpha: 0.2),
          child: Icon(icon, color: purple),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
      ),
    );
  }
}

class FriendsTab extends StatefulWidget {
  const FriendsTab({super.key});

  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> {
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Trouve des joueurs',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Recherche un pseudo SquadVibe.'),
        const SizedBox(height: 20),
        TextField(
          controller: search,
          decoration: InputDecoration(
            hintText: 'Entre un pseudo exact',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () => setState(() {}),
            ),
          ),
          onSubmitted: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),
        if (search.text.trim().isNotEmpty)
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .collection('usernames')
                .doc(search.text.trim().toLowerCase())
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Text('Aucun joueur trouvé avec ce pseudo.');
              }
              final uid = snapshot.data!.data()?['uid'] as String?;
              if (uid == FirebaseAuth.instance.currentUser?.uid) {
                return const Text('C’est ton propre pseudo !');
              }
              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .get(),
                builder: (context, player) {
                  final name = player.data?.data()?['pseudo'] ?? 'Joueur';
                  return Card(
                    color: panel,
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person),
                      ),
                      title: Text(name),
                      subtitle: const Text('Joueur SquadVibe'),
                    ),
                  );
                },
              );
            },
          ),
      ],
    );
  }
}

class SimpleTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const SimpleTab({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: purple),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(subtitle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final name = data?['pseudo'] ?? 'Joueur';
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 42,
                  backgroundColor: purple,
                  child: Icon(Icons.person, size: 48),
                ),
                const SizedBox(height: 16),
                Text(name,
                    style: const TextStyle(
                        fontSize: 25, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(user.email ?? ''),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Se déconnecter'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
