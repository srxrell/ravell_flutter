import 'package:flutter/material.dart';
import 'package:readreels/screens/profile_screen.dart';
import 'package:readreels/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:readreels/models/story.dart';
import 'package:readreels/services/comment_service.dart';
import '../models/comment.dart';

class CommentsBottomSheet extends StatefulWidget {
  final Story story;
  const CommentsBottomSheet({super.key, required this.story});

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  List<Comment> comments = [];
  final TextEditingController _commentController = TextEditingController();

  int? _currentUserId; // 🟢 ИСПРАВЛЕНО: _currentUserId
  Comment? _editingComment;

  void _goToUserProfile(int userId) {
    // 🟢 ИСПРАВЛЕНО: userId
    if (mounted) {
      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (context) => UserProfileScreen(
                profileUserId: userId,
              ), // 🟢 ИСПРАВЛЕНО: profileUserId
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId(); // 🟢 ИСПРАВЛЕНО
    _fetchComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // --- USER AUTH LOGIC ---
  Future<void> _loadCurrentUserId() async {
    // 🟢 ИСПРАВЛЕНО
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currentUserId = prefs.getInt(
          'user_id',
        ); // 🟢 ИСПРАВЛЕНО: _currentUserId
      });
    }
  }

  // --- FETCHING LOGIC ---
  Future<void> _fetchComments() async {
    try {
      final fetchedComments = await CommentService().getCommentsForStory(
        widget.story.id,
      );
      if (mounted) {
        setState(() {
          comments = fetchedComments.reversed.toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching comments: $e');
    }
  }

  // --- ADD COMMENT LOGIC ---
  Future<void> _addComment() async {
    final String commentContent = _commentController.text;

    if (commentContent.isEmpty) return;
    if (!mounted) return;

    final int? currentUserId = _currentUserId; // 🟢 ИСПРАВЛЕНО

    if (currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Для добавления комментария необходимо войти в систему.',
            ),
          ),
        );
      }
      return;
    }

    // Optimistic UI Update
    final Comment tempComment = Comment(
      id: -1,
      content: commentContent,
      username: 'You (sending...)', // 🟢 ИСПРАВЛЕНО: username
      storyId: widget.story.id,
      userId: currentUserId, // 🟢 ИСПРАВЛЕНО: userId
      createdAt: DateTime.now(),
      isEdited: false,
      avatarUrl: null, // 🟢 ИСПРАВЛЕНО: avatarUrl
    );

    if (mounted) {
      setState(() {
        comments.insert(0, tempComment);
        _commentController.clear();
      });
    }

    try {
      await CommentService().addCommentToStory(
        widget.story.id,
        currentUserId,
        commentContent,
      );
      await _fetchComments();
    } catch (e) {
      debugPrint('Exception: Failed to add comment to story $e');
      if (mounted) {
        setState(() {
          comments.remove(tempComment);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ошибка: Комментарий не был добавлен. Повторите попытку.',
            ),
          ),
        );
      }
    }
  }

  // --- DELETE COMMENT LOGIC ---
  Future<void> _deleteComment(int commentId) async {
    Navigator.of(context).pop();
    try {
      if (mounted) {
        setState(() {
          comments.removeWhere((c) => c.id == commentId);
        });
      }

      await CommentService().deleteComment(commentId);
    } catch (e) {
      debugPrint('Error deleting comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось удалить комментарий.')),
        );
        _fetchComments();
      }
    }
  }

  // --- EDITING START/SETUP LOGIC ---
  void _startEdit(Comment comment) {
    if (mounted) {
      setState(() {
        _editingComment = comment;
        _commentController.text = comment.content;
      });
      Navigator.of(context).pop();
    }
  }

  // --- UPDATE COMMENT LOGIC ---
  Future<void> _updateComment() async {
    if (_editingComment == null || _commentController.text.isEmpty) return;
    final String newContent = _commentController.text;
    final int commentId = _editingComment!.id;

    if (mounted) {
      setState(() {
        final index = comments.indexWhere((c) => c.id == commentId);
        if (index != -1) {
          comments[index] = Comment(
            id: comments[index].id,
            content: newContent,
            username: comments[index].username, // 🟢 ИСПРАВЛЕНО
            storyId: comments[index].storyId,
            userId: comments[index].userId, // 🟢 ИСПРАВЛЕНО
            createdAt: comments[index].createdAt,
            isEdited: true,
            avatarUrl: comments[index].avatarUrl, // 🟢 ИСПРАВЛЕНО
          );
          _commentController.clear();
          _editingComment = null;
        }
      });
    }

    try {
      await CommentService().updateComment(commentId, newContent);
      await _fetchComments();
    } catch (e) {
      debugPrint('Error updating comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось обновить комментарий.')),
        );
        _fetchComments();
      }
    }
  }

  // --- COMMENT OPTIONS MODAL ---
  void _showCommentOptions(Comment comment) {
    if (comment.userId != _currentUserId || comment.id == -1)
      return; // 🟢 ИСПРАВЛЕНО: userId

    showModalBottomSheet(
      barrierColor: const Color.fromARGB(153, 0, 0, 0),
      elevation: 0,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(
              top: BorderSide(color: neoBlack, width: 4),
              left: BorderSide(color: neoBlack, width: 4),
              right: BorderSide(color: neoBlack, width: 8),
              bottom: BorderSide(color: neoBlack, width: 8),
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Редактировать'),
                onTap: () => _startEdit(comment),
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Удалить',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () => _deleteComment(comment.id),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + keyboardHeight),
      decoration: const BoxDecoration(
        color: bottomBackground,
        border: Border(
          top: BorderSide(width: 3, color: Color(0xFFE19265)),
          left: BorderSide(width: 3, color: Color(0xFFE19265)),
          right: BorderSide(width: 3, color: Color(0xFFE19265)),
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child:
                comments.isEmpty
                    ? const Center(child: Text("No comments yet"))
                    : ListView.builder(
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        final isOwner =
                            comment.userId == _currentUserId; // 🟢 ИСПРАВЛЕНО

                        final bool isAvatarSet =
                            comment.avatarUrl != null &&
                            comment.avatarUrl!.isNotEmpty; // 🟢 ИСПРАВЛЕНО
                        ImageProvider? avatarImageProvider;
                        if (isAvatarSet) {
                          avatarImageProvider = NetworkImage(
                            comment.avatarUrl!,
                          ); // 🟢 ИСПРАВЛЕНО
                        }

                        return GestureDetector(
                          onLongPress:
                              isOwner
                                  ? () => _showCommentOptions(comment)
                                  : null,
                          child: ListTile(
                            leading: GestureDetector(
                              onTap:
                                  () => _goToUserProfile(
                                    comment.userId,
                                  ), // 🟢 ИСПРАВЛЕНО
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor:
                                    isAvatarSet
                                        ? Colors.transparent
                                        : Colors.blueGrey,
                                backgroundImage: avatarImageProvider,
                                child:
                                    isAvatarSet
                                        ? null
                                        : const Icon(
                                          Icons.person,
                                          size: 20,
                                          color: Colors.white,
                                        ),
                              ),
                            ),
                            subtitle: Text(
                              comment.content,
                              style: const TextStyle(fontSize: 20),
                            ),
                            title: Row(
                              children: [
                                GestureDetector(
                                  onTap:
                                      () => _goToUserProfile(
                                        comment.userId,
                                      ), // 🟢 ИСПРАВЛЕНО
                                  child: Text(
                                    comment.username ??
                                        'Unknown User', // 🟢 ИСПРАВЛЕНО
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ),
                                if (comment.isEdited)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 8.0),
                                    child: Text(
                                      ' • Изменено',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFCF875E),
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(15)),
                      borderSide: BorderSide(
                        width: 3,
                        color: Color(0xFF532910),
                      ),
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(15)),
                      borderSide: BorderSide(
                        width: 3,
                        color: Color(0xFF532910),
                      ),
                    ),
                    hintStyle: const TextStyle(color: Colors.black),
                    hintText:
                        _editingComment == null
                            ? 'Add a comment...'
                            : 'Edit comment...',
                    suffixIcon:
                        _editingComment != null
                            ? IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  _editingComment = null;
                                  _commentController.clear();
                                });
                              },
                            )
                            : null,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: Icon(
                  _editingComment == null ? Icons.send : Icons.check,
                  color: const Color(0xFF532910),
                ),
                onPressed: () async {
                  if (_editingComment == null) {
                    await _addComment();
                  } else {
                    await _updateComment();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
