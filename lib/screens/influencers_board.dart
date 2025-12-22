import 'package:flutter/material.dart';
import 'package:readreels/services/influencer_service.dart';
import 'package:readreels/services/auth_service.dart';
import '../models/influencer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InfluencersBoard extends StatefulWidget {
  const InfluencersBoard({super.key});

  @override
  State<InfluencersBoard> createState() => _InfluencersBoardState();
}

class _InfluencersBoardState extends State<InfluencersBoard> {
  late Future<List<Influencer>> future;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    future = _loadInfluencers();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    String? username = prefs.getString('username');

    if (username == null) {
      print('Username is null, reloading user profile...');
      await AuthService().loadAndSaveUserProfile();
      username = prefs.getString('username');
    }

    print('================ DEBUG ADMIN CHECK ================');
    print('Stored username: "$username"');
    if (username == 'serellvorne' && mounted) {
      print('User IS admin. Enabling button.');
      setState(() {
        _isAdmin = true;
      });
    } else {
      print('User is NOT admin.');
    }
  }

  Future<List<Influencer>> _loadInfluencers() async {
    final auth = AuthService();
    final token = await auth.getAccessToken();

    if (token == null) {
      throw Exception('User not authorized');
    }

    final service = InfluencersService(
      baseUrl: AuthService.baseUrl,
      token: token,
    );

    return service.getEarlyInfluencers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ранние участники')),
      floatingActionButton: _isAdmin
          ? FloatingActionButton(
              onPressed: _showAddInfluencerDialog,
              child: const Icon(Icons.add),
            )
          : null,
      body: FutureBuilder<List<Influencer>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Ошибка загрузки'));
          }

          final influencers = snapshot.data ?? [];

          if (influencers.isEmpty) {
            return const Center(
              child: Text(
                'Ранние участники появятся здесь',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: influencers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final inf = influencers[index];

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundImage:
                          inf.avatar != null ? NetworkImage(inf.avatar!) : null,
                      child:
                          inf.avatar == null
                              ? Text(inf.username[0].toUpperCase())
                              : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                inf.username,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (inf.isEarly) ...[
                                const SizedBox(width: 6),
                                const Text(
                                  'EARLY',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('${inf.storyCount} stories'),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // позже
                      },
                      child: Text(inf.isFollowing ? 'Following' : 'Follow'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }


  void _showAddInfluencerDialog() {
    final usernameController = TextEditingController();
    final ideaController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Early Influencer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                hintText: 'Enter username to add',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ideaController,
              decoration: const InputDecoration(
                labelText: 'Idea / Contribution',
                hintText: 'What did they do?',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement backend call
              print('Adding influencer: ${usernameController.text}, Idea: ${ideaController.text}');
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Request sent (Backend pending)')),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
