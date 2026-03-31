import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/firebase_service.dart';

/// Patient requests tab — shows pending connection requests from parents.
class DoctorRequestsTab extends StatefulWidget {
  const DoctorRequestsTab({super.key});

  @override
  State<DoctorRequestsTab> createState() => _DoctorRequestsTabState();
}

class _DoctorRequestsTabState extends State<DoctorRequestsTab> {
  final _firebaseService = FirebaseService();
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final requests = await _firebaseService.getDoctorRequests();
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _respondToRequest(
    Map<String, dynamic> request,
    bool approve,
  ) async {
    final requestId = request['requestId'] as String?;
    if (requestId == null || requestId.isEmpty) return;

    await _firebaseService.respondToDoctorRequest(requestId, approve);

    if (!mounted) return;
    setState(() {
      _requests.removeWhere((r) => r['requestId'] == requestId);
    });

    final childName = (request['childName'] as String?) ?? 'Request';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${approve ? 'Accepted' : 'Declined'} $childName'),
        backgroundColor: approve ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Patient Requests'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        foregroundColor:
            isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.doctorPrimary,
                ),
              )
              : RefreshIndicator(
                color: AppColors.doctorPrimary,
                onRefresh: _load,
                child:
                    _requests.isEmpty
                        ? _buildEmptyState(isDark)
                        : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                          itemCount: _requests.length,
                          itemBuilder:
                              (context, index) => _buildRequestCard(
                                _requests[index],
                                isDark,
                                index,
                              ),
                        ),
              ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request, bool isDark, int index) {
    final childName = (request['childName'] as String?) ?? 'Adult User';
    final parentName = (request['parentName'] as String?) ?? 'User';
    final conditions = List<String>.from(request['conditions'] ?? const []);
    final age = request['childAge'] ?? 18;
    final isAdultConsult = (request['isAdultConsultation'] as bool?) ?? false;
    final consultNote = (request['consultNote'] as String?)?.trim() ?? '';

    return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.darkDivider : AppColors.divider,
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : AppColors.primary).withValues(
                  alpha: 0.04,
                ),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.doctorPrimary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        childName.isNotEmpty ? childName[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.doctorPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          childName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color:
                                isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isAdultConsult
                              ? 'Adult Consultation • $parentName'
                              : 'Age $age  •  Parent: $parentName',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Pending',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
              if (conditions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children:
                      conditions
                          .take(3)
                          .map(
                            (c) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.doctorPrimary.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                c,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.doctorPrimary,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ],
              if (consultNote.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? AppColors.darkSurfaceVariant
                            : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    consultNote,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: ElevatedButton(
                        onPressed: () => _respondToRequest(request, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.doctorPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Accept',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: OutlinedButton(
                        onPressed: () => _respondToRequest(request, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Decline',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: (200 + index * 80).ms, duration: 400.ms)
        .slideY(begin: 0.05);
  }

  Widget _buildEmptyState(bool isDark) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Center(
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.doctorPrimary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.inbox_rounded,
                  size: 36,
                  color: AppColors.doctorPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No Requests',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color:
                      isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Consultation requests will appear here.',
                style: TextStyle(
                  fontSize: 14,
                  color:
                      isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
