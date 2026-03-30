import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/firebase_service.dart';
import '../../../models/risk_alert_model.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class DoctorAlertsTab extends StatefulWidget {
  const DoctorAlertsTab({super.key});

  @override
  State<DoctorAlertsTab> createState() => _DoctorAlertsTabState();
}

class _DoctorAlertsTabState extends State<DoctorAlertsTab> {
  late FirebaseService _firebaseService;
  late Stream<List<RiskAlertModel>> _alertsStream;

  @override
  void initState() {
    super.initState();
    _firebaseService = context.read<FirebaseService>();
    _alertsStream = _firebaseService.getRiskAlertsForDoctor();
  }

  Future<void> _resolveAlert(RiskAlertModel alert) async {
    try {
      await _firebaseService.resolveRiskAlert(alert.id, alert.userId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alert resolved successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resolve alert: \$e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<RiskAlertModel>>(
      stream: _alertsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading alerts.',
              style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
            ),
          );
        }

        final alerts = snapshot.data ?? [];
        final unresolvedAlerts = alerts.where((a) => !a.isResolved).toList();

        if (unresolvedAlerts.isEmpty) {
          return _buildEmptyState(isDark);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: unresolvedAlerts.length,
          itemBuilder: (context, index) {
            final alert = unresolvedAlerts[index];
            return _buildAlertCard(context, alert, isDark);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 64,
            color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            'No active alerts',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All patient risks have been addressed.',
            style: TextStyle(
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(BuildContext context, RiskAlertModel alert, bool isDark) {
    final isHighSeverity = alert.severity == AlertSeverity.high;
    final cardColor = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;
    final accentColor = isHighSeverity ? AppColors.error : AppColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
          width: isHighSeverity ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isHighSeverity ? Icons.warning_rounded : Icons.info_outline_rounded,
                  color: accentColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isHighSeverity ? 'High Risk Alert' : 'Medium Risk Alert',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  DateFormat.yMMMd().add_jm().format(alert.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Patient / Parent ID: \${alert.userId}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Source: \${alert.source.name.toUpperCase()}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                alert.description,
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _resolveAlert(alert),
                icon: const Icon(Icons.check_rounded, size: 20),
                label: const Text('Mark as Resolved'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isHighSeverity ? AppColors.error : AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
