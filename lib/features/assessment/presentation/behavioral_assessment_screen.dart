import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/child_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../models/child_assessment_result_model.dart';
import '../../../services/behavioral_assessment_service.dart';
import '../../../widgets/common/loading_overlay.dart';

/// Screen for conducting behavioral assessment check-ins with parents.
/// Uses conversational AI to gather information about child behavior changes.
class BehavioralAssessmentScreen extends ConsumerStatefulWidget {
  const BehavioralAssessmentScreen({super.key});

  @override
  ConsumerState<BehavioralAssessmentScreen> createState() => _BehavioralAssessmentScreenState();
}

class _BehavioralAssessmentScreenState extends ConsumerState<BehavioralAssessmentScreen> {
  late final BehavioralAssessmentService _assessmentService;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isInitialized = false;
  bool _isLoading = false;
  bool _assessmentComplete = false;
  ChildAssessmentResult? _assessmentResult;

  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    // Get service from provider will be done in didChangeDependencies or use ref in build
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeAssessment() async {
    setState(() => _isLoading = true);

    try {
      _assessmentService.initialize();

      final childProfile = ref.read(selectedChildProvider);
      final user = ref.read(userProvider);

      if (childProfile == null || user == null) {
        _showError('Child profile or user not found');
        return;
      }

      // TODO: Fetch actual data from services
      // For now, using placeholder data
      _assessmentService.startAssessmentSession(
        childProfile: childProfile,
        gameCompletionRate: '75', // TODO: Get from game service
        daysSinceLastSession: 2, // TODO: Get from therapy service
        moodHistory: 'mixed - some good days, some challenging', // TODO: Get from mood tracking
        doctorName: 'Dr. Smith', // TODO: Get from doctor service
        previousRiskLevels: ['stable', 'monitor'], // TODO: Get from assessment history
      );

      _isInitialized = true;

      // Start with the opening question
      await _sendInitialMessage();

    } catch (e) {
      _showError('Failed to initialize assessment: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendInitialMessage() async {
    const initialPrompt = "I'd like to check in on how your child has been doing lately — not their therapy progress, just their overall mood and behavior day-to-day. Have you noticed anything different about them in the past week or two?";

    setState(() {
      _messages.add(ChatMessage(
        text: initialPrompt,
        isFromAI: true,
        timestamp: DateTime.now(),
      ));
    });

    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isFromAI: false,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final response = await _assessmentService.sendParentResponse(text);

      // Check if this is the final assessment result
      final result = ChildAssessmentResult.fromResponseText(response);
      if (result != null) {
        setState(() {
          _assessmentComplete = true;
          _assessmentResult = result;
          _messages.add(ChatMessage(
            text: 'Assessment complete! Here\'s the summary:\n\n${_formatResultForDisplay(result)}',
            isFromAI: true,
            timestamp: DateTime.now(),
          ));
        });
      } else {
        setState(() {
          _messages.add(ChatMessage(
            text: response,
            isFromAI: true,
            timestamp: DateTime.now(),
          ));
        });
      }
    } catch (e) {
      _showError('Failed to get response: $e');
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  Future<void> _endAssessment() async {
    setState(() => _isLoading = true);

    try {
      final result = await _assessmentService.generateAssessmentResult();

      if (result != null) {
        setState(() {
          _assessmentComplete = true;
          _assessmentResult = result;
          _messages.add(ChatMessage(
            text: 'Assessment complete! Here\'s the summary:\n\n${_formatResultForDisplay(result)}',
            isFromAI: true,
            timestamp: DateTime.now(),
          ));
        });
      } else {
        _showError('Failed to generate assessment result');
      }
    } catch (e) {
      _showError('Failed to end assessment: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatResultForDisplay(ChildAssessmentResult result) {
    final buffer = StringBuffer();

    buffer.writeln('**Risk Level:** ${result.riskLevel.toUpperCase()}');
    buffer.writeln('**Confidence:** ${(result.confidence * 100).toInt()}%');
    buffer.writeln();

    buffer.writeln('**Key Signals:**');
    result.domainSignals.forEach((key, value) {
      buffer.writeln('- ${key.replaceAll('_', ' ')}: $value/10');
    });

    if (result.behaviorChangesFromBaseline.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('**Changes from Baseline:**');
      for (final change in result.behaviorChangesFromBaseline) {
        buffer.writeln('- $change');
      }
    }

    if (result.recommendedActions.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('**Recommended Actions:**');
      for (final action in result.recommendedActions) {
        buffer.writeln('- **${action.title}** (${action.priority}): ${action.reason}');
      }
    }

    if (result.escalateToDoctor) {
      buffer.writeln();
      buffer.writeln('**⚠️ Escalated to Doctor:** ${result.escalationReason}');
    }

    buffer.writeln();
    buffer.writeln('**Follow-up in ${result.followUpInDays} days**');

    return buffer.toString();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    _assessmentService = ref.read<BehavioralAssessmentService>();

    if (!_isInitialized) {
      _initializeAssessment();
    }

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
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: Column(
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
            if (!_assessmentComplete)
              _buildMessageInput(),
          ],
        ),
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
              ? Theme.of(context).primaryColor.withOpacity(0.1)
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