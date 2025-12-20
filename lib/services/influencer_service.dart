import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/influencer.dart';

class InfluencersService {
  final String baseUrl;
  final String token;

  InfluencersService({required this.baseUrl, required this.token});

  Future<List<Influencer>> getEarlyInfluencers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/influencers/early'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load influencers');
    }

    final data = json.decode(response.body);

    final List list = data['influencers'] ?? [];
    return list.map((e) => Influencer.fromJson(e)).toList();
  }
}
