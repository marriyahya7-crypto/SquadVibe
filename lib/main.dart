
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const purple = Color(0xFF9B5CFF);
const background = Color(0xFF100D19);
const panel = Color(0xFF201A2D);

final db = FirebaseFirestore.instance;
final auth = FirebaseAuth.instance;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const SquadVibeApp());
}

String chatIdFor(String a, String b) {
  final ids = [a, b]..sort();
  return '${ids[0]}_${ids[1]}';
}

void notice(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
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
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: panel,
          indicatorColor: Color(0xFF42266A),
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
      stream: auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data == null
            ? const LoginPage()
            : const HomePage();
      },
    );
  }
}

// -------------------- CONNEXION / INSCRIPTION --------------------

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

  Future<void> resetPassword() async {
    final mail = email.text.trim();
    if (mail.isEmpty) {
      setState(() => error = 'Entre ton adresse email.');
      return;
    }

    setState(() {
      loading = true;
      error = '';
    });

    try {
      await auth.sendPasswordResetEmail(email: mail);
      if (mounted) {
        notice(context, 'Si le compte existe, un email sera envoyé.');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => error = e.code == 'invalid-email'
            ? 'Adresse email invalide.'
            : 'Impossible d’envoyer le lien. Réessaie.');
      }
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
            'Pseudo de 3 à 20 caractères : lettres, chiffres ou _.');
        }
        if (pass.length < 6) {
          throw Exception('Mot de passe : 6 caractères minimum.');
        }

        final credential = await auth.createUserWithEmailAndPassword(
          email: mail,
          password: pass,
        );

        final uid = credential.user!.uid;

        try {
          await db.runTransaction((tx) async {
            final usernameRef = db.collection('usernames').doc(normalized);
            final userRef = db.collection('users').doc(uid);
            final existing = await tx.get(usernameRef);

            if (existing.exists) {
              throw Exception('Ce pseudo est déjà utilisé.');
            }

            tx.set(usernameRef, {'uid': uid});
            tx.set(userRef, {
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
        await auth.signInWithEmailAndPassword(
          email: mail,
          password: pass,
        );
      }
    } on FirebaseAuthException catch (e) {
      final messages = {
        'email-already-in-use': 'Cet email possède déjà un compte.',
        'invalid-email': 'Adresse email invalide.',
        'weak-password': 'Mot de passe trop faible.',
        'user-not-found': 'Aucun compte trouvé avec cet email.',
        'wrong-password': 'Email ou mot de passe incorrect.',
        'invalid-credential': 'Email ou mot de passe incorrect.',
        'network-request-failed': 'Vérifie ta connexion Internet.',
      };
      if (mounted) {
        setState(() => error = messages[e.code] ?? 'Erreur : ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
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
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Ta squad. Ton univers.',
                  style: TextStyle(color: Colors.white60),
                ),
                const SizedBox(height: 32),
                if (registering) ...[
                  TextField(
                    controller: pseudo,
                    autocorrect: false,
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
                      onPressed: () =>
                          setState(() => hidePassword = !hidePassword),
                      icon: Icon(hidePassword
                          ? Icons.visibility
                          : Icons.visibility_off),
                    ),
                  ),
                  onSubmitted: (_) {
                    if (!loading) submit();
                  },
                ),
                if (!registering)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: loading ? null : resetPassword,
                      child: const Text('Mot de passe oublié ?'),
                    ),
                  ),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 12),
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
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
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
                  child: Text(registering
                      ? 'Déjà inscrit ? Se connecter'
                      : 'Créer un compte gratuitement'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------- NAVIGATION PRINCIPALE --------------------

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selected = 0;

  @override
  Widget build(BuildContext context) {
    const pages = [
      DashboardTab(),
      FriendsTab(),
      MessagesTab(),
      ProfileTab(),
    ];

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
    final me = auth.currentUser!;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: db.collection('users').doc(me.uid).snapshots(),
      builder: (context, snapshot) {
        final name = snapshot.data?.data()?['pseudo'] ?? 'Joueur';

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Salut $name 👋',
              style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Retrouve tes amis et discute avec ta squad.',
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 24),
            const _FeatureCard(
              icon: Icons.people,
              title: 'Ta communauté',
              subtitle: 'Recherche des joueurs et ajoute tes amis.',
            ),
            const SizedBox(height: 14),
            const _FeatureCard(
              icon: Icons.chat,
              title: 'Messages privés',
              subtitle: 'Discute en direct avec tes amis.',
            ),
            const SizedBox(height: 14),
            const _FeatureCard(
              icon: Icons.shield,
              title: 'SquadVibe',
              subtitle: 'Ton espace pour retrouver tes joueurs.',
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

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
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
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(subtitle),
        ),
      ),
    );
  }
}

// -------------------- AMIS ET DEMANDES --------------------

class FriendsTab extends StatefulWidget {
  const FriendsTab({super.key});

  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> {
  final search = TextEditingController();
  String noticeText = '';
  bool sending = false;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> sendRequest(String targetUid) async {
    final me = auth.currentUser!;
    if (sending) return;

    if (targetUid == me.uid) {
      setState(() => noticeText = 'Tu ne peux pas t’ajouter toi-même.');
      return;
    }

    setState(() {
      sending = true;
      noticeText = '';
    });

    try {
      final outgoingId = '${me.uid}_$targetUid';
      final incomingId = '${targetUid}_${me.uid}';
      final outgoing = db.collection('friendRequests').doc(outgoingId);
      final incoming = db.collection('friendRequests').doc(incomingId);

      final results = await Future.wait([outgoing.get(), incoming.get()]);
      if (results[0].exists || results[1].exists) {
        throw Exception('Une demande existe déjà ou a déjà été traitée.');
      }

      await outgoing.set({
        'senderUid': me.uid,
        'receiverUid': targetUid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) setState(() => noticeText = 'Demande envoyée !');
    } catch (e) {
      if (mounted) {
        setState(() => noticeText =
            e.toString().contains('Exception:')
                ? e.toString().replaceFirst('Exception: ', '')
                : 'Envoi impossible. Vérifie les règles Firestore.');
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> answerRequest(
    QueryDocumentSnapshot<Map<String, dynamic>> request,
    bool accept,
  ) async {
    final me = auth.currentUser!;
    final data = request.data();
    final senderUid = data['senderUid'] as String?;

    if (senderUid == null) return;

    try {
      if (!accept) {
        await request.reference.update({'status': 'declined'});
        if (mounted) notice(context, 'Demande refusée.');
        return;
      }

      await db.runTransaction((tx) async {
        final requestRef = request.reference;
        final freshRequest = await tx.get(requestRef);

        if (!freshRequest.exists ||
            freshRequest.data()?['receiverUid'] != me.uid ||
            freshRequest.data()?['status'] != 'pending') {
          throw Exception('Cette demande n’est plus disponible.');
        }

        final meRef = db.collection('users').doc(me.uid);
        final senderRef = db.collection('users').doc(senderUid);
        final meSnap = await tx.get(meRef);
        final senderSnap = await tx.get(senderRef);

        final myName = meSnap.data()?['pseudo'] ?? 'Joueur';
        final senderName = senderSnap.data()?['pseudo'] ?? 'Joueur';

        tx.update(requestRef, {'status': 'accepted'});

        tx.set(
          db.collection('friends').doc(me.uid)
              .collection('contacts').doc(senderUid),
          {
            'uid': senderUid,
            'pseudo': senderName,
            'createdAt': FieldValue.serverTimestamp(),
          },
        );

        tx.set(
          db.collection('friends').doc(senderUid)
              .collection('contacts').doc(me.uid),
          {
            'uid': me.uid,
            'pseudo': myName,
            'createdAt': FieldValue.serverTimestamp(),
          },
        );
      });

      if (mounted) notice(context, 'Ami ajouté !');
    } catch (_) {
      if (mounted) {
        notice(context, 'Action impossible. Vérifie les règles Firestore.');
      }
    }
  }

  void openChat(String uid, String pseudo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(peerUid: uid, peerPseudo: pseudo),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = auth.currentUser!;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Trouve ta squad',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
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
            future: db.collection('usernames')
                .doc(search.text.trim().toLowerCase()).get(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return const Text('Erreur de recherche Firestore.');
              }
              if (!snap.hasData || !snap.data!.exists) {
                return const Text('Aucun joueur trouvé.');
              }

              final uid = snap.data!.data()?['uid'] as String?;
              if (uid == null || uid == me.uid) {
                return const Text('C’est ton propre pseudo.');
              }

              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: db.collection('users').doc(uid).get(),
                builder: (context, player) {
                  final name = player.data?.data()?['pseudo'] as String?
                      ?? search.text.trim();

                  return Card(
                    color: panel,
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person),
                      ),
                      title: Text(name),
                      subtitle: const Text('Joueur SquadVibe'),
                      trailing: IconButton(
                        onPressed: sending ? null : () => sendRequest(uid),
                        icon: const Icon(Icons.person_add, color: purple),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
        if (noticeText.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(noticeText),
        ],
        const SizedBox(height: 28),
        const Text(
          'Demandes reçues',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db.collection('friendRequests')
              .where('receiverUid', isEqualTo: me.uid)
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return const Text('Erreur des demandes. Vérifie Firestore.');
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.data!.docs.isEmpty) {
              return const Text('Aucune demande pour le moment.');
            }

            return Column(
              children: snap.data!.docs.map((request) {
                final senderUid = request.data()['senderUid'] as String;
                return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: db.collection('users').doc(senderUid).get(),
                  builder: (context, userSnap) {
                    final name =
                        userSnap.data?.data()?['pseudo'] ?? 'Joueur';
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
                              onPressed: () => answerRequest(request, true),
                              icon: const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Refuser',
                              onPressed: () => answerRequest(request, false),
                              icon: const Icon(
                                Icons.cancel,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 28),
        const Text(
          'Mes amis',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db.collection('friends').doc(me.uid)
              .collection('contacts').snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return const Text('Erreur lors du chargement des amis.');
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.data!.docs.isEmpty) {
              return const Text('Tes amis apparaîtront ici après acceptation.');
            }

            return Column(
              children: snap.data!.docs.map((doc) {
                final data = doc.data();
                final uid = data['uid'] as String? ?? doc.id;
                final name = data['pseudo'] as String? ?? 'Joueur';

                return Card(
                  color: panel,
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person, color: purple),
                    ),
                    title: Text(name),
                    subtitle: const Text('Ami'),
                    trailing: IconButton(
                      tooltip: 'Envoyer un message',
                      icon: const Icon(Icons.chat_bubble, color: purple),
                      onPressed: () => openChat(uid, name),
                    ),
                    onTap: () => openChat(uid, name),
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

// -------------------- LISTE DES CONVERSATIONS --------------------

class MessagesTab extends StatelessWidget {
  const MessagesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final me = auth.currentUser!;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('chats')
          .where('members', arrayContains: me.uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Impossible de charger les messages. Vérifie Firestore.'),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 56, color: purple),
                  SizedBox(height: 14),
                  Text(
                    'Aucune conversation',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Ajoute un ami, puis appuie sur son icône de message.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final docs = [...snap.data!.docs];
        docs.sort((a, b) {
          final aTime = a.data()['updatedAt'] as Timestamp?;
          final bTime = b.data()['updatedAt'] as Timestamp?;
          return (bTime?.millisecondsSinceEpoch ?? 0)
              .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
        });

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Messages',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
              ),
            ),
            ...docs.map((doc) {
              final data = doc.data();
              final names = Map<String, dynamic>.from(
                data['memberNames'] ?? {},
              );
              final otherUid = (data['members'] as List)
                  .cast<String>()
                  .firstWhere((id) => id != me.uid, orElse: () => '');
              final name = names[otherUid] ?? 'Conversation';

              return Card(
                color: panel,
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person, color: purple),
                  ),
                  title: Text(name.toString()),
                  subtitle: Text(
                    (data['lastMessage'] as String?) ?? 'Démarrer la discussion',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatPage(
                          peerUid: otherUid,
                          peerPseudo: name.toString(),
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

// -------------------- CONVERSATION PRIVÉE EN TEMPS RÉEL --------------------

class ChatPage extends StatefulWidget {
  final String peerUid;
  final String peerPseudo;

  const ChatPage({
    super.key,
    required this.peerUid,
    required this.peerPseudo,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final input = TextEditingController();
  final scroll = ScrollController();
  bool loading = true;
  bool sending = false;
  String? failure;

  User get me => auth.currentUser!;
  String get conversationId => chatIdFor(me.uid, widget.peerUid);
  DocumentReference<Map<String, dynamic>> get chatRef =>
      db.collection('chats').doc(conversationId);

  @override
  void initState() {
    super.initState();
    prepareChat();
  }

  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> prepareChat() async {
    try {
      final myProfile = await db.collection('users').doc(me.uid).get();
      final myName = myProfile.data()?['pseudo'] ?? 'Joueur';
      final existing = await chatRef.get();

      if (!existing.exists) {
        final members = [me.uid, widget.peerUid]..sort();
        await chatRef.set({
          'members': members,
          'memberNames': {
            me.uid: myName,
            widget.peerUid: widget.peerPseudo,
          },
          'lastMessage': '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final data = existing.data()!;
        final members = List<String>.from(data['members'] ?? []);
        if (!members.contains(me.uid) || !members.contains(widget.peerUid)) {
          throw Exception('Conversation non autorisée.');
        }
      }
    } catch (_) {
      failure = 'Impossible d’ouvrir la conversation. Vérifie les règles Firestore.';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> sendMessage() async {
    final text = input.text.trim();
    if (text.isEmpty || sending || failure != null) return;
    if (text.length > 2000) {
      notice(context, 'Message trop long : 2 000 caractères maximum.');
      return;
    }

    setState(() => sending = true);
    input.clear();

    try {
      final batch = db.batch();
      final messageRef = chatRef.collection('messages').doc();

      batch.set(messageRef, {
        'senderUid': me.uid,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.update(chatRef, {
        'lastMessage': text,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scroll.hasClients) {
            scroll.animateTo(
              0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (_) {
      input.text = text;
      if (mounted) {
        notice(context, 'Message non envoyé. Vérifie les règles Firestore.');
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(
              radius: 17,
              child: Icon(Icons.person, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.peerPseudo,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: background,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : failure != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(failure!, textAlign: TextAlign.center),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: chatRef.collection('messages')
                            .orderBy('createdAt', descending: true)
                            .limit(200)
                            .snapshots(),
                        builder: (context, snap) {
                          if (snap.hasError) {
                            return const Center(
                              child: Text('Erreur de chargement des messages.'),
                            );
                          }
                          if (!snap.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snap.data!.docs.isEmpty) {
                            return const Center(
                              child: Text('Envoie le premier message 👋'),
                            );
                          }

                          return ListView.builder(
                            controller: scroll,
                            reverse: true,
                            padding: const EdgeInsets.all(16),
                            itemCount: snap.data!.docs.length,
                            itemBuilder: (context, index) {
                              final message = snap.data!.docs[index].data();
                              final mine = message['senderUid'] == me.uid;
                              final time = message['createdAt'] as Timestamp?;
                              final timeText = time == null
                                  ? ''
                                  : '${time.toDate().hour.toString().padLeft(2, '0')}:'
                                    '${time.toDate().minute.toString().padLeft(2, '0')}';

                              return Align(
                                alignment: mine
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.78,
                                  ),
                                  margin: const EdgeInsets.symmetric(vertical: 5),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: mine ? purple : panel,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(message['text'] ?? ''),
                                      if (timeText.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          timeText,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: input,
                                minLines: 1,
                                maxLines: 5,
                                maxLength: 2000,
                                decoration: const InputDecoration(
                                  hintText: 'Écris un message...',
                                  counterText: '',
                                ),
                                onSubmitted: (_) => sendMessage(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: sending ? null : sendMessage,
                              icon: sending
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

// -------------------- PROFIL --------------------

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = auth.currentUser!;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: db.collection('users').doc(user.uid).snapshots(),
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
                      await auth.signOut();
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
