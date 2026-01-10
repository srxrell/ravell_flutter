import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/storage/hive_storage.dart';
import '../../models/story.dart';
import '../../models/comment.dart';
import '../../models/hashtag.dart';

/// Repository for story operations with offline-first caching
class StoryRepository {
  final DioClient _dioClient;

  StoryRepository(this._dioClient);

  Box get _storiesBox => HiveStorage.getStoriesBox();

  /// Get all stories with cache-first strategy
  Future<List<Story>> getStories({bool forceRefresh = false}) async {
    try {
      // Try to fetch from network
      final response = await _dioClient.dio.get(ApiEndpoints.stories);

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> storiesJson = data is Map ? (data['stories'] ?? []) : data;

        final stories = storiesJson.map((json) => Story.fromJson(json)).toList();

        // Cache stories
        await _cacheStories(stories);

        print('✅ Fetched ${stories.length} stories from network');
        return stories;
      }

      throw Exception('Failed to load stories');
    } on DioException catch (e) {
      print('⚠️ Network error: ${e.message}. Loading from cache...');
      // Load from cache on network error
      return _getCachedStories();
    }
  }

  /// Get seeds (stories without replies)
  Future<List<Story>> getSeeds() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.seeds);

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> storiesJson = data is Map ? (data['stories'] ?? []) : data;
        return storiesJson.map((json) => Story.fromJson(json)).toList();
      }

      throw Exception('Failed to load seeds');
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Failed to load seeds');
    }
  }

  /// Get branches (stories with replies)
  Future<List<Story>> getBranches() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.branches);

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> storiesJson = data is Map ? (data['stories'] ?? []) : data;
        return storiesJson.map((json) => Story.fromJson(json)).toList();
      }

      throw Exception('Failed to load branches');
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Failed to load branches');
    }
  }

  /// Get single story by ID
  Future<Story> getStory(int id) async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.storyById(id));

      if (response.statusCode == 200) {
        final story = Story.fromJson(response.data);

        // Cache individual story
        await _storiesBox.put('story_$id', story.toJson());

        return story;
      }

      throw Exception('Failed to load story');
    } on DioException catch (e) {
      // Try to load from cache
      final cached = _storiesBox.get('story_$id');
      if (cached != null) {
        print('⚠️ Loading story $id from cache');
        return Story.fromJson(Map<String, dynamic>.from(cached));
      }
      throw Exception(e.message ?? 'Failed to load story');
    }
  }

  /// Get replies for a story
  Future<List<Story>> getRepliesForStory(int storyId) async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.storyReplies(storyId));

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> storiesJson = data is Map ? (data['stories'] ?? []) : data;
        return storiesJson.map((json) => Story.fromJson(json)).toList();
      }

      throw Exception('Failed to load replies');
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Failed to load replies');
    }
  }

  /// Create a new story
  Future<Story> createStory({
    required String title,
    required String content,
    required List<int> hashtagIds,
    int? replyTo,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.stories,
        data: {
          'title': title,
          'content': content,
          'hashtag_ids': hashtagIds,
          if (replyTo != null) 'reply_to': replyTo,
        },
      );

      if (response.statusCode == 201) {
        final story = Story.fromJson(response.data);
        print('✅ Story created successfully');
        return story;
      }

      throw Exception('Failed to create story');
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Failed to create story');
    }
  }

  /// Update an existing story
  Future<Story> updateStory({
    required int storyId,
    required String title,
    required String content,
    required List<int> hashtagIds,
  }) async {
    try {
      final response = await _dioClient.dio.put(
        ApiEndpoints.storyById(storyId),
        data: {
          'title': title,
          'content': content,
          'hashtag_ids': hashtagIds,
        },
      );

      if (response.statusCode == 200) {
        return Story.fromJson(response.data);
      }

      throw Exception('Failed to update story');
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Failed to update story');
    }
  }

  /// Delete a story
  Future<void> deleteStory(int id) async {
    try {
      final response = await _dioClient.dio.delete(ApiEndpoints.storyById(id));

      if (response.statusCode == 200 || response.statusCode == 204) {
        // Remove from cache
        await _storiesBox.delete('story_$id');
        print('✅ Story deleted successfully');
        return;
      }

      throw Exception('Failed to delete story');
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Failed to delete story');
    }
  }

  /// Share a story
  Future<void> shareStory(int id) async {
    try {
      final response = await _dioClient.dio.post(ApiEndpoints.storyShare(id));

      if (response.statusCode == 200) {
        print('✅ Story shared successfully');
        return;
      }

      throw Exception('Failed to share story');
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Failed to share story');
    }
  }

  /// Mark story as not interested
  Future<void> markStoryAsNotInterested(int storyId) async {
    try {
      await _dioClient.dio.post(ApiEndpoints.storyNotInterested(storyId));
      print('✅ Story marked as not interested');
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Failed to mark story');
    }
  }

  /// Search stories
  Future<List<Story>> searchStories(String searchTerm) async {
    try {
      final response = await _dioClient.dio.get(
        ApiEndpoints.stories,
        queryParameters: {'search': searchTerm},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> storiesJson = data is Map ? (data['stories'] ?? []) : data;
        return storiesJson.map((json) => Story.fromJson(json)).toList();
      }

      throw Exception('Failed to search stories');
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Failed to search stories');
    }
  }

  /// Get stories by hashtag
  Future<List<Story>> getStoriesByHashtag(int hashtagId) async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.hashtagStories(hashtagId));

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> storiesJson = data is Map ? (data['stories'] ?? []) : data;
        return storiesJson.map((json) => Story.fromJson(json)).toList();
      }

      throw Exception('Failed to load hashtag stories');
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Failed to load hashtag stories');
    }
  }

  /// Get user stories
  Future<List<Story>> getUserStories(int userId) async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.userStories(userId));

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> storiesJson = data is Map ? (data['stories'] ?? []) : data;
        return storiesJson.map((json) => Story.fromJson(json)).toList();
      }

      throw Exception('Failed to load user stories');
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Failed to load user stories');
    }
  }

  /// Get comments for a story
  Future<List<Comment>> getCommentsForStory(int storyId) async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.storyComments(storyId));

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> commentsJson = data is Map ? (data['comments'] ?? []) : data;
        return commentsJson.map((json) => Comment.fromJson(json)).toList();
      }

      throw Exception('Failed to load comments');
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Failed to load comments');
    }
  }

  /// Create a comment on a story
  Future<Comment> createComment({
    required int storyId,
    required String content,
    int? parentCommentId,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.comments,
        data: {
          'story_id': storyId,
          'content': content,
          if (parentCommentId != null) 'parent_comment_id': parentCommentId,
        },
      );

      if (response.statusCode == 201) {
        return Comment.fromJson(response.data);
      }

      throw Exception('Failed to create comment');
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Failed to create comment');
    }
  }

  /// Get all hashtags
  Future<List<Hashtag>> getHashtags() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.hashtags);

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> hashtagsJson = data is Map ? (data['hashtags'] ?? []) : data;
        return hashtagsJson.map((json) => Hashtag.fromJson(json)).toList();
      }

      throw Exception('Failed to load hashtags');
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Failed to load hashtags');
    }
  }

  /// Create a new hashtag
  Future<Hashtag> createHashtag(String name) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.hashtags,
        data: {'name': name},
      );

      if (response.statusCode == 201) {
        return Hashtag.fromJson(response.data);
      }

      throw Exception('Failed to create hashtag');
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Failed to create hashtag');
    }
  }

  // ========== CACHING METHODS ==========

  /// Cache stories to Hive
  Future<void> _cacheStories(List<Story> stories) async {
    try {
      final storiesMap = {
        for (var story in stories) 'story_${story.id}': story.toJson()
      };
      await _storiesBox.putAll(storiesMap);

      // Also save a list of all story IDs for quick retrieval
      final storyIds = stories.map((s) => s.id).toList();
      await _storiesBox.put('all_story_ids', storyIds);

      print('💾 Cached ${stories.length} stories');
    } catch (e) {
      print('⚠️ Failed to cache stories: $e');
    }
  }

  /// Get cached stories
  List<Story> _getCachedStories() {
    try {
      final storyIds = _storiesBox.get('all_story_ids') as List?;

      if (storyIds == null || storyIds.isEmpty) {
        print('⚠️ No cached stories found');
        return [];
      }

      final stories = <Story>[];
      for (var id in storyIds) {
        final cached = _storiesBox.get('story_$id');
        if (cached != null) {
          stories.add(Story.fromJson(Map<String, dynamic>.from(cached)));
        }
      }

      print('💾 Loaded ${stories.length} stories from cache');
      return stories;
    } catch (e) {
      print('⚠️ Failed to load cached stories: $e');
      return [];
    }
  }

  /// Clear all cached stories
  Future<void> clearCache() async {
    await _storiesBox.clear();
    print('🗑️ Story cache cleared');
  }
}
