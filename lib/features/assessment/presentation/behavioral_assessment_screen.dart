import 'package:flutter/material.dart';
import '../../../models/child_assessment_result_model.dart';
import '../../../models/child_profile_model.dart';
import '../../../services/behavioral_assessment_service.dart';
import '../../../services/firebase_service.dart';

/// Screen for conducting behavioral assessment check-ins with parents.
/// Uses conversational AI to gather information about child behavior changes.
class BehavioralAssessmentScreen extends StatefulWidget {
  const BehavioralAssessmentScreen({super.key});

  @override
  State<BehavioralAssessmentScreen> createState() =>
      _BehavioralAssessmentScreenState();
}

class _BehavioralAssessmentScreenState extends State<BehavioralAssessmentScreen> {
  final BehavioralAssessmentService _assessmentService =
      BehavioralAssessmentService();
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isInitialized = false;
  bool _isLoading = false;
  bool _assessmentComplete = false;

  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAssessment();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeAssessment() async {
    if (_isInitialized) return;
    setState(() => _isLoading = true);

    try {
      _assessmentService.initialize();

      final childProfile = await _firebaseService.getChildProfile();
      if (childProfile == null) {
        _showError('Child profile not found. Please complete profile setup.');
        return;
      }

      _assessmentService.startAssessmentSession(
        childProfile: childProfile,
        gameCompletionRate: '75',
        daysSinceLastSession: 2,
        moodHistory: 'mixed - some good days, some challenging',
        doctorName: 'Assigned Doctor',
        previousRiskLevels: ['stable', 'monitor'],
      );

      _isInitialized = true;
      await _sendInitialMessage(childProfile);
    } catch (e) {
      _showError('Failed to initialize assessment: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendInitialMessage(ChildProfileModel childProfile) async {
    final initialPrompt =
        'I\'d like to check in on how ${childProfile.name} has been doing lately. '
        'Have you noticed anything different in mood or behavior this week?';

    setState(() {
      _messages.add(
        ChatMessage(
          text: initialPrompt,
          isFromAI: true,
          timestamp: DateTime.now(),
        ),
      );
    });

    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading || _assessmentComplete) return;

    setState(() {
      _messages.add(
        ChatMessage(
          text: text,
          isFromAI: false,
          timestamp: DateTime.now(),
        ),
      );
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final response = await _assessmentService.sendParentResponse(text);

      final result = ChildAssessmentResult.fromResponseText(response);
      if (result != null) {
        setState(() {
          _assessmentComplete = true;
          _messages.add(
            ChatMessage(
              text:
                  'Assessment complete. Here is the summary:\n\n${_formatResultForDisplay(result)}',
              isFromAI: true,
              timestamp: DateTime.now(),
            ),
          );
        });
      } else {
        setState(() {
          _messages.add(
            ChatMessage(
              text: response,
              isFromAI: true,
              timestamp: DateTime.now(),
            ),
          );
        });
      }
    } catch (e) {
      _showError('Failed to get response: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToBottom();
      }
    }
  }

  Future<void> _endAssessment() async {
    if (_assessmentComplete) return;

    setState(() => _isLoading = true);

    try {
      final result = await _assessmentService.generateAssessmentResult();

      if (result == null) {
        _showError('Failed to generate assessment result');
        return;
      }

      setState(() {
        _assessmentComplete = true;
        _messages.add(
          ChatMessage(
            text:
                'Assessment complete. Here is the summary:\n\n${_formatResultForDisplay(result)}',
            isFromAI: true,
            timestamp: DateTime.now(),
          ),
        );
      });
    } catch (e) {
      _showError('Failed to end assessment: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatResultForDisplay(ChildAssessmentResult result) {
    final buffer = StringBuffer();

    buffer.writeln('Risk Level: ${result.riskLevel.toUpperCase()}');
    buffer.writeln('Confidence: ${(result.confidence * 100).toInt()}%');
    buffer.writeln();

    buffer.writeln('Key Signals:');
    result.domainSignals.forEach((key, value) {
      buffer.writeln('- ${key.replaceAll('_', ' ')}: $value/10');
    });

    if (result.behaviorChangesFromBaseline.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Changes from Baseline:');
      for (final change in result.behaviorChangesFromBaseline) {
        buffer.writeln('- $change');
      }
    }

    if (result.recommendedActions.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Recommended Actions:');
      for (final action in result.recommendedActions) {
        buffer.writeln('- ${action.title} (${action.priority}): ${action.reason}');
      }
    }

    if (result.escalateToDoctor) {
      buffer.writeln();
      buffer.writeln('Escalated to Doctor: ${result.escalationReason}');
    }

    buffer.writeln();
    buffer.writeln('Follow-up in ${result.followUpInDays} days');

    return buffer.toString();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Behavioral Check-in'),
        actions: [
          if (!_assessmentComplete && _messages.length > 1)
            TextButton(
              onPressed: _endAssessment,
              child: const Text('End Assessment'),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: _messages.isEmpty
                    ? const Center(child: Text('Initializing assessment...'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return _ChatBubble(message: message);
                        },
                      ),
              ),
              if (!_assessmentComplete) _buildMessageInput(),
            ],
          ),
          if (_isLoading)
            const Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Share your observations...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              minLines: 1,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sendMessage,
            icon: const Icon(Icons.send),
            color: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isFromAI ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: message.isFromAI
              ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
              : Theme.of(context).primaryColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: message.isFromAI
                    ? Theme.of(context).textTheme.bodyLarge?.color
                    : Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(message.timestamp),
              style: TextStyle(
                fontSize: 12,
                color: message.isFromAI
                    ? Theme.of(context).textTheme.bodySmall?.color
                    : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}

class ChatMessage {
  final String text;
  final bool isFromAI;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isFromAI,
    required this.timestamp,
  });
}
