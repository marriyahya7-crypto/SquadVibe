
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const purple = Color(0xFF9B5CFF);
const background = Color(0xFF100D19);
const panel = Color(0xFF201A2D);

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
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: purple,
          brightness: Brightness.dark,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: panel,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
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
        if (snapshot.data == null) return const LoginPage();
        return const HomePage();
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
  bool registering = false;
  bool loading = false;
  String error = '';

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    pseudo.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      loading = true;
      error = '';
    });

    try {
      final mail = email.text.trim();
      final pass = password.text;
      if (mail.isEmpty || pass.isEmpty) {
        throw Exception('Remplis ton email et ton mot de passe.');
      }

      if (registering) {
        final name = pseudo.text.trim();
        final normalized = name.toLowerCase();

        if (!RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(name)) {
          throw Exception(
            'Pseudo : 3 à 20 caractères, lettres, chiffres ou _.');
        }
        if (pass.length < 6) {
          throw Exception('Le mot de passe doit avoir 6 caractères minimum.');
        }

        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: mail,
          password: pass,
        );

        final uid = credential.user!.uid;
        final db = FirebaseFirestore.instance;

        try {
          await db.runTransaction((transaction) async {
            final usernameRef =
                db.collection('usernames').doc(normalized);
            final userRef = db.collection('users').doc(uid);
            final existing = await transaction.get(usernameRef);

            if (existing.exists) {
              throw Exception('Ce pseudo est déjà utilisé.');
            }

            transaction.set(usernameRef, {'uid': uid});
            transaction.set(userRef, {
              'uid': uid,
              'pseudo': name,
              'email': mail,
              'createdAt': FieldValue.serverTimestamp(),
            });
          });
        } catch (_) {
          await credential.user?.delete();
          rethrow;
        }
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: mail,
          password: pass,
        );
      }
    } on FirebaseAuthException catch (e) {
      error = switch (e.code) {
        'email-already-in-use' => 'Cet email possède déjà un compte.',
        'invalid-email' => 'Adresse email invalide.',
        'weak-password' => 'Mot de passe trop faible.',
        'user-not-found' => 'Aucun compte trouvé avec cet email.',
        'wrong-password' || 'invalid-credential' =>
          'Email ou mot de passe incorrect.',
        'network-request-failed' => 'Vérifie ta connexion Internet.',
        _ => e.message ?? 'Erreur de connexion.',
      };
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
      if (error.isEmpty) error = 'Une erreur est survenue.';
    } finally {
      if (mounted) setState(() => loading = false);
    }

    if (mounted && error.isNotEmpty) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.bolt, size: 76, color: purple),
                const SizedBox(height: 8),
                const Text(
                  'SquadVibe',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Ta squad. Ton univers.',
                  style: TextStyle(color: Colors.white60),
                ),
                const SizedBox(height: 32),
                if (registering) ...[
                  TextField(
                    controller: pseudo,
                    decoration: const InputDecoration(
                      labelText: 'Pseudo unique',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Adresse email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(error, style: const TextStyle(color: Colors.redAccent)),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: loading ? null : submit,
                    child: loading
                        ? const CircularProgressIndicator()
                        : Text(registering ? 'Créer mon compte' : 'Connexion'),
                  ),
                ),
                TextButton(
                  onPressed: loading
                      ? null
                      : () => setState(() {
                            registering = !registering;
                            error = '';
                          }),
                  child: Text(
                    registering
                        ? 'Déjà inscrit ? Se connecter'
                        : 'Créer un compte gratuitement',
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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selected = 0;

  final pages = const [
    DashboardTab(),
    FriendsTab(),
    MessagesTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SquadVibe ⚡',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: background,
      ),
      body: IndexedStack(index: selected, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (i) => setState(() => selected = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            label: 'Amis',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

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
            Text(
              'Salut $name 👋',
              style: const TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Retrouve tes amis et construis ta squad.',
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 24),
            _FeatureCard(
              icon: Icons.people,
              title: 'Ta communauté',
              subtitle: 'Recherche des joueurs et ajoute tes amis.',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FriendsStandalone()),
              ),
            ),
            const SizedBox(height: 14),
            const _FeatureCard(
              icon: Icons.chat,
              title: 'Messages',
              subtitle: 'L’espace pour discuter avec ta squad.',
            ),
            const SizedBox(height: 14),
            const _FeatureCard(
              icon: Icons.shield,
              title: 'SquadVibe',
              subtitle: 'Un espace gaming pour retrouver tes joueurs.',
            ),
          ],
        );
      },
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: panel,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: purple.withValues(alpha: 0.2),
          child: Icon(icon, color: purple),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(subtitle),
        ),
        onTap: onTap,
      ),
    );
  }
}

class FriendsStandalone extends StatelessWidget {
  const FriendsStandalone({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trouve ta squad')),
      body: const FriendsTab(),
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
  String notice = '';
  bool loading = false;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> sendRequest(String uid, String name) async {
    final me = FirebaseAuth.instance.currentUser!;
    if (loading) return;
    setState(() {
      loading = true;
      notice = '';
    });

    try {
      final db = FirebaseFirestore.instance;
      final myData = await db.collection('users').doc(me.uid).get();
      final myName = myData.data()?['pseudo'] ?? 'Joueur';
      final id = '${me.uid}_$uid';
      final ref = db.collection('friendRequests').doc(id);
      final existing = await ref.get();

      if (existing.exists) {
        setState(() => notice = 'Tu as déjà envoyé cette demande.');
      } else {
        await ref.set({
          'fromUid': me.uid,
          'toUid': uid,
          'fromPseudo': myName,
          'toPseudo': name,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
        setState(() => notice = 'Demande envoyée à $name !');
      }
    } catch (_) {
      setState(() => notice =
          'Envoi impossible. Les règles Firestore doivent être configurées.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> answerRequest(String id, bool accept) async {
    try {
      await FirebaseFirestore.instance
          .collection('friendRequests')
          .doc(id)
          .update({'status': accept ? 'accepted' : 'declined'});
      if (mounted) {
        setState(() {
          notice = accept ? 'Demande acceptée !' : 'Demande refusée.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => notice = 'Action impossible : vérifie les règles Firestore.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser!;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Trouve ta squad',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text('Tape le pseudo exact d’un joueur.'),
        const SizedBox(height: 16),
        TextField(
          controller: search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Pseudo du joueur',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        if (search.text.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            key: ValueKey(search.text.trim().toLowerCase()),
            future: FirebaseFirestore.instance
                .collection('usernames')
                .doc(search.text.trim().toLowerCase())
                .get(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return const Text('Erreur. Vérifie les règles Firestore.');
              }
              if (!snap.hasData || !snap.data!.exists) {
                return const Text('Aucun joueur trouvé.');
              }

              final uid = snap.data!.data()?['uid'] as String?;
              if (uid == null || uid == me.uid) {
                return const Text('C’est ton propre pseudo.');
              }

              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .get(),
                builder: (context, player) {
                  final name =
                      player.data?.data()?['pseudo'] as String? ??
                          search.text.trim();
                  return Card(
                    color: panel,
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person),
                      ),
                      title: Text(name),
                      subtitle: const Text('Joueur SquadVibe'),
                      trailing: IconButton(
                        onPressed:
                            loading ? null : () => sendRequest(uid, name),
                        icon: const Icon(Icons.person_add, color: purple),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
        if (notice.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(notice),
        ],
        const SizedBox(height: 28),
        const Text(
          'Demandes reçues',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('friendRequests')
              .where('toUid', isEqualTo: me.uid)
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return const Text(
                'Les demandes nécessitent les règles Firestore adaptées.',
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.data!.docs.isEmpty) {
              return const Text('Aucune demande pour le moment.');
            }
            return Column(
              children: snap.data!.docs.map((doc) {
                final name = doc.data()['fromPseudo'] ?? 'Joueur';
                return Card(
                  color: panel,
                  child: ListTile(
                    title: Text(name),
                    subtitle: const Text('Demande d’ami'),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          onPressed: () => answerRequest(doc.id, true),
                          icon: const Icon(Icons.check, color: Colors.green),
                        ),
                        IconButton(
                          onPressed: () => answerRequest(doc.id, false),
                          icon: const Icon(Icons.close, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class MessagesTab extends StatelessWidget {
  const MessagesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 56, color: purple),
            SizedBox(height: 14),
            Text(
              'Les messages arrivent bientôt',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'On configurera les conversations après les demandes d’amis.',
              textAlign: TextAlign.center,
            ),
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
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 42,
                  backgroundColor: purple,
                  child: Icon(Icons.person, size: 46),
                ),
                const SizedBox(height: 16),
                Text(
                  data?['pseudo'] ?? 'Joueur',
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(user.email ?? ''),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    icon: const Icon(Icons.logout),
                    label: const Text('Se déconnecter'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
