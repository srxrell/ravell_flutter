import 'package:flutter/material.dart';
import 'package:readreels/services/influencer_service.dart';
import 'package:readreels/services/auth_service.dart';
import '../models/influencer.dart';
import 'package:readreels/managers/settings_manager.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:readreels/widgets/early_access_bottom.dart';

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
    final settings = Provider.of<SettingsManager>(context);
    return Scaffold(
      appBar: AppBar(title:  Text(settings.translate('influence_list'))),
      
      body: FutureBuilder<List<Influencer>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text(settings.translate('error_loading')));
          }

          final influencers = snapshot.data ?? [];

          if (influencers.isEmpty) {
            return Center(
              child: Text(
                settings.translate('early_contributors_here'),
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
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[200],
                        border: Border.all(color: Colors.black, width: 1),
                      ),
                      child: inf.resolvedAvatar != null
                          ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: inf.resolvedAvatar!,
                                fit: BoxFit.cover,
                                httpHeaders: const {
                                  'User-Agent': 'FlutterApp/1.0',
                                },
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                errorWidget: (context, url, error) => Center(
                                  child: Text(
                                    inf.username[0].toUpperCase(),
                                    style:  TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                inf.username[0].toUpperCase(),
                                style:  TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
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
                                style:  TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (inf.isEarly) ...[
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () => EarlyAccessSheet.show(context),
                                  child: const Icon(Icons.star, color: Colors.amber, size: 16),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('${inf.featureDescription}'),
                        ],
                      ),
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
        title:  Text('Add Early Influencer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: usernameController,
              decoration:  InputDecoration(
                labelText: 'Username',
                hintText: 'Enter username to add',
              ),
            ),
             SizedBox(height: 10),
            TextField(
              controller: ideaController,
              decoration:  InputDecoration(
                labelText: 'Idea / Contribution',
                hintText: 'What did they do?',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:  Text('Cancel'),
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
            child:  Text('Add'),
          ),
        ],
      ),
    );
  }
}
