// Core API endpoints for the ReadReels application
class ApiEndpoints {
  static const String baseUrl = 'https://ravell-backend-1.onrender.com';

  // Authentication
  static const String login = '/login';
  static const String register = '/register';
  static const String refreshToken = '/refresh-token';
  static const String savePlayer = '/save-player';

  // Stories
  static const String stories = '/stories';
  static const String seeds = '/stories/seeds';
  static const String branches = '/stories/branches';
  static String storyById(int id) => '/stories/$id';
  static String storyReplies(int id) => '/stories/$id/replies';
  static String storyComments(int id) => '/stories/$id/comments';
  static String storyShare(int id) => '/stories/$id/share';
  static String storyNotInterested(int id) => '/stories/$id/not-interested';

  // Users
  static String userById(int id) => '/users/$id';
  static String userProfile(int id) => '/users/$id/profile';
  static String userStories(int id) => '/users/$id/stories';
  static String userFollowers(int id) => '/users/$id/followers';
  static String userFollowing(int id) => '/users/$id/following';

  // Comments
  static const String comments = '/comments';
  static String commentById(int id) => '/comments/$id';

  // Hashtags
  static const String hashtags = '/hashtags';
  static String hashtagById(int id) => '/hashtags/$id';
  static String hashtagStories(int id) => '/hashtags/$id/stories';

  // Achievements
  static const String achievements = '/achievements';
  static String userAchievements(int userId) => '/users/$userId/achievements';

  // Activity
  static String userActivity(int userId) => '/users/$userId/activity';

  // Streak
  static String userStreak(int userId) => '/users/$userId/streak';
}
