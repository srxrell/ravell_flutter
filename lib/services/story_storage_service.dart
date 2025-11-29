// lib/services/story_storage_service.dart

// 1. Экспортируем интерфейс. Это гарантирует, что StoryStorageInterface будет виден.
export 'story_storage_interface.dart';

// 2. УСЛОВНЫЙ ЭКСПОРТ: Этот синтаксис выбирает, какой из двух файлов-реализаций
// будет использоваться и экспортироваться.
// dart.library.js активен только в Web. Если его нет (Mobile/Desktop),
// используется io-реализация.

export './story_storage_io.dart'
    if (dart.library.js) './story_storage_web.dart';

// Файл story_storage_io.dart (или story_storage_web.dart) должен содержать
// определение функции: StoryStorageInterface createStoryStorage() => ...;
