
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

  final List<Map<String, dynamic>> friends = [
    {'name': 'Alex', 'game': 'En jeu', 'online': true},
    {'name': 'Yanis', 'game': 'Disponible', 'online': true},
    {'name': 'Mehdi', 'game': 'Absent', 'online': false},
    {'name': 'Sam', 'game': 'En jeu', 'online': true},
  ];

  final List<String> messages = [];
  final TextEditingController controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void summonFriends() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📣 Appeler la squad'),
        content: const Text(
          'Ta demande est prête ! '
          'Les notifications réelles seront ajoutées plus tard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  Widget homeContent() {
    final online = friends.where((f) => f['online'] == true).length;

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
              const Text(
                'MA SQUAD',
                style: TextStyle(fontSize: 13, letterSpacing: 2),
              ),
              const SizedBox(height: 5),
              Text(
                '$online amis en ligne',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: summonFriends,
                  icon: const Icon(Icons.campaign_rounded),
                  label: const Text('Appeler la squad'),
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
          'Tes amis',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ...friends.map((friend) {
          final isOnline = friend['online'] as bool;
          return Card(
            color: const Color(0xFF1C1D2B),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF312E81),
                child: Text(friend['name'][0]),
              ),
              title: Text(friend['name'] as String),
              subtitle: Text(friend['game'] as String),
              trailing: Icon(
                Icons.circle,
                size: 11,
                color: isOnline ? Colors.greenAccent : Colors.grey,
              ),
            ),
          );
        }),
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
          subtitle: Text('Discussion locale de démonstration'),
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
                  controller: controller,
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

  void sendMessage() {
    final message = controller.text.trim();
    if (message.isEmpty) return;
    setState(() {
      messages.add(message);
      controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: tab == 0 ? homeContent() : chatContent(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (index) => setState(() => tab = index),
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
