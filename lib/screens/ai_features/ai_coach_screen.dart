import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:menstrual_health_ai/constants/app_colors.dart';
import 'package:menstrual_health_ai/constants/text_styles.dart';
import 'package:menstrual_health_ai/models/user_data.dart';
import 'package:menstrual_health_ai/providers/user_data_provider.dart';
import 'package:menstrual_health_ai/providers/auth_provider.dart';
import 'package:menstrual_health_ai/services/ai_service.dart';
import 'package:menstrual_health_ai/services/api_service.dart';
import 'package:menstrual_health_ai/widgets/custom_app_bar.dart';
import 'package:provider/provider.dart';

class AiCoachScreen extends StatefulWidget {
  const AiCoachScreen({super.key});

  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  bool _isLoadingHistory = true;
  final AIService _aiService = AIService();

  // Chat messages and history
  final List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _chatHistory = [];
  String? _currentChatId;

  // Suggested questions
  final List<String> _suggestedQuestions = [
    "How can I manage my ovulation symptoms?",
    "What foods should I eat during my period?",
    "Why am I feeling more tired than usual?",
    "How can I reduce period pain naturally?",
    "What exercise is best during my luteal phase?",
  ];

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    try {
      setState(() {
        _isLoadingHistory = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        print('❌ No current user found');
        setState(() {
          _isLoadingHistory = false;
        });
        _addInitialGreeting();
        return;
      }

      print('🔄 Loading chat history for user: ${currentUser.id}');

      // Updated API call to use GET /ai/chat with userId parameter
      final response = await ApiService.getChatHistory(
        userId: currentUser.id,
      );

      if (response != null && response['success'] == true) {
        final data = response['data'] as List<dynamic>;

        setState(() {
          _chatHistory = data.cast<Map<String, dynamic>>();
        });

        if (data.isNotEmpty) {
          // Load the most recent chat conversation
          final chatData = data.first;
          _loadChatMessages(chatData);
        } else {
          // No existing chat history, add initial greeting
          _addInitialGreeting();
        }
      } else {
        print('❌ Failed to load chat history or no history exists');
        _addInitialGreeting();
      }
    } catch (e) {
      print('❌ Error loading chat history: $e');
      _addInitialGreeting();
    } finally {
      setState(() {
        _isLoadingHistory = false;
      });
    }
  }

  void _loadChatMessages(Map<String, dynamic> chatData) {
    _currentChatId = chatData['id'];
    final messages = chatData['messages'] as List<dynamic>;

    setState(() {
      _messages.clear();
      for (final msg in messages) {
        _messages.add({
          'isUser': msg['role'] == 'user',
          'message': msg['content'],
          'timestamp': DateTime.parse(msg['timestamp']),
          'id': msg['id'],
        });
      }
    });

    print('✅ Loaded ${_messages.length} messages from chat');
  }

  void _addInitialGreeting() async {
    final userData =
        Provider.of<UserDataProvider>(context, listen: false).userData;

    setState(() {
      _isTyping = true;
    });

    String greeting =
        "Hello! I'm your Mimos Uterinos AI health coach. How can I help you today?";

    if (userData != null) {
      greeting =
          "Hello ${userData.name}! I'm your Mimos Uterinos AI health coach. I'm here to provide personalized insights based on your cycle data. How can I help you today?";
    }

    // Simulate AI typing delay
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _messages.add({
        'isUser': false,
        'message': greeting,
        'timestamp': DateTime.now(),
      });
      _isTyping = false;
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    final userData =
        Provider.of<UserDataProvider>(context, listen: false).userData;

    if (currentUser == null) {
      setState(() {
        _messages.add({
          'isUser': false,
          'message': "Please log in to continue chatting with me.",
          'timestamp': DateTime.now(),
        });
      });
      return;
    }

    setState(() {
      // Add user message
      _messages.add({
        'isUser': true,
        'message': message,
        'timestamp': DateTime.now(),
      });

      // Clear input field
      _messageController.clear();

      // Show typing indicator
      _isTyping = true;
    });

    // Scroll to bottom
    _scrollToBottom();

    try {
      print('🔄 Sending message to server API...');

      // Updated API call with correct parameters
      final response = await ApiService.sendChatMessage(
        userId: currentUser.id,
        message: message,
        chatId: _currentChatId, // Pass chatId as parameter
      );

      if (response != null && response['success'] == true) {
        // Server API response successful
        final chatData = response['data'];
        _currentChatId = chatData['id'];

        final messages = chatData['messages'] as List<dynamic>;
        final lastMessage = messages.last;

        if (lastMessage['role'] == 'assistant') {
          setState(() {
            _isTyping = false;

            // Add server AI response
            _messages.add({
              'isUser': false,
              'message': lastMessage['content'],
              'timestamp': DateTime.parse(lastMessage['timestamp']),
              'id': lastMessage['id'],
            });
          });

          print('✅ Received server AI response');

          // Refresh chat history (but don't reload current messages)
          _loadChatHistoryOnly();
        }
      } else {
        throw Exception('Server API failed, falling back to local AI');
      }
    } catch (e) {
      print('⚠️ Server API failed, using local AI service: $e');

      try {
        // Fallback to local AI service
        if (userData != null) {
          final localResponse = await _aiService.generateCoachResponse(
            message,
            userData,
          );

          setState(() {
            _isTyping = false;

            // Add local AI response
            _messages.add({
              'isUser': false,
              'message': localResponse,
              'timestamp': DateTime.now(),
            });
          });

          print('✅ Received local AI response');
        } else {
          throw Exception('No user data available for local AI');
        }
      } catch (localError) {
        print('❌ Both server and local AI failed: $localError');

        setState(() {
          _isTyping = false;

          // Add error message
          _messages.add({
            'isUser': false,
            'message':
                "I'm sorry, I'm having trouble connecting to my knowledge base right now. Please check your internet connection and try again later.",
            'timestamp': DateTime.now(),
          });
        });
      }
    }

    // Scroll to bottom after response
    _scrollToBottom();
  }

  Future<void> _loadChatHistoryOnly() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      if (currentUser == null) return;

      final response = await ApiService.getChatHistory(
        userId: currentUser.id,
      );

      if (response != null && response['success'] == true) {
        final data = response['data'] as List<dynamic>;

        setState(() {
          _chatHistory = data.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      print('❌ Error loading chat history only: $e');
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _startNewChat() {
    setState(() {
      _messages.clear();
      _currentChatId = null;
    });
    _addInitialGreeting();
    Navigator.pop(context); // Close drawer
  }

  void _loadChatFromHistory(Map<String, dynamic> chatData) {
    _loadChatMessages(chatData);
    Navigator.pop(context); // Close drawer
  }

  void _clearCurrentChat() async {
    if (_currentChatId == null) {
      // Clear local messages only
      setState(() {
        _messages.clear();
      });
      _addInitialGreeting();
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear Chat"),
        content:
            const Text("Are you sure you want to clear this conversation?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                await ApiService.deleteChatConversation(
                  chatId: _currentChatId!,
                );

                setState(() {
                  _messages.clear();
                  _currentChatId = null;
                });

                _addInitialGreeting();
                _loadChatHistory(); // Refresh chat history

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Chat cleared successfully"),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Failed to clear chat: ${e.toString()}"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text("Clear"),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          // Fixed header height and added flex to prevent overflow
          Container(
            height: 100, // Reduced from 120 to prevent overflow
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  AppColors.secondary,
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8), // Reduced padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment:
                      MainAxisAlignment.center, // Changed from end to center
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 24, // Reduced from 28
                    ),
                    const SizedBox(height: 4), // Reduced from 8
                    const Text(
                      "Chat History",
                      style: TextStyle(
                        // Use plain TextStyle instead of TextStyles.heading3
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // New Chat Button
          ListTile(
            leading:
                const Icon(Icons.add_circle_outline, color: AppColors.primary),
            title: const Text("New Chat"),
            onTap: _startNewChat,
          ),

          const Divider(),

          // Chat History - Added Flexible to prevent overflow
          Flexible(
            // Changed from Expanded to Flexible
            child: _chatHistory.isEmpty
                ? const Center(
                    child: Text(
                      "No chat history yet",
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true, // Added shrinkWrap
                    itemCount: _chatHistory.length,
                    itemBuilder: (context, index) {
                      final chat = _chatHistory[index];
                      final messages = chat['messages'] as List<dynamic>;
                      final lastMessage = messages.isNotEmpty
                          ? messages.last['content'] as String
                          : 'Empty conversation';
                      final isCurrentChat = chat['id'] == _currentChatId;

                      return Container(
                        color: isCurrentChat
                            ? AppColors.primary.withOpacity(0.1)
                            : null,
                        child: ListTile(
                          leading: Icon(
                            Icons.chat_bubble_outline,
                            color:
                                isCurrentChat ? AppColors.primary : Colors.grey,
                          ),
                          title: Text(
                            lastMessage.length > 30
                                ? '${lastMessage.substring(0, 30)}...'
                                : lastMessage,
                            style: TextStyle(
                              fontWeight: isCurrentChat
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            _formatChatDate(DateTime.parse(chat['updatedAt'])),
                            style: const TextStyle(fontSize: 12),
                          ),
                          onTap: () => _loadChatFromHistory(chat),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () => _deleteChatFromHistory(chat['id']),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          const Divider(),

          // Clear Current Chat - Made this conditional and compact
          if (_messages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                  bottom: 8), // Added padding to prevent overflow
              child: ListTile(
                leading:
                    const Icon(Icons.clear_all, color: Colors.red, size: 20),
                title: const Text(
                  "Clear Current Chat",
                  style: TextStyle(
                      color: Colors.red, fontSize: 14), // Reduced font size
                ),
                onTap: _clearCurrentChat,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4), // Reduced padding
              ),
            ),
        ],
      ),
    );
  }

  String _formatChatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    } else if (difference.inDays == 1) {
      return "Yesterday";
    } else if (difference.inDays < 7) {
      return "${difference.inDays} days ago";
    } else {
      return "${date.day}/${date.month}/${date.year}";
    }
  }

  void _deleteChatFromHistory(String chatId) async {
    try {
      await ApiService.deleteChatConversation(chatId: chatId);

      setState(() {
        _chatHistory.removeWhere((chat) => chat['id'] == chatId);

        // If we deleted the current chat, clear it
        if (_currentChatId == chatId) {
          _messages.clear();
          _currentChatId = null;
          _addInitialGreeting();
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Chat deleted successfully"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to delete chat: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingHistory) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: const CustomAppBar(
          title: "Mimos Uterinos AI Coach",
          showBackButton: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: "Mimos Uterinos AI Coach",
        showBackButton: true,
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              tooltip: "Chat History",
            ),
          ),
        ],
      ),
      endDrawer: _buildDrawer(),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  // Typing indicator
                  return _buildTypingIndicator();
                }

                final message = _messages[index];
                return _buildMessageBubble(
                  message: message['message'],
                  isUser: message['isUser'],
                  timestamp: message['timestamp'],
                ).animate().fadeIn(duration: 300.ms).slideY(begin: 10, end: 0);
              },
            ),
          ),

          // Suggested questions
          if (_messages.length < 2)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Suggested Questions",
                    style: TextStyles.subtitle2,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _suggestedQuestions.map((question) {
                      return GestureDetector(
                        onTap: () {
                          _sendMessage(question);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.secondary.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            question,
                            style: TextStyles.caption.copyWith(
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(delay: 500.ms, duration: 800.ms)
                .slideY(delay: 500.ms, begin: 20, end: 0),

          // Message input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.divider,
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: TextStyles.body2,
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        enabled: !_isTyping,
                        onSubmitted: (value) => _sendMessage(value),
                        decoration: InputDecoration(
                          hintText:
                              _isTyping ? "AI is typing..." : "Ask Mimos AI...",
                          hintStyle: TextStyles.body2.copyWith(
                            color: AppColors.textSecondary.withOpacity(0.5),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(
                              Icons.mic_rounded,
                              color: AppColors.primary,
                            ),
                            onPressed: () {
                              // TODO: Implement voice input
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Voice input coming soon!"),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _isTyping ? Colors.grey : AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isTyping ? Colors.grey : AppColors.primary)
                              .withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isTyping ? Icons.hourglass_empty : Icons.send_rounded,
                        color: Colors.white,
                      ),
                      onPressed: _isTyping
                          ? null
                          : () {
                              _sendMessage(_messageController.text);
                            },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({
    required String message,
    required bool isUser,
    required DateTime timestamp,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser)
            Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.auto_awesome,
                  color: AppColors.secondary,
                  size: 20,
                ),
              ),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUser ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(16).copyWith(
                      bottomLeft: isUser
                          ? const Radius.circular(16)
                          : const Radius.circular(0),
                      bottomRight: isUser
                          ? const Radius.circular(0)
                          : const Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message,
                    style: TextStyles.body2.copyWith(
                      color: isUser ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}",
                  style: TextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (isUser)
            Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.auto_awesome,
                color: AppColors.secondary,
                size: 20,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomLeft: const Radius.circular(0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(),
                const SizedBox(width: 4),
                _buildDot(delay: 300),
                const SizedBox(width: 4),
                _buildDot(delay: 600),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot({int delay = 0}) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: AppColors.secondary,
        shape: BoxShape.circle,
      ),
    )
        .animate(
          onPlay: (controller) => controller.repeat(),
        )
        .scale(
          begin: const Offset(0.5, 0.5),
          end: const Offset(1, 1),
          duration: 600.ms,
          delay: Duration(milliseconds: delay),
          curve: Curves.easeInOut,
        )
        .then()
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(0.5, 0.5),
          duration: 600.ms,
          curve: Curves.easeInOut,
        );
  }
}
