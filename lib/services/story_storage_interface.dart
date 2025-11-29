import 'package:readreels/models/story.dart';

abstract class StoryStorageInterface {
  Future<void> saveStories(List<Story> stories);
  Future<List<Story>> readStories();
  Future<void> clearCache();
}
