import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_colors.dart';
import '../../../widgets/premium/glass_card.dart';
import '../../../widgets/premium/gradient_button.dart';
import 'jobs_pipeline_screen.dart'; // To get TechnicianQueueItem

class JobFlowTracker extends StatefulWidget {
  final TechnicianQueueItem item;
  final ValueChanged<String> onStatusUpdated;

  const JobFlowTracker({
    super.key,
    required this.item,
    required this.onStatusUpdated,
  });

  @override
  State<JobFlowTracker> createState() => _JobFlowTrackerState();
}

class _JobFlowTrackerState extends State<JobFlowTracker> {
  late String _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.item.status.toLowerCase().trim();
  }

  // Simplified linear workflow
  final List<String> _workflowSteps = [
    'accepted',
    'on_the_way',
    'arrived',
    'in_progress',
    'completed',
  ];

  final Map<String, String> _stepLabels = {
    'accepted': 'Request Accepted',
    'on_the_way': 'On The Way',
    'arrived': 'Arrived at Location',
    'in_progress': 'Job in Progress',
    'completed': 'Completed',
  };

  int get _currentStepIndex {
    final index = _workflowSteps.indexOf(_currentStatus);
    return index == -1 ? 0 : index;
  }

  String get _nextStatus {
    final idx = _currentStepIndex;
    if (idx < _workflowSteps.length - 1) {
      return _workflowSteps[idx + 1];
    }
    return _currentStatus;
  }

  String get _nextActionLabel {
    final next = _nextStatus;
    switch (next) {
      case 'on_the_way': return 'Start Trip';
      case 'arrived': return 'Mark as Arrived';
      case 'in_progress': return 'Start Job';
      case 'completed': return 'Complete Job';
      default: return 'Done';
    }
  }

  IconData get _nextActionIcon {
    final next = _nextStatus;
    switch (next) {
      case 'on_the_way': return Icons.directions_car_rounded;
      case 'arrived': return 'Mark as Arrived' == _nextActionLabel ? Icons.location_on_rounded : Icons.location_on_rounded;
      case 'in_progress': return Icons.build_rounded;
      case 'completed': return Icons.check_circle_rounded;
      default: return Icons.check_rounded;
    }
  }

  void _advanceStatus() {
    final next = _nextStatus;
    if (next != _currentStatus) {
      setState(() => _currentStatus = next);
      widget.onStatusUpdated(next);
      
      if (next == 'completed') {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDone = _currentStatus == 'completed';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Job Tracker',
          style: GoogleFonts.spaceGrotesk(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildClientInfoCard(),
                    const SizedBox(height: 32),
                    Text(
                      'PROGRESS',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildTimeline(),
                  ],
                ),
              ),
            ),
            if (!isDone)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: GradientButton(
                  onPressed: _advanceStatus,
                  text: _nextActionLabel,
                  icon: _nextActionIcon,
                  gradientColors: [AppColors.neonAccent, AppColors.success],
                  textColor: AppColors.onPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientInfoCard() {
    final booking = widget.item.booking;
    
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.surfaceContainerHigh,
                child: Icon(Icons.person_rounded, color: AppColors.onSurfaceVariant, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.serviceTitle,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Client ID: \${widget.item.clientId.substring(0, 8)}...',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (booking != null && booking.description.isNotEmpty) ...[
            Text(
              'DESCRIPTION',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              booking.description,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (booking != null && booking.imageUrls.isNotEmpty) ...[
            Text(
              'PHOTOS',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: booking.imageUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final url = booking.imageUrls[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: url.isNotEmpty
                        ? Image.network(
                            url,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 80,
                              height: 80,
                              color: AppColors.surfaceContainerHigh,
                              child: Icon(Icons.broken_image_rounded, color: AppColors.onSurfaceVariant, size: 24),
                            ),
                          )
                        : Container(
                            width: 80,
                            height: 80,
                            color: AppColors.surfaceContainerHigh,
                            child: Icon(Icons.image_not_supported_rounded, color: AppColors.onSurfaceVariant, size: 24),
                          ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: _buildActionBtn(Icons.chat_bubble_rounded, 'Message'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionBtn(Icons.call_rounded, 'Call'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: AppColors.onSurface),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    return Column(
      children: List.generate(_workflowSteps.length, (index) {
        final step = _workflowSteps[index];
        final isCompleted = _currentStepIndex >= index;
        final isCurrent = _currentStepIndex == index;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted ? AppColors.neonAccent : AppColors.surfaceContainerHigh,
                    border: Border.all(
                      color: isCompleted ? AppColors.neonAccent : AppColors.glassBorder,
                      width: 2,
                    ),
                  ),
                  child: isCompleted
                      ? Icon(Icons.check_rounded, size: 14, color: AppColors.onPrimary)
                      : null,
                ),
                if (index < _workflowSteps.length - 1)
                  Container(
                    width: 2,
                    height: 40,
                    color: isCompleted ? AppColors.neonAccent : AppColors.glassBorder,
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _stepLabels[step]!,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                        color: isCompleted ? AppColors.onSurface : AppColors.onSurfaceVariant,
                      ),
                    ),
                    if (isCurrent)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Current Status',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.neonAccent,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
