import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/booking_model.dart';
import '../theme/app_colors.dart';
import 'chat_screen.dart';

class BookingConfirmationScreen extends StatefulWidget {
  final BookingModel booking;
  final String technicianName;
  final String? technicianPhotoUrl;

  const BookingConfirmationScreen({
    super.key,
    required this.booking,
    required this.technicianName,
    this.technicianPhotoUrl,
  });

  @override
  State<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          otherUserId: widget.booking.technicianId,
          otherUserName: widget.technicianName,
          otherUserRole: 'technician',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.onSurface,
                  ),
                  Text(
                    'Booking sent',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  SizedBox(width: 48),
                ],
              ),
              SizedBox(height: 24),
              Expanded(
                child: FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color:
                                  AppColors.neonAccent.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.neonAccent
                                    .withValues(alpha: 0.2),
                              ),
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: 72,
                              color: AppColors.neonAccent,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Your booking request is live',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Booking ID ${widget.booking.id.substring(0, 8)}…',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.neonAccent,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Full chat is unlocked now. You can share photos, send voice notes, and stay in real-time contact with ${widget.technicianName}.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              height: 1.6,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // ─── Real-time Status Tracker ─────────
                          _BookingStatusTracker(
                            bookingId: widget.booking.id,
                          ),
                          const SizedBox(height: 20),

                          _InfoCard(
                            booking: widget.booking,
                            technicianName: widget.technicianName,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _openChat,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.neonAccent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            'Open chat',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Center(
                          child: Text(
                            'Back to profile',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Real-time Status Tracker ─────────────────────────────

class _BookingStatusTracker extends StatelessWidget {
  final String bookingId;
  const _BookingStatusTracker({required this.bookingId});

  static const _statusSteps = [
    'pending',
    'accepted',
    'on_the_way',
    'in_progress',
    'completed',
  ];

  static const _statusLabels = {
    'pending': 'Pending review',
    'accepted': 'Accepted',
    'on_the_way': 'On the way',
    'in_progress': 'In progress',
    'completed': 'Completed',
    'rejected': 'Declined',
    'cancelled': 'Cancelled',
  };

  static const _statusIcons = {
    'pending': Icons.hourglass_top_rounded,
    'accepted': Icons.check_circle_outline_rounded,
    'on_the_way': Icons.directions_car_rounded,
    'in_progress': Icons.handyman_rounded,
    'completed': Icons.verified_rounded,
  };

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.statusPending;
      case 'accepted':
        return AppColors.statusAccepted;
      case 'on_the_way':
        return AppColors.statusOnTheWay;
      case 'in_progress':
        return AppColors.statusInProgress;
      case 'completed':
        return AppColors.statusCompleted;
      default:
        return AppColors.statusCancelled;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .snapshots(),
      builder: (context, snapshot) {
        String currentStatus = 'pending';
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          currentStatus =
              (data?['status'] as String? ?? 'pending').toLowerCase().trim();
        }

        // Handle rejected/cancelled
        if (currentStatus == 'rejected' || currentStatus == 'cancelled') {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.emergency.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.emergency.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.cancel_outlined,
                  color: AppColors.emergency,
                  size: 22,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _statusLabels[currentStatus] ?? currentStatus,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.emergency,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final currentIndex = _statusSteps.indexOf(currentStatus);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BOOKING STATUS',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              ...List.generate(_statusSteps.length, (index) {
                final step = _statusSteps[index];
                final isCompleted = index < currentIndex;
                final isActive = index == currentIndex;
                final isPending = index > currentIndex;
                final color = isCompleted || isActive
                    ? _statusColor(step)
                    : AppColors.surfaceContainerHigh;

                return Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: (isCompleted || isActive)
                                ? color.withValues(alpha: 0.15)
                                : AppColors.surfaceContainerHigh,
                            shape: BoxShape.circle,
                            border: isActive
                                ? Border.all(color: color, width: 2)
                                : null,
                          ),
                          child: Icon(
                            isCompleted
                                ? Icons.check_rounded
                                : _statusIcons[step] ??
                                    Icons.circle_outlined,
                            size: 16,
                            color: (isCompleted || isActive)
                                ? color
                                : AppColors.onSurfaceVariant
                                    .withValues(alpha: 0.3),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          _statusLabels[step] ?? step,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isPending
                                ? AppColors.onSurfaceVariant
                                    .withValues(alpha: 0.4)
                                : AppColors.onSurface,
                          ),
                        ),
                        if (isActive) ...[
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Current',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (index < _statusSteps.length - 1)
                      Padding(
                        padding: const EdgeInsets.only(left: 15),
                        child: Container(
                          width: 2,
                          height: 24,
                          color: isCompleted
                              ? color.withValues(alpha: 0.4)
                              : AppColors.surfaceContainerHigh,
                        ),
                      ),
                  ],
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

// ─── Info Card ────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final BookingModel booking;
  final String technicianName;

  const _InfoCard({
    required this.booking,
    required this.technicianName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.neonAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: AppColors.neonAccent,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      technicianName,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Conversation unlocked for service coordination',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _InfoRow(label: 'Service', value: booking.serviceName),
          const SizedBox(height: 10),
          _InfoRow(label: 'Schedule', value: booking.humanDate),
          const SizedBox(height: 10),
          _InfoRow(label: 'Time', value: booking.scheduledTimeLabel),
          const SizedBox(height: 10),
          _InfoRow(label: 'Priority', value: booking.urgency),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
