import 'package:shared_preferences/shared_preferences.dart';
import '../models/draft_story.dart';

class DraftService {
  static const _key = 'story_drafts';

  Future<List<DraftStory>> getDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    return DraftStory.decode(raw);
  }

  Future<void> saveDraft(DraftStory draft) async {
    final prefs = await SharedPreferences.getInstance();
    final drafts = await getDrafts();

    drafts.removeWhere((d) => d.id == draft.id);
    drafts.add(draft);

    await prefs.setString(_key, DraftStory.encode(drafts));
  }

  Future<void> deleteDraft(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final drafts = await getDrafts();
    drafts.removeWhere((d) => d.id == id);
    await prefs.setString(_key, DraftStory.encode(drafts));
  }
}
