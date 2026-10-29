
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const purple = Color(0xFF9B5CFF);
const background = Color(0xFF100D19);
const panel = Color(0xFF201A2D);
const muted = Color(0xFFAAA1BB);

// Keeps the login screen mounted while signup cleanup is in progress.
final ValueNotifier<bool> accountCreationInProgress = ValueNotifier<bool>(false);

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
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: panel,
          hintStyle: const TextStyle(color: muted),
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

// L'authentification décide toujours de l'écran à afficher.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: accountCreationInProgress,
      builder: (context, isCreatingAccount, child) {
        if (isCreatingAccount) return const LoginScreen();

        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingScreen();
            }

            final user = snapshot.data;

            if (user == null) return const LoginScreen();
            return HomeScreen(key: ValueKey(user.uid));
          },
        );
      },
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: purple),
      ),
    );
  }
}

class Brand extends StatelessWidget {
  const Brand({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Icon(Icons.bolt, color: purple, size: 58),
        SizedBox(height: 6),
        Text(
          'SQUADVIBE',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'Ta squad, tes amis, ton univers.',
          style: TextStyle(color: muted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  bool createAccount = false;
  bool showPassword = false;

  final username = TextEditingController();

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    username.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (loading) return;

    final mail = email.text.trim().toLowerCase();
    final pass = password.text;
    final pseudo = username.text.trim();

    if (mail.isEmpty ||
        !mail.contains('@') ||
        pass.isEmpty ||
        (createAccount && pseudo.isEmpty)) {
      showMessage('Remplis correctement tous les champs.');
      return;
    }

    if (createAccount && pass.length < 6) {
      showMessage('Le mot de passe doit contenir au moins 6 caractères.');
      return;
    }

    setState(() => loading = true);
    if (createAccount) accountCreationInProgress.value = true;

    UserCredential? credential;
    bool createdAuthAccount = false;

    try {
      if (createAccount) {
        final normalized = pseudo.toLowerCase();

        if (!RegExp(r'^[a-zA-Z0-9_.]{3,20}$').hasMatch(pseudo)) {
          throw Exception(
            'Pseudo : 3 à 20 caractères, lettres, chiffres, _ ou .',
          );
        }

        credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: mail,
          password: pass,
        );

        createdAuthAccount = true;

        final user = credential.user!;

        // Read the username only after authentication, as Firestore rules require auth.
        final existingUsername = await FirebaseFirestore.instance
            .collection('usernames')
            .doc(normalized)
            .get();
        if (existingUsername.exists) {
          throw Exception('Ce pseudo est déjà utilisé.');
        }

        // Le pseudo et le profil sont créés ensemble.
        // Deux inscriptions ne peuvent pas réserver le même pseudo.
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final db = FirebaseFirestore.instance;
          final usernameRef = db.collection('usernames').doc(normalized);
          final userRef = db.collection('users').doc(user.uid);

          final usernameSnapshot = await transaction.get(usernameRef);
          final userSnapshot = await transaction.get(userRef);

          if (usernameSnapshot.exists) {
            throw Exception('Ce pseudo est déjà utilisé.');
          }

          if (userSnapshot.exists) {
            throw Exception('Ce profil existe déjà.');
          }

          transaction.set(usernameRef, {
            'uid': user.uid,
            'username': pseudo,
            'createdAt': FieldValue.serverTimestamp(),
          });

          transaction.set(userRef, {
            'uid': user.uid,
            'username': pseudo,
            'usernameLower': normalized,
            'email': mail,
            'bio': '',
            'friends': <String>[],
            'createdAt': FieldValue.serverTimestamp(),
          });
        });

        if (mounted) {
          showMessage('Compte créé avec succès !');
        }
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: mail,
          password: pass,
        );
      }

      // Ne pas naviguer manuellement vers l'accueil :
      // AuthGate suit l'état réel de Firebase.
    } on FirebaseAuthException catch (e) {
      if (createdAuthAccount && credential?.user != null) {
        try {
          await credential!.user!.delete();
        } catch (_) {
          // Si la suppression échoue, ne pas masquer l'erreur initiale.
        }
      }

      if (e.code == 'email-already-in-use') {
        showMessage('Cette adresse possède déjà un compte.');
      } else if (e.code == 'invalid-credential' ||
          e.code == 'wrong-password' ||
          e.code == 'user-not-found') {
        showMessage('Adresse e-mail ou mot de passe incorrect.');
      } else if (e.code == 'weak-password') {
        showMessage('Choisis un mot de passe plus sécurisé.');
      } else {
        showMessage('Erreur Firebase : ${e.message ?? e.code}');
      }
    } catch (e) {
      // Si la création du profil échoue après celle du compte,
      // on tente de supprimer le compte incomplet.
      if (createdAuthAccount && credential?.user != null) {
        try {
          await credential!.user!.delete();
        } catch (_) {}
      }

      showMessage(
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (createAccount) accountCreationInProgress.value = false;
      if (mounted) setState(() => loading = false);
    }
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  const Brand(),
                  const SizedBox(height: 42),
                  Text(
                    createAccount
                        ? 'Rejoins ta squad.'
                        : 'Content de te revoir.',
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (createAccount) ...[
                    TextField(
                      controller: username,
                      textCapitalization: TextCapitalization.none,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.person_outline),
                        hintText: 'Pseudo unique',
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.email_outlined),
                      hintText: 'Adresse e-mail',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: password,
                    obscureText: !showPassword,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline),
                      hintText: 'Mot de passe',
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => showPassword = !showPassword,
                        ),
                        icon: Icon(
                          showPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: purple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: loading ? null : submit,
                      child: loading
                          ? const CircularProgressIndicator()
                          : Text(
                              createAccount
                                  ? 'Créer mon compte'
                                  : 'Se connecter',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: loading
                        ? null
                        : () => setState(
                              () => createAccount = !createAccount,
                            ),
                    child: Text(
                      createAccount
                          ? 'J’ai déjà un compte'
                          : 'Créer un compte',
                      style: const TextStyle(color: purple),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    // AuthGate affichera automatiquement l'écran de connexion.
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final pseudo = data?['username'] as String? ??
            user.displayName ??
            user.email?.split('@').first ??
            'Joueur';

        final pages = <Widget>[
          HomeContent(username: pseudo),
          const FriendsPage(),
          const MessagesPage(),
          const NitroContent(),
          ProfileContent(
            username: pseudo,
            email: user.email ?? '',
            onSignOut: signOut,
          ),
        ];

        return Scaffold(
          appBar: AppBar(
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt, color: purple),
                SizedBox(width: 8),
                Text(
                  'SQUADVIBE',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: IndexedStack(
              index: selectedIndex,
              children: pages,
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) {
              setState(() => selectedIndex = index);
            },
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
                icon: Icon(Icons.chat_bubble_outline),
                selectedIcon: Icon(Icons.chat_bubble),
                label: 'Messages',
              ),
              NavigationDestination(
                icon: Icon(Icons.workspace_premium_outlined),
                selectedIcon: Icon(Icons.workspace_premium),
                label: 'Nitro',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profil',
              ),
            ],
          ),
        );
      },
    );
  }
}

class HomeContent extends StatelessWidget {
  final String username;
  const HomeContent({super.key, required this.username});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final contacts = FirebaseFirestore.instance.collection('friends').doc(user.uid).collection('contacts');
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFB06CFF), Color(0xFF6C35D7), Color(0xFF32176E)]),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: purple.withValues(alpha: 0.22), blurRadius: 24, offset: const Offset(0, 10))],
          ),
          child: Stack(children: [
            const Positioned(right: -8, top: -10, child: Icon(Icons.bolt, size: 100, color: Color(0x33FFFFFF))),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.17), borderRadius: BorderRadius.circular(30)), child: const Text('⚡ TON UNIVERS, TA SQUAD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1))),
              const SizedBox(height: 18),
              Text('Salut $username 👋', style: const TextStyle(fontSize: 27, height: 1.1, fontWeight: FontWeight.w900)),
              const SizedBox(height: 9),
              const Text('Retrouve tes amis et fais vivre ta squad.', style: TextStyle(color: Color(0xFFECE0FF), fontSize: 14)),
              const SizedBox(height: 20),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: contacts.snapshots(),
                builder: (context, snap) {
                  final count = snap.data?.docs.length ?? 0;
                  final label = count.toString() + (count == 1 ? ' ami dans ta squad' : ' amis dans ta squad');
                  return Row(children: [const Icon(Icons.people_alt_rounded, size: 18), const SizedBox(width: 7), Text(label, style: const TextStyle(fontWeight: FontWeight.w700))]);
                },
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 26),
        const Text('À TOI DE JOUER', style: TextStyle(color: muted, letterSpacing: 1.8, fontWeight: FontWeight.w800, fontSize: 12)),
        const SizedBox(height: 13),
        Row(children: [
          Expanded(child: _QuickAction(icon: Icons.person_add_alt_1_rounded, title: 'Ajouter', subtitle: 'Trouve tes amis', color: const Color(0xFF9B5CFF), onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ouvre l’onglet Amis pour rechercher un pseudo.'))))),
          const SizedBox(width: 12),
          Expanded(child: _QuickAction(icon: Icons.workspace_premium_rounded, title: 'Nitro', subtitle: 'Passe au niveau +', color: const Color(0xFFFFC857), onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Découvre SquadVibe Nitro dans l’onglet Nitro.'))))),
        ]),
        const SizedBox(height: 26),
        const Text('TON ESPACE', style: TextStyle(color: muted, letterSpacing: 1.8, fontWeight: FontWeight.w800, fontSize: 12)),
        const SizedBox(height: 13),
        const FeatureTile(icon: Icons.people_alt_outlined, title: 'Ta squad, toujours proche', subtitle: 'Ajoute tes amis avec leur pseudo unique et accepte les demandes reçues.'),
        const FeatureTile(icon: Icons.chat_bubble_outline_rounded, title: 'Des conversations privées', subtitle: 'Lance une discussion avec les amis que tu as acceptés.'),
        const FeatureTile(icon: Icons.workspace_premium_outlined, title: 'Personnalise ton expérience', subtitle: 'Découvre les avantages prévus pour SquadVibe Nitro.'),
        const SizedBox(height: 8),
        Center(child: Text('SquadVibe • créé pour ta squad 💜', style: TextStyle(color: muted.withValues(alpha: 0.75), fontSize: 12))),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: panel,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color)),
            const SizedBox(height: 15),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: muted, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}

class FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const FeatureTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: purple.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: purple, size: 30),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(subtitle, style: const TextStyle(color: muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PlaceholderPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const PlaceholderPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: purple, size: 58),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(color: muted)),
          ],
        ),
      ),
    );
  }
}

class ProfileContent extends StatelessWidget {
  final String username;
  final String email;
  final Future<void> Function() onSignOut;

  const ProfileContent({
    super.key,
    required this.username,
    required this.email,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.account_circle, color: purple, size: 100),
        const SizedBox(height: 12),
        Text(
          username,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          email,
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted),
        ),
        const SizedBox(height: 30),
        const Text(
          'Informations du compte',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 14),
        ListTile(
          tileColor: panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: const Icon(Icons.person_outline, color: purple),
          title: const Text('Pseudo'),
          subtitle: Text(username),
        ),
        const SizedBox(height: 12),
        ListTile(
          tileColor: panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: const Icon(Icons.email_outlined, color: purple),
          title: const Text('E-mail'),
          subtitle: Text(email),
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.redAccent,
            padding: const EdgeInsets.all(16),
          ),
          onPressed: onSignOut,
          icon: const Icon(Icons.logout),
          label: const Text('Se déconnecter'),
        ),
      ],
    );
  }
}

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});
  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final search = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void notice(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> sendRequest() async {
    if (busy) return;
    final typed = search.text.trim();
    final normalized = typed.toLowerCase();
    if (typed.isEmpty) { notice('Entre le pseudo de ton ami.'); return; }
    setState(() => busy = true);
    try {
      final me = FirebaseAuth.instance.currentUser!;
      final db = FirebaseFirestore.instance;
      final usernameDoc = await db.collection('usernames').doc(normalized).get();
      if (!usernameDoc.exists) { notice('Aucun compte trouvé avec ce pseudo.'); return; }
      final usernameData = usernameDoc.data()!;
      final targetUid = usernameData['uid'] as String?;
      final targetName = usernameData['username'] as String? ?? typed;
      if (targetUid == null || targetUid == me.uid) {
        notice(targetUid == me.uid ? 'Tu ne peux pas t’ajouter toi-même.' : 'Profil invalide.');
        return;
      }
      final contact = await db.collection('friends').doc(me.uid).collection('contacts').doc(targetUid).get();
      if (contact.exists) { notice('Vous êtes déjà amis.'); return; }

      final requestId = '${me.uid}_$targetUid';
      final reverseId = '${targetUid}_${me.uid}';
      final requestRef = db.collection('friendRequests').doc(requestId);
      final reverseRef = db.collection('friendRequests').doc(reverseId);
      final existing = await requestRef.get();
      if (existing.exists && existing.data()?['status'] == 'pending') { notice('Demande déjà envoyée.'); return; }
      final reverse = await reverseRef.get();
      if (reverse.exists && reverse.data()?['status'] == 'pending') {
        notice('Cette personne t’a déjà envoyé une demande. Regarde les demandes reçues.');
        return;
      }
      await requestRef.set({
        'senderUid': me.uid,
        'receiverUid': targetUid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      search.clear();
      notice('Demande envoyée à $targetName !');
    } catch (_) {
      notice('Envoi impossible : vérifie les règles Firestore.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> respond(String requestId, String otherUid, bool accept) async {
    try {
      final me = FirebaseAuth.instance.currentUser!;
      final db = FirebaseFirestore.instance;
      final requestRef = db.collection('friendRequests').doc(requestId);
      if (accept) {
        final batch = db.batch();
        batch.update(requestRef, {'status': 'accepted'});
        batch.set(db.collection('friends').doc(me.uid).collection('contacts').doc(otherUid), {
          'uid': otherUid,
          'requestId': requestId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        batch.set(db.collection('friends').doc(otherUid).collection('contacts').doc(me.uid), {
          'uid': me.uid,
          'requestId': requestId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await batch.commit();
        notice('Demande acceptée !');
      } else {
        await requestRef.update({'status': 'declined'});
        notice('Demande refusée.');
      }
    } catch (_) {
      notice('Action impossible : vérifie les règles Firestore.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser!;
    final db = FirebaseFirestore.instance;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text('TES AMIS', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('Recherche un pseudo pour envoyer une demande.', style: TextStyle(color: muted)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: TextField(
            controller: search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => sendRequest(),
            decoration: const InputDecoration(hintText: 'Pseudo de ton ami', prefixIcon: Icon(Icons.search)),
          )),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: busy ? null : sendRequest,
            icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.person_add_alt_1),
          ),
        ]),
        const SizedBox(height: 24),
        const Text('DEMANDES REÇUES', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db.collection('friendRequests').where('receiverUid', isEqualTo: me.uid).snapshots(),
          builder: (context, snap) {
            if (snap.hasError) return const Text('Demandes indisponibles : vérifie les règles Firestore.', style: TextStyle(color: muted));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: purple));
            final docs = snap.data!.docs.where((d) => d.data()['status'] == 'pending').toList();
            if (docs.isEmpty) return const Text('Aucune demande reçue.', style: TextStyle(color: muted));
            return Column(children: docs.map((doc) {
              final senderUid = doc.data()['senderUid'] as String? ?? '';
              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: db.collection('users').doc(senderUid).get(),
                builder: (context, userSnap) {
                  final senderName = userSnap.data?.data()?['username'] as String? ?? 'Joueur';
                  return Card(color: panel, child: ListTile(
                    leading: const CircleAvatar(backgroundColor: purple, child: Icon(Icons.person)),
                    title: Text(senderName),
                    subtitle: const Text('Demande d’ami'),
                    trailing: Wrap(spacing: 0, children: [
                      IconButton(onPressed: () => respond(doc.id, senderUid, true), icon: const Icon(Icons.check_circle, color: Colors.green)),
                      IconButton(onPressed: () => respond(doc.id, senderUid, false), icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent)),
                    ]),
                  ));
                },
              );
            }).toList());
          },
        ),
        const SizedBox(height: 24),
        const Text('MA LISTE D’AMIS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db.collection('friends').doc(me.uid).collection('contacts').snapshots(),
          builder: (context, snap) {
            if (snap.hasError) return const Text('Liste d’amis indisponible : vérifie les règles Firestore.', style: TextStyle(color: muted));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: purple));
            final docs = snap.data!.docs;
            if (docs.isEmpty) return const Text('Tes amis acceptés apparaîtront ici.', style: TextStyle(color: muted));
            return Column(children: docs.map((doc) {
              final friendUid = doc.data()['uid'] as String? ?? doc.id;
              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: db.collection('users').doc(friendUid).get(),
                builder: (context, friendSnap) {
                  final friendName = friendSnap.data?.data()?['username'] as String? ?? 'Joueur';
                  return Card(color: panel, child: ListTile(
                    leading: const CircleAvatar(backgroundColor: purple, child: Icon(Icons.person)),
                    title: Text(friendName),
                    subtitle: const Text('Ami SquadVibe'),
                  ));
                },
              );
            }).toList());
          },
        ),
      ],
    );
  }
}

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Padding(
    padding: EdgeInsets.all(28),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.chat_bubble_outline, color: purple, size: 58),
      SizedBox(height: 16),
      Text('MESSAGES', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
      SizedBox(height: 8),
      Text('La messagerie privée sera activée après validation des règles Firestore.', textAlign: TextAlign.center, style: TextStyle(color: muted)),
    ]),
  ));
}

class NitroContent extends StatelessWidget {
  const NitroContent({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFD978), Color(0xFFB46CFF), Color(0xFF5829B8)]),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(30)), child: const Text('✦ SQUADVIBE NITRO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.3))),
            const SizedBox(height: 20),
            const Text('Ta squad,\nton style.', style: TextStyle(fontSize: 34, height: 1.05, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            const Text('Une expérience plus personnalisée, pensée pour toi.', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 20),
            const Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('1,99 €', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
              Padding(padding: EdgeInsets.only(bottom: 5, left: 5), child: Text('/ mois', style: TextStyle(fontWeight: FontWeight.w600))),
            ]),
          ]),
        ),
        const SizedBox(height: 24),
        const Text('LES AVANTAGES NITRO', style: TextStyle(color: muted, letterSpacing: 1.6, fontWeight: FontWeight.w800, fontSize: 12)),
        const SizedBox(height: 12),
        const _NitroBenefit(icon: Icons.palette_outlined, title: 'Thèmes exclusifs', subtitle: 'Personnalise les couleurs de ton espace.'),
        const _NitroBenefit(icon: Icons.workspace_premium_outlined, title: 'Badge Nitro', subtitle: 'Un badge spécial sur ton profil.'),
        const _NitroBenefit(icon: Icons.auto_awesome_outlined, title: 'Profil mis en avant', subtitle: 'Affiche ton style dans la communauté.'),
        const _NitroBenefit(icon: Icons.bolt_outlined, title: 'Accès aux nouveautés', subtitle: 'Découvre les prochaines options en avant-première.'),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Nitro arrive bientôt ✨'),
              content: const Text('L’offre et son prix sont présentés ici, mais le paiement n’est pas encore activé. Rien ne sera prélevé.'),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Compris'))],
            ),
          ),
          style: FilledButton.styleFrom(backgroundColor: purple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
          icon: const Icon(Icons.lock_clock_outlined),
          label: const Text('Bientôt disponible', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 10),
        const Text('Aucun paiement actif pour le moment. Le prix affiché est une proposition.', textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 11)),
      ],
    );
  }
}

class _NitroBenefit extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _NitroBenefit({required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(19), border: Border.all(color: purple.withValues(alpha: 0.15))),
    child: Row(children: [
      Container(width: 45, height: 45, decoration: BoxDecoration(color: purple.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: purple)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: muted, fontSize: 12)),
      ])),
      const Icon(Icons.check_circle, color: Color(0xFF7DDBA3), size: 19),
    ]),
  );
}
