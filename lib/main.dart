
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
      title: 'SquadVibe',
      debugShowCheckedModeBanner: false,
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
  bool hidePassword = true;
  String error = '';

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    pseudo.dispose();
    super.dispose();
  }

  void showError(String message) {
    if (mounted) setState(() => error = message);
  }

  // MOT DE PASSE OUBLIE
  Future<void> resetPassword() async {
    final mail = email.text.trim();

    if (mail.isEmpty) {
      showError('Entre ton adresse email dans le champ email.');
      return;
    }

    setState(() {
      loading = true;
      error = '';
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: mail,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Si un compte correspond à cet email, '
            'un lien de récupération sera envoyé.',
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showError(
        e.code == 'invalid-email'
            ? 'Adresse email invalide.'
            : 'Envoi impossible. Vérifie ton email et réessaie.',
      );
    } catch (_) {
      showError('Erreur réseau. Réessaie.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
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
          throw Exception(
            'Le mot de passe doit avoir au moins 6 caractères.');
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
      if (e.code == 'email-already-in-use') {
        showError('Cet email possède déjà un compte.');
      } else if (e.code == 'invalid-email') {
        showError('Adresse email invalide.');
      } else if (e.code == 'weak-password') {
        showError('Mot de passe trop faible.');
      } else if (e.code == 'user-not-found') {
        showError('Aucun compte trouvé avec cet email.');
      } else if (e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        showError('Email ou mot de passe incorrect.');
      } else if (e.code == 'network-request-failed') {
        showError('Vérifie ta connexion Internet.');
      } else {
        showError(e.message ?? 'Une erreur est survenue.');
      }
    } catch (e) {
      showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
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
                    textCapitalization: TextCapitalization.none,
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
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Adresse email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: password,
                  obscureText: hidePassword,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                        () => hidePassword = !hidePassword,
                      ),
                      icon: Icon(
                        hidePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => loading ? null : submit(),
                ),

                // Le bouton apparaît uniquement en mode connexion.
                if (!registering)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: loading ? null : resetPassword,
                      child: const Text('Mot de passe oublié ?'),
                    ),
                  ),

                if (error.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],

                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: loading ? null : submit,
                    child: loading
                        ? const SizedBox(
                            height: 23,
                            width: 23,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            registering
                                ? 'Créer mon compte'
                                : 'Connexion',
                          ),
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
      body: IndexedStack(
        index: selected,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (i) {
          setState(() => selected = i);
        },
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
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const FriendsStandalone(),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            const _FeatureCard(
              icon: Icons.chat,
              title: 'Messages',
              subtitle: 'Un espace pour discuter avec ta squad.',
            ),
            const SizedBox(height: 14),
            const _FeatureCard(
              icon: Icons.shield,
              title: 'SquadVibe',
              subtitle: 'Ton espace gaming pour retrouver tes joueurs.',
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
          backgroundColor: purple.withOpacity(0.2),
          child: Icon(icon, color: purple),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
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
  bool sending = false;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> sendRequest(String uid, String name) async {
    final me = FirebaseAuth.instance.currentUser!;
    if (sending) return;

    setState(() {
      sending = true;
      notice = '';
    });

    try {
      final db = FirebaseFirestore.instance;
      final myData = await db.collection('users').doc(me.uid).get();
      final myName = myData.data()?['pseudo'] ?? 'Joueur';
      final requestId = '${me.uid}_$uid';
      final ref = db.collection('friendRequests').doc(requestId);
      final existing = await ref.get();

      if (existing.exists) {
        if (mounted) {
          setState(() => notice = 'Cette demande existe déjà.');
        }
        return;
      }

      await ref.set({
        'fromUid': me.uid,
        'toUid': uid,
        'fromPseudo': myName,
        'toPseudo': name,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => notice = 'Demande envoyée à $name !');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => notice =
              'Envoi impossible. Vérifie les règles Firestore.',
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> answerRequest(String id, bool accept) async {
    final me = FirebaseAuth.instance.currentUser!;

    try {
      final ref = FirebaseFirestore.instance
          .collection('friendRequests')
          .doc(id);

      final request = await ref.get();
      if (!request.exists || request.data()?['toUid'] != me.uid) {
        throw Exception('Demande introuvable.');
      }

      await ref.update({
        'status': accept ? 'accepted' : 'declined',
      });

      if (mounted) {
        setState(() {
          notice = accept
              ? 'Demande acceptée !'
              : 'Demande refusée.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => notice =
              'Action impossible. Vérifie les règles Firestore.',
        );
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
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text('Recherche un joueur avec son pseudo exact.'),
        const SizedBox(height: 16),
        TextField(
          controller: search,
          autocorrect: false,
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
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (snap.hasError) {
                return const Text(
                  'Erreur de recherche. Vérifie Firestore.',
                );
              }

              if (!snap.hasData || !snap.data!.exists) {
                return const Text('Aucun joueur trouvé.');
              }

              final uid = snap.data!.data()?['uid'] as String?;

              if (uid == null || uid == me.uid) {
                return const Text('C’est ton propre pseudo.');
              }

              return FutureBuilder<
                  DocumentSnapshot<Map<String, dynamic>>>(
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
                        tooltip: 'Ajouter',
                        onPressed: sending
                            ? null
                            : () => sendRequest(uid, name),
                        icon: const Icon(
                          Icons.person_add,
                          color: purple,
                        ),
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
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
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
                'Configure les règles Firestore pour afficher les demandes.',
              );
            }

            if (!snap.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
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
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline),
                    ),
                    title: Text(name),
                    subtitle: const Text('Demande d’ami'),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          tooltip: 'Accepter',
                          onPressed: () => answerRequest(doc.id, true),
                          icon: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Refuser',
                          onPressed: () => answerRequest(doc.id, false),
                          icon: const Icon(
                            Icons.cancel,
                            color: Colors.redAccent,
                          ),
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
            Icon(
              Icons.chat_bubble_outline,
              size: 56,
              color: purple,
            ),
            SizedBox(height: 14),
            Text(
              'Messages',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Les conversations privées seront ajoutées ensuite.',
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
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                    },
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
