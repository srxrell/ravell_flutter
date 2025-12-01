import 'dart:io' if (dart.library.html) 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:readreels/screens/add_story.dart';
import 'package:readreels/screens/subscribers_list.dart';
import 'package:readreels/screens/user_story_feed_screen.dart';
import 'package:readreels/services/auth_service.dart';
import 'package:readreels/services/story_service.dart';
import 'package:readreels/theme.dart';
import 'package:readreels/widgets/neowidgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:readreels/services/subscription_service.dart';
import 'edit_profile.dart';
import 'package:readreels/models/story.dart';
import 'package:readreels/widgets/bottom_nav_bar_liquid.dart' as p;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

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
  XFile? _avatarXFile;
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

    String? filePath;
    List<int>? fileBytes;
    String? fileName;

    if (_avatarXFile != null) {
      if (kIsWeb) {
        fileBytes = await _avatarXFile!.readAsBytes();
        fileName = _avatarXFile!.name;
      } else {
        filePath = _avatarXFile!.path;
      }
    } else if (widget.initialUserData['avatar'] != null &&
        _initialAvatarUrl == null) {
      dataToUpdate['avatar'] = '';
    }

    try {
      final response = await _subscriptionService.updateProfileWithImage(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        bio: '',
        avatarFilePath: filePath,
        avatarFileBytes: fileBytes,
        avatarFileName: fileName,
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
      return FutureBuilder<Uint8List>(
        future: _avatarXFile!.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.hasData) {
            imageProvider = MemoryImage(snapshot.data!);
            return _buildAvatarWidget(imageProvider, false);
          }
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
                  print('🟢 КНОПКА НАЖАТА! isSaving = $_isSaving');
                  if (!_isSaving) {
                    _saveProfile();
                  } else {
                    print('⏳ Уже сохраняется, ждем...');
                  }
                },
                type: NeoButtonType.login,
                text: _isSaving ? 'Сохранение...' : 'Сохранить изменения',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
