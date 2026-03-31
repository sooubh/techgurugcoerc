import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/doctor_chat_model.dart';
import '../../../services/firebase_service.dart';
import '../../chat/presentation/doctor_patient_chat_screen.dart';
import '../../../models/doctor_model.dart';

/// Doctor chats tab — shows all patient conversations.
/// Filtering by unread, online status, search.
class DoctorChatsTab extends StatefulWidget {
  const DoctorChatsTab({super.key});

  @override
  State<DoctorChatsTab> createState() => _DoctorChatsTabState();
}

class _DoctorChatsTabState extends State<DoctorChatsTab> {
  final _firebaseService = FirebaseService();
  List<Map<String, dynamic>> _chatSessions = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool _showUnreadOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sessions = await _firebaseService.getDoctorChatWithPatients();
      if (!mounted) return;
      setState(() {
        _chatSessions = sessions;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading chats: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    _filtered = _chatSessions;

    if (_showUnreadOnly) {
      _filtered = _filtered.where((c) => (c['unreadCount'] ?? 0) > 0).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      _filtered = _filtered.where((c) {
        final name = (c['patientName'] ?? '').toString().toLowerCase();
        return name.contains(query);
      }).toList();
    }

    _filtered.sort((a, b) {
      final aTime = (a['lastMessageTime'] as int?) ?? 0;
      final bTime = (b['lastMessageTime'] as int?) ?? 0;
      return bTime.compareTo(aTime);
    });
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _toggleUnreadFilter() {
    setState(() {
      _showUnreadOnly = !_showUnreadOnly;
      _applyFilters();
    });
  }

  String _formatTime(int? timestamp) {
    if (timestamp == null) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return DateFormat('MMM d').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Patient Chats'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        foregroundColor:
            isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        actions: [
          IconButton(
            icon: Icon(
              _showUnreadOnly ? Icons.filter_alt : Icons.filter_alt_outlined,
              color:
                  _showUnreadOnly
                      ? AppColors.doctorPrimary
                      : (isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.textTertiary),
            ),
            onPressed: _toggleUnreadFilter,
            tooltip: 'Show unread only',
          ),
          SizedBox(width: 8),
        ],
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.doctorPrimary,
                ),
              )
              : _filtered.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_outlined,
                          size: 64,
                          color:
                              isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.textTertiary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No chats found'
                              : 'No patient chats yet',
                          style: TextStyle(
                            fontSize: 16,
                            color:
                                isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                  : Column(
                    children: [
                      // Search bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                        child: Container(
                          decoration: BoxDecoration(
                            color:
                                isDark ? AppColors.darkSurface : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                                  isDark
                                      ? AppColors.darkDivider
                                      : AppColors.divider,
                            ),
                          ),
                          child: TextField(
                            onChanged: _onSearch,
                            decoration: InputDecoration(
                              hintText: 'Search by patient name…',
                              hintStyle: TextStyle(
                                color:
                                    isDark
                                        ? AppColors.darkTextTertiary
                                        : AppColors.textTertiary,
                              ),
                              border: InputBorder.none,
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color:
                                    isDark
                                        ? AppColors.darkTextTertiary
                                        : AppColors.textTertiary,
                              ),
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                            style: TextStyle(
                              color:
                                  isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      // Chat list
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final chat = _filtered[index];
                            final unreadCount = chat['unreadCount'] ?? 0;
                            final isOnline = chat['patientOnline'] ?? false;

                            return GestureDetector(
                              onTap: () {
                                final patientId = chat['patientId'] as String?;
                                if (patientId != null) {
                                  final doctor = DoctorModel(
                                    id: _firebaseService.currentUser?.uid ?? '',
                                    name: 'Dr. ${chat['doctorName']}',
                                    email:
                                        _firebaseService.currentUser?.email ?? '',
                                    specialization: 'Doctor',
                                    clinicName: 'Clinic',
                                    phone: '',
                                    bio: 'Doctor',
                                    photoUrl: null,
                                  );

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) =>
                                              DoctorPatientChatScreen(
                                                doctor: doctor,
                                              ),
                                    ),
                                  ).then((_) => _load());
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color:
                                      isDark
                                          ? AppColors.darkSurface
                                          : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        isDark
                                            ? AppColors.darkDivider
                                            : AppColors.divider,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Avatar with online status
                                    Stack(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: AppColors.doctorPrimary
                                                .withValues(alpha: 0.2),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Center(
                                            child: Icon(
                                              Icons.person_rounded,
                                              color: AppColors.doctorPrimary,
                                              size: 24,
                                            ),
                                          ),
                                        ),
                                        if (isOnline)
                                          Positioned(
                                            bottom: 0,
                                            right: 0,
                                            child: Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                color: Colors.green,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color:
                                                      isDark
                                                          ? AppColors
                                                              .darkSurface
                                                          : Colors.white,
                                                  width: 2,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    // Chat info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            chat['patientName'] ?? 'Patient',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  isDark
                                                      ? AppColors
                                                          .darkTextPrimary
                                                      : AppColors.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            chat['lastMessage'] ??
                                                'No messages yet',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  isDark
                                                      ? AppColors
                                                          .darkTextTertiary
                                                      : AppColors.textTertiary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Time and unread badge
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _formatTime(
                                            chat['lastMessageTime'] as int?,
                                          ),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                isDark
                                                    ? AppColors
                                                        .darkTextTertiary
                                                    : AppColors.textTertiary,
                                          ),
                                        ),
                                        if (unreadCount > 0)
                                          Container(
                                            margin:
                                                const EdgeInsets.only(top: 4),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.doctorPrimary,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '$unreadCount',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
    );
  }
}
