import 'dart:io' if (dart.library.html) 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:readreels/services/subscription_service.dart';
import 'package:readreels/theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:readreels/widgets/neowidgets.dart'; // Используем kIsWeb отсюда

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> initialUserData;
  final Function(Map<String, dynamic>) onProfileUpdated;

  const EditProfileScreen({
    super.key,
    required this.initialUserData,
    required this.onProfileUpdated,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final SubscriptionService _subscriptionService = SubscriptionService();
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;

  bool _isSaving = false;
  XFile? _avatarXFile; // Используем XFile для кросс-платформенности
  String? _initialAvatarUrl;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.initialUserData['username'],
    );
    _emailController = TextEditingController(
      text: widget.initialUserData['email'],
    );
    _firstNameController = TextEditingController(
      text: widget.initialUserData['first_name'] ?? '',
    );
    _lastNameController = TextEditingController(
      text: widget.initialUserData['last_name'] ?? '',
    );
    _initialAvatarUrl = widget.initialUserData['avatar'];
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatarImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );

    if (pickedFile != null && mounted) {
      setState(() {
        _avatarXFile = pickedFile;
      });
    }
  }

  void _clearAvatar() {
    setState(() {
      _avatarXFile = null;
      _initialAvatarUrl = null;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final dataToUpdate = <String, String>{
      'username': _usernameController.text,
      'email': _emailController.text,
      'first_name': _firstNameController.text,
      'last_name': _lastNameController.text,
    };

    // Параметры для загрузки файла
    String? filePath;
    List<int>? fileBytes;
    String? fileName;

    if (_avatarXFile != null) {
      // ✅ ИСПРАВЛЕНО: Используем kIsWeb для надежного определения Web-платформы
      if (kIsWeb) {
        // --- Логика для Web: получаем байты и имя ---
        fileBytes = await _avatarXFile!.readAsBytes();
        fileName = _avatarXFile!.name;
        // Если вы на Web, path будет недоступен, поэтому filePath = null
      } else {
        // --- Логика для Mobile/Desktop: получаем путь ---
        filePath = _avatarXFile!.path;
      }
    } else if (widget.initialUserData['avatar'] != null &&
        _initialAvatarUrl == null) {
      // Сигнал для бэкенда удалить файл
      dataToUpdate['avatar'] = '';
    }

    try {
      final response = await _subscriptionService.updateProfileWithImage(
        dataToUpdate,
        avatarFilePath: filePath,
        avatarFileBytes:
            fileBytes, // Теперь эти поля гарантированно заполнены для Web
        avatarFileName:
            fileName, // Теперь эти поля гарантированно заполнены для Web
      );

      if (response.containsKey('username') && response['username'] is List ||
          response.containsKey('detail')) {
        final errorDetail =
            response['detail'] ??
            (response.values.first is List
                ? response.values.first[0]
                : 'Неизвестная ошибка валидации');
        _showErrorSnackbar('Ошибка валидации: $errorDetail');
      } else {
        widget.onProfileUpdated(response);
        Navigator.of(context).pop();
        _showSuccessSnackbar("Профиль успешно обновлен!");
      }
    } catch (e) {
      _showErrorSnackbar('Ошибка: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.black)),
        backgroundColor: Colors.greenAccent,
      ),
    );
  }

  Widget _buildAvatarSection() {
    ImageProvider? imageProvider;

    if (_avatarXFile != null) {
      // Если выбран новый файл, используем FutureBuilder для безопасной загрузки байтов (для Web)
      return FutureBuilder<Uint8List>(
        future: _avatarXFile!.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.hasData) {
            imageProvider = MemoryImage(snapshot.data!);
            return _buildAvatarWidget(imageProvider, false);
          }
          // Показываем заглушку, пока ждем данные
          return _buildAvatarWidget(null, true);
        },
      );
    } else if (_initialAvatarUrl != null) {
      imageProvider = NetworkImage(_initialAvatarUrl!);
    }

    return _buildAvatarWidget(
      imageProvider,
      _avatarXFile == null && _initialAvatarUrl == null,
    );
  }

  Widget _buildAvatarWidget(ImageProvider? imageProvider, bool isPlaceholder) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Set up your persona",
                style: neoTextStyle(30, weight: FontWeight.bold),
              ),
              Text(
                "Make an avatar to continue",
                style: neoTextStyle(17, weight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: _pickAvatarImage,
              child: Container(
                width: 200,
                height: 200,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  border: Border(
                    top: BorderSide(color: neoBlack, width: 4),
                    left: BorderSide(color: neoBlack, width: 4),
                    right: BorderSide(color: neoBlack, width: 8),
                    bottom: BorderSide(color: neoBlack, width: 8),
                  ),
                ),
                child:
                    isPlaceholder
                        ? const Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person, size: 60),
                            Text("Upload avatar"),
                          ],
                        )
                        : ClipRRect(
                          child: Image(
                            image: imageProvider!,
                            fit: BoxFit.cover,
                            width: 120,
                            height: 120,
                            errorBuilder:
                                (context, error, stackTrace) => const Icon(
                                  Icons.error_outline,
                                  size: 60,
                                  color: Colors.red,
                                ),
                          ),
                        ),
              ),
            ),
            const SizedBox(height: 10),
            if (_avatarXFile != null || _initialAvatarUrl != null)
              NeoIconButton(
                type: NeoButtonType.white,
                onPressed: _clearAvatar,
                icon: const Icon(Icons.close, color: Colors.red),
                child: const Text(
                  'Очистить',
                  style: TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAvatarSection(),

              // Поле Имя пользователя
              TextFormField(
                controller: _usernameController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите имя пользователя';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Поле Email
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите email';
                  }
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                    return 'Введите корректный email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Поле Имя
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(hintText: 'Введите имя'),
              ),
              const SizedBox(height: 16),

              // Поле Фамилия
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(hintText: 'Введите фамилию'),
              ),
              const SizedBox(height: 16),

              // Кнопка сохранения
              NeoButton(
                onPressed: () {
                  if (_isSaving != null) {
                    _saveProfile();
                  }
                },
                type: NeoButtonType.login,
                text: _isSaving ? 'Сохранение...' : 'Сохранить изменения',
              ),
            ],
          ),
        ),
      ),
      // bottomNavigationBar: const PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASS(),
    );
  }
}
