
import 'package:flutter/material.dart';

void main() {
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
        scaffoldBackgroundColor: const Color(0xFF10111A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B5CF6),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  String myStatus = 'En ligne';

  final List<String> friends = [];
  final TextEditingController friendController =
      TextEditingController();
  final TextEditingController messageController =
      TextEditingController();
  final List<String> messages = [];

  @override
  void dispose() {
    friendController.dispose();
    messageController.dispose();
    super.dispose();
  }

  void addFriend() {
    friendController.clear();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ajouter un ami'),
        content: TextField(
          controller: friendController,
          autofocus: true,
          maxLength: 25,
          decoration: const InputDecoration(
            labelText: 'Pseudo ou code ami',
            hintText: 'Exemple : Yahya123',
            prefixIcon: Icon(Icons.person_add_alt_1),
          ),
          onSubmitted: (_) {
            saveFriend(dialogContext);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => saveFriend(dialogContext),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void saveFriend(BuildContext dialogContext) {
    final name = friendController.text.trim();

    if (name.isEmpty) return;

    if (friends.any(
      (friend) => friend.toLowerCase() == name.toLowerCase(),
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cet ami est déjà dans ta liste.')),
      );
      return;
    }

    setState(() {
      friends.add(name);
    });

    Navigator.pop(dialogContext);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name ajouté à ta liste !')),
    );
  }

  void sendMessage() {
    final message = messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      messages.add(message);
      messageController.clear();
    });
  }

  Widget homeContent() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 12),
        const Text(
          'SQUADVIBE',
          style: TextStyle(
            color: Color(0xFFA78BFA),
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ta squad. Ton univers.',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6D28D9), Color(0xFF312E81)],
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.groups_rounded, size: 35),
              const SizedBox(height: 12),
              const Text('MA SQUAD'),
              const SizedBox(height: 5),
              Text(
                '${friends.length} ami(s)',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: addFriend,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Ajouter un ami'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF4C1D95),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        const Text(
          'Mon statut',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: ['En ligne', 'En jeu', 'Absent', 'Invisible'].map((s) {
            return ChoiceChip(
              label: Text(s),
              selected: myStatus == s,
              onSelected: (_) => setState(() => myStatus = s),
            );
          }).toList(),
        ),
        const SizedBox(height: 25),
        const Text(
          'Mes amis',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (friends.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Aucun ami pour le moment. '
              'Appuie sur « Ajouter un ami » pour commencer.',
              textAlign: TextAlign.center,
            ),
          ),
        ...friends.map(
          (friend) => Card(
            color: const Color(0xFF1C1D2B),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF312E81),
                child: Text(friend[0].toUpperCase()),
              ),
              title: Text(friend),
              subtitle: const Text('Ami ajouté sur cet appareil'),
              trailing: IconButton(
                icon: const Icon(Icons.person_remove_outlined),
                tooltip: 'Supprimer',
                onPressed: () {
                  setState(() => friends.remove(friend));
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget chatContent() {
    return Column(
      children: [
        const ListTile(
          title: Text(
            'Chat de la squad',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          subtitle: Text('Messages locaux de démonstration'),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: messages.map((message) {
              return Align(
                alignment: Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6D28D9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(message),
                ),
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    hintText: 'Écrire un message...',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => sendMessage(),
                ),
              ),
              IconButton(
                onPressed: sendMessage,
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: tab == 0 ? homeContent() : chatContent(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (index) {
          setState(() => tab = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_rounded),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_rounded),
            label: 'Chat',
          ),
        ],
      ),
    );
  }
}
