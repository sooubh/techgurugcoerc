import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/doctor_model.dart';
import '../../../services/firebase_service.dart';

/// Lets adult users connect with a doctor and request a consultation.
class AdultConsultationScreen extends StatefulWidget {
  const AdultConsultationScreen({super.key});

  @override
  State<AdultConsultationScreen> createState() => _AdultConsultationScreenState();
}

class _AdultConsultationScreenState extends State<AdultConsultationScreen> {
  final _firebaseService = FirebaseService();
  final _noteController = TextEditingController();

  List<DoctorModel> _doctors = [];
  bool _isLoading = true;
  String? _submittingDoctorId;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    setState(() => _isLoading = true);
    try {
      final doctors = await _firebaseService.getAvailableDoctors();
      if (!mounted) return;
      setState(() {
        _doctors = doctors;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load doctors right now.')),
      );
    }
  }

  Future<void> _requestConsultation(DoctorModel doctor) async {
    if (_submittingDoctorId != null) return;

    setState(() => _submittingDoctorId = doctor.id);
    try {
      await _firebaseService.sendAdultConsultationRequest(
        doctorId: doctor.id,
        note: _noteController.text.trim(),
      );

      if (!mounted) return;
      _noteController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Consultation request sent to Dr. ${doctor.name}'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send request. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _submittingDoctorId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect with Doctor'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadDoctors,
        color: AppColors.doctorPrimary,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _buildHeaderCard(isDark),
            const SizedBox(height: 16),
            _buildNoteBox(isDark),
            const SizedBox(height: 16),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 32),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.doctorPrimary),
                ),
              )
            else if (_doctors.isEmpty)
              _buildEmptyState(isDark)
            else
              ..._doctors.asMap().entries.map(
                (entry) => _buildDoctorCard(
                  doctor: entry.value,
                  isDark: isDark,
                  index: entry.key,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.divider,
        ),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Color(0xFFE0F2FE),
            child: Icon(Icons.medical_services_rounded, color: AppColors.doctorPrimary),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Request a private adult mental wellness consultation with a doctor.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteBox(bool isDark) {
    return TextField(
      controller: _noteController,
      minLines: 2,
      maxLines: 4,
      decoration: InputDecoration(
        hintText: 'Optional note for the doctor (symptoms, concerns, preferred time)',
        filled: true,
        fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkDivider : AppColors.divider,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkDivider : AppColors.divider,
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorCard({
    required DoctorModel doctor,
    required bool isDark,
    required int index,
  }) {
    final isSubmitting = _submittingDoctorId == doctor.id;

    return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppColors.darkDivider : AppColors.divider,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.doctorPrimary.withValues(alpha: 0.12),
                    child: Text(
                      (doctor.name.isNotEmpty ? doctor.name[0] : 'D').toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.doctorPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doctor.name.isNotEmpty ? 'Dr. ${doctor.name}' : 'Doctor',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          doctor.specialization,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                doctor.clinicName,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isSubmitting ? null : () => _requestConsultation(doctor),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.doctorPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(isSubmitting ? 'Sending...' : 'Request Consultation'),
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: (120 + index * 70).ms, duration: 350.ms)
        .slideY(begin: 0.04);
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.divider,
        ),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, size: 40, color: AppColors.textTertiary),
          const SizedBox(height: 10),
          Text(
            'No doctors available right now.',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Please try again later.',
            style: TextStyle(
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
