import 'package:get_it/get_it.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';

import '../network/dio_client.dart';
import '../storage/hive_storage.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/story_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/achievement_repository.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/story/story_bloc.dart';
import '../../blocs/profile/profile_bloc.dart';
import '../../blocs/achievement/achievement_bloc.dart';
import '../../blocs/comment/comment_bloc.dart';

final getIt = GetIt.instance;

/// Initialize all dependencies
/// Initialize all dependencies
Future<void> setupDependencies() async {
  print('🔧 Setting up dependencies...');

  // Initialize Hive storage
  await HiveStorage.init();
  await HiveStorage.openBoxes();

  // Initialize HydratedBloc storage for state persistence
  // ИСПРАВЛЕНИЕ: Оборачиваем путь в HydratedStorageDirectory
  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: HydratedStorageDirectory(
      (await getApplicationDocumentsDirectory()).path,
    ),
  );

  // Core - Network
  getIt.registerLazySingleton<DioClient>(() => DioClient());

  // Repositories
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepository(getIt<DioClient>()),
  );

  getIt.registerLazySingleton<StoryRepository>(
    () => StoryRepository(getIt<DioClient>()),
  );

  getIt.registerLazySingleton<UserRepository>(
    () => UserRepository(getIt<DioClient>()),
  );

  getIt.registerLazySingleton<AchievementRepository>(
    () => AchievementRepository(getIt<DioClient>()),
  );

  // BLoCs - Register as factories so each screen gets a fresh instance if needed
  // or as singletons if you want to share state across the app
  getIt.registerLazySingleton<AuthBloc>(
    () => AuthBloc(authRepository: getIt<AuthRepository>()),
  );

  getIt.registerFactory<StoryBloc>(
    () => StoryBloc(storyRepository: getIt<StoryRepository>()),
  );

  getIt.registerFactory<ProfileBloc>(
    () => ProfileBloc(userRepository: getIt<UserRepository>()),
  );

  getIt.registerFactory<AchievementBloc>(
    () => AchievementBloc(achievementRepository: getIt<AchievementRepository>()),
  );

  getIt.registerFactory<CommentBloc>(
    () => CommentBloc(storyRepository: getIt<StoryRepository>()),
  );

  print('✅ Dependencies setup complete');
}


/// Dispose all dependencies (call on app dispose if needed)
Future<void> disposeDependencies() async {
  await HiveStorage.closeAll();
  await getIt.reset();
  print('🗑️ Dependencies disposed');
}
