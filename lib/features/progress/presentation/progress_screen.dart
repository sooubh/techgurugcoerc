import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/firebase_service.dart';
import '../../../services/cache/smart_data_repository.dart';
import 'package:provider/provider.dart';
import '../../../models/activity_log_model.dart';

/// Easy progress screen with live data from Firestore.
/// Shows weekly summary, stress-skill growth, activity history, and trend.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final _firebaseService = FirebaseService();
  bool _isLoading = true;
  bool _isAdultView = false;

  // Real data from Firestore
  Map<String, dynamic> _weeklyStats = {'count': 0, 'minutes': 0, 'streak': 0};
  Map<String, double> _skillProgress = {};
  List<ActivityLogModel> _activityLogs = [];
  List<Map<String, dynamic>> _milestones = [];
  List<int> _dailyCounts = List.filled(7, 0);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final repository = context.read<SmartDataRepository>();
      final uid = _firebaseService.currentUser?.uid;
      if (uid == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      
      final dashboard = await repository.getDashboardData(uid, isAdult: _isAdultView);
      final logs = await _firebaseService.getActivityLogs(limit: 50, isAdult: _isAdultView);
      final milestones = _isAdultView ? <Map<String, dynamic>>[] : await _firebaseService.getMilestones();

      final fallbackWeekly = _computeWeeklyStatsFromLogs(logs);
      final fallbackDailyCounts = _computeDailyCountsFromLogs(logs);

      if (mounted) {
        setState(() {
          final weeklyFromDashboard = Map<String, dynamic>.from(
            dashboard['weeklyStats'] ?? {},
          );
          _weeklyStats =
              (weeklyFromDashboard['count'] ?? 0) == 0 && logs.isNotEmpty
                  ? fallbackWeekly
                  : (dashboard['weeklyStats'] ?? {'count': 0, 'minutes': 0, 'streak': 0});
          _skillProgress = Map<String, double>.from(dashboard['skillProgress'] ?? {});
          _activityLogs = logs;
          _milestones = milestones;
          final dashboardCounts = List<int>.from(
            dashboard['dailyActivityCounts'] ?? List.filled(7, 0),
          );
          _dailyCounts =
              dashboardCounts.every((c) => c == 0) && logs.isNotEmpty
                  ? fallbackDailyCounts
                  : dashboardCounts;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _computeWeeklyStatsFromLogs(List<ActivityLogModel> logs) {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final weekLogs = logs.where((l) => !l.completedAt.isBefore(sevenDaysAgo)).toList();

    final totalSeconds = weekLogs.fold<int>(0, (sum, l) => sum + l.durationSeconds);
    final activeDays = <String>{};
    for (final log in weekLogs) {
      final d = log.completedAt;
      activeDays.add('${d.year}-${d.month}-${d.day}');
    }

    int streak = 0;
    var checkDate = DateTime.now();
    checkDate = DateTime(checkDate.year, checkDate.month, checkDate.day);
    while (activeDays.contains('${checkDate.year}-${checkDate.month}-${checkDate.day}')) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    return {
      'count': weekLogs.length,
      'minutes': (totalSeconds / 60).round(),
      'streak': streak,
    };
  }

  List<int> _computeDailyCountsFromLogs(List<ActivityLogModel> logs) {
    final now = DateTime.now();
    final counts = List.filled(7, 0);
    for (final log in logs) {
      final daysAgo = now.difference(log.completedAt).inDays;
      if (daysAgo >= 0 && daysAgo < 7) {
        counts[6 - daysAgo] += 1;
      }
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('How You Are Doing'),
        actions: [
          IconButton(
            onPressed: () {
              final report = _generateReport();
              Clipboard.setData(ClipboardData(text: report));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Report copied to clipboard.'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            icon: const Icon(Icons.share_rounded, size: 22),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadData,
                color: AppColors.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Toggle Switch ─────────────────────────
                      _buildToggleSwitch(context, isDark),
                      const SizedBox(height: 20),

                      // ─── Weekly Summary Card ───────────────────
                      _buildWeeklySummary(context, isDark),
                      const SizedBox(height: 20),

                      // ─── Skill Progress Rings ──────────────────
                      _sectionTitle(context, 'Stress Relief Skills'),
                      const SizedBox(height: 12),
                      _buildSkillRings(context, isDark),
                      const SizedBox(height: 24),

                      // ─── Activity History ──────────────────────
                      _sectionTitle(context, 'Recent Activities'),
                      const SizedBox(height: 12),
                      _buildActivityHistory(context, isDark),
                      const SizedBox(height: 24),

                      // ─── Milestones ────────────────────────────
                      if (!_isAdultView) ...[
                        _sectionTitle(context, 'Big Wins'),
                        const SizedBox(height: 12),
                        _buildMilestones(context, isDark),
                        const SizedBox(height: 24),
                      ],

                      // ─── Weekly Trend ──────────────────────────
                      _sectionTitle(context, 'This Week at a Glance'),
                      const SizedBox(height: 12),
                      _buildWeeklyTrend(context, isDark),
                      const SizedBox(height: 24),

                      // ─── Full Progress Report ───────────────────
                      _sectionTitle(context, 'Full Report'),
                      const SizedBox(height: 12),
                      _buildFullProgressReport(context, isDark),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildToggleSwitch(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_isAdultView) {
                  setState(() {
                    _isAdultView = false;
                    _isLoading = true;
                  });
                  _loadData();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_isAdultView 
                      ? (isDark ? AppColors.darkCardBackground : AppColors.cardBackground)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: !_isAdultView 
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'Child View',
                  style: TextStyle(
                    fontWeight: !_isAdultView ? FontWeight.bold : FontWeight.normal,
                    color: !_isAdultView 
                        ? (isDark ? Colors.white : AppColors.textPrimary)
                        : (isDark ? Colors.white54 : AppColors.textSecondary),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!_isAdultView) {
                  setState(() {
                    _isAdultView = true;
                    _isLoading = true;
                  });
                  _loadData();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _isAdultView 
                      ? (isDark ? AppColors.darkCardBackground : AppColors.cardBackground)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _isAdultView 
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'Adult View',
                  style: TextStyle(
                    fontWeight: _isAdultView ? FontWeight.bold : FontWeight.normal,
                    color: _isAdultView 
                        ? (isDark ? Colors.white : AppColors.textPrimary)
                        : (isDark ? Colors.white54 : AppColors.textSecondary),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _generateReport() {
    final buffer = StringBuffer();
    buffer.writeln('CARE-AI Simple Report');
    buffer.writeln(
      'Generated: ${DateTime.now().toIso8601String().substring(0, 10)}',
    );
    buffer.writeln('─────────────────────────');
    buffer.writeln();
    buffer.writeln('Weekly Summary');
    buffer.writeln('  Activities Completed: ${_weeklyStats['count']}');
    buffer.writeln('  Total Minutes: ${_weeklyStats['minutes']}');
    buffer.writeln('  Current Streak: ${_weeklyStats['streak']} days');
    buffer.writeln();
    buffer.writeln('Stress Relief Skills');
    if (_skillProgress.isEmpty) {
      buffer.writeln('  No activities logged yet.');
    }
    for (final entry in _skillProgress.entries) {
      buffer.writeln('  ${entry.key}: ${(entry.value * 100).toInt()}%');
    }
    buffer.writeln();
    buffer.writeln('Big Wins');
    if (_milestones.isEmpty) {
      buffer.writeln('  No milestones yet.');
    }
    for (final m in _milestones) {
      buffer.writeln('  ${m['emoji'] ?? '⭐'} ${m['title'] ?? 'Milestone'}');
    }
    buffer.writeln();
    buffer.writeln('Recent Activities');
    if (_activityLogs.isEmpty) {
      buffer.writeln('  No activities logged yet.');
    }
    for (final log in _activityLogs) {
      final mins = (log.durationSeconds / 60).round();
      buffer.writeln('  ✓ ${log.activityTitle} ($mins min)');
    }
    buffer.writeln();
    buffer.writeln('─────────────────────────');
    buffer.writeln('Generated by CARE-AI • AI Parenting Companion');
    return buffer.toString();
  }

  Widget _buildWeeklySummary(BuildContext context, bool isDark) {
    return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF5B6EF5), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5B6EF5).withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.insights_rounded, color: Colors.white, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'This Week',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _SummaryItem(
                    label: 'Activities',
                    value: '${_weeklyStats['count']}',
                    icon: Icons.extension_rounded,
                  ),
                  _SummaryItem(
                    label: 'Minutes',
                    value: '${_weeklyStats['minutes']}',
                    icon: Icons.timer_rounded,
                  ),
                  _SummaryItem(
                    label: 'Streak',
                    value: '${_weeklyStats['streak']} d',
                    icon: Icons.local_fire_department_rounded,
                  ),
                ],
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.05, duration: 500.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildSkillRings(BuildContext context, bool isDark) {
    if (_skillProgress.isEmpty) {
      return _buildEmptyState(
        context,
        isDark,
        'Do activities to see your skill growth.',
      );
    }

    final colors = [
      AppColors.primary,
      AppColors.accent,
      const Color(0xFF10B981),
      AppColors.purple,
      const Color(0xFFF59E0B),
    ];

    final entries = _skillProgress.entries.toList();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children:
          entries.asMap().entries.map((entry) {
            final skill = entry.value;
            final color = colors[entry.key % colors.length];
            return Column(
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: skill.value,
                        backgroundColor:
                            isDark
                                ? AppColors.darkSurfaceVariant
                                : AppColors.surfaceVariant,
                        color: color,
                        strokeWidth: 6,
                        strokeCap: StrokeCap.round,
                      ),
                      Text(
                        '${(skill.value * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  skill.key.length > 10
                      ? '${skill.key.substring(0, 10)}…'
                      : skill.key,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ).animate().fadeIn(
              delay: Duration(milliseconds: 200 + (entry.key * 100)),
              duration: 400.ms,
            );
          }).toList(),
    );
  }

  Widget _buildActivityHistory(BuildContext context, bool isDark) {
    if (_activityLogs.isEmpty) {
      return _buildEmptyState(
        context,
        isDark,
        'No activities yet. Start one now.',
      );
    }

    return Column(
      children:
          _activityLogs.asMap().entries.map((entry) {
            final log = entry.value;
            final mins = (log.durationSeconds / 60).round();
            final ago = _timeAgo(log.completedAt);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color:
                    isDark
                        ? AppColors.darkCardBackground
                        : AppColors.cardBackground,
                borderRadius: BorderRadius.circular(14),
                border:
                    isDark
                        ? Border.all(
                          color: AppColors.darkBorder.withValues(alpha: 0.2),
                        )
                        : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.activityTitle,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'Completed • $mins min • $ago',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(
              delay: Duration(milliseconds: 100 * entry.key),
              duration: 300.ms,
            );
          }).toList(),
    );
  }

  Widget _buildMilestones(BuildContext context, bool isDark) {
    if (_milestones.isEmpty) {
      return _buildEmptyState(
        context,
        isDark,
        'Big wins will show up as progress grows.',
      );
    }

    return Column(
      children:
          _milestones.asMap().entries.map((entry) {
            final milestone = entry.value;
            final title = milestone['title'] ?? 'Milestone';
            final category = milestone['category'] ?? '';
            final emoji = milestone['emoji'] ?? '⭐';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: isDark ? 0.15 : 0.08),
                    Colors.transparent,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (category.isNotEmpty)
                          Text(
                            category,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.emoji_events_rounded,
                    color: AppColors.accent,
                    size: 24,
                  ),
                ],
              ),
            ).animate().fadeIn(
              delay: Duration(milliseconds: 200 + (entry.key * 100)),
              duration: 400.ms,
            );
          }).toList(),
    );
  }

  Widget _buildWeeklyTrend(BuildContext context, bool isDark) {
    final now = DateTime.now();
    final days = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];
    });

    final maxCount =
        _dailyCounts.isEmpty ? 1 : _dailyCounts.reduce((a, b) => a > b ? a : b);
    final maxVal = maxCount == 0 ? 1 : maxCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border:
            isDark
                ? Border.all(color: AppColors.darkBorder.withValues(alpha: 0.2))
                : null,
      ),
      child: Column(
        children: [
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children:
                  days.asMap().entries.map((entry) {
                    final index = entry.key;
                    final value =
                        _dailyCounts.length > index ? _dailyCounts[index] : 0;
                    final normalized = value / maxVal;
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (value > 0)
                          Text(
                            '$value',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        const SizedBox(height: 2),
                        Container(
                          width: 28,
                          height: (100 * normalized).clamp(4, 100).toDouble(),
                          decoration: BoxDecoration(
                            gradient:
                                value > 0
                                    ? LinearGradient(
                                      colors: [
                                        AppColors.primary.withValues(
                                          alpha: 0.7,
                                        ),
                                        AppColors.primary,
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    )
                                    : null,
                            color:
                                value == 0
                                    ? (isDark
                                        ? AppColors.darkSurfaceVariant
                                        : AppColors.surfaceVariant)
                                    : null,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ).animate().fadeIn(
                          delay: Duration(milliseconds: 300 + (index * 60)),
                          duration: 400.ms,
                        ),
                      ],
                    );
                  }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children:
                days.map((d) {
                  return Text(
                    d,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontSize: 11),
                  );
                }).toList(),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms, duration: 500.ms);
  }

  Widget _buildEmptyState(BuildContext context, bool isDark, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border:
            isDark
                ? Border.all(color: AppColors.darkBorder.withValues(alpha: 0.2))
                : null,
      ),
      child: Column(
        children: [
          Icon(
            Icons.hourglass_empty_rounded,
            size: 36,
            color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildFullProgressReport(BuildContext context, bool isDark) {
    final report = _generateReport();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder.withValues(alpha: 0.2)
              : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isAdultView ? 'Adult Full Report' : 'Child Full Report',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: report));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Full report copied to clipboard.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              report,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                fontFamily: 'monospace',
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms, duration: 450.ms);
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}';
  }
}

// ─── Data Classes ──────────────────────────────────────────

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
