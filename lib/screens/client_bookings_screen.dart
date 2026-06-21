import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/booking_model.dart';
import '../services/booking_service.dart';
import '../theme/app_colors.dart';

import '../widgets/review_rating_modal.dart';

class ClientBookingsScreen extends StatefulWidget {
  const ClientBookingsScreen({super.key});

  @override
  State<ClientBookingsScreen> createState() => _ClientBookingsScreenState();
}

class _ClientBookingsScreenState extends State<ClientBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _bookingService = BookingService.instance;
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'My Bookings',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.neonAccent,
          unselectedLabelColor: AppColors.onSurfaceVariant,
          indicatorColor: AppColors.neonAccent,
          indicatorWeight: 3,
          dividerColor: AppColors.whiteBorder5,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: StreamBuilder<List<BookingModel>>(
        stream: FirebaseFirestore.instance.collection('bookings').where('clientId', isEqualTo: uid).snapshots().map((snapshot) => snapshot.docs.map((doc) => BookingModel.fromFirestore(doc)).toList()),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final bookings = snapshot.data ?? [];
          final activeBookings = bookings.where((b) => b.isActive).toList();
          final historyBookings = bookings.where((b) => !b.isActive).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildList(activeBookings, isActiveTab: true),
              _buildList(historyBookings, isActiveTab: false),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(List<BookingModel> bookings, {required bool isActiveTab}) {
    if (bookings.isEmpty) {
      return Center(
        child: Text(
          isActiveTab ? 'No active bookings.' : 'No booking history.',
          style: GoogleFonts.inter(
            fontSize: 15,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      );
    }

    // Sort by updated time, newest first
    bookings.sort((a, b) {
      final aTime = a.updatedAt ?? a.createdAt;
      final bTime = b.updatedAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final booking = bookings[index];
        return _BookingCard(booking: booking, isActiveTab: isActiveTab);
      },
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.isActiveTab});

  final BookingModel booking;
  final bool isActiveTab;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.whiteBorder5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.handyman_rounded,
                    color: AppColors.neonAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.serviceName,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      booking.technicianName,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isActiveTab)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: booking.normalizedStatus == 'completed'
                        ? AppColors.success.withValues(alpha: 0.2)
                        : AppColors.emergency.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    booking.status.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: booking.normalizedStatus == 'completed'
                          ? AppColors.success
                          : AppColors.emergency,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (isActiveTab) _DeliveryTimeline(booking: booking),
          if (isActiveTab && booking.normalizedStatus == 'quote_sent')
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _EstimateCard(booking: booking),
            ),
          if (isActiveTab &&
              booking.normalizedStatus == 'completed_pending_confirmation')
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _CompletionConfirmationCard(booking: booking),
            ),
          if (!isActiveTab && booking.normalizedStatus == 'completed') ...[
            const SizedBox(height: 16),
            Divider(color: AppColors.whiteBorder5),
            const SizedBox(height: 12),
            _ActionButton(
              label: 'Leave a Review',
              icon: Icons.star_border_rounded,
              color: Colors.amberAccent,
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => ReviewRatingModal(
                    booking: booking,
                    onComplete: () => Navigator.of(ctx).pop(),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _DeliveryTimeline extends StatelessWidget {
  const _DeliveryTimeline({required this.booking});

  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    final status = booking.normalizedStatus;

    // Define the sequence of steps
    final steps = [
      {'key': 'pending_quote', 'label': 'Request Sent'},
      {'key': 'quote_sent', 'label': 'Estimate Sent'},
      {'key': 'accepted', 'label': 'Accepted'},
      {'key': 'in_progress', 'label': 'Work Started'},
      {'key': 'completed_pending_confirmation', 'label': 'Awaiting Confirmation'},
      {'key': 'completed', 'label': 'Completed'},
    ];

    int currentIndex = 0;
    if (status == 'completed') currentIndex = 5;
    else if (status == 'completed_pending_confirmation') currentIndex = 4;
    else if (status == 'in_progress') currentIndex = 3;
    else if (status == 'accepted') currentIndex = 2;
    else if (status == 'quote_sent') currentIndex = 1;
    else if (status == 'pending_quote' || status == 'pending') currentIndex = 0;
    else {
      // For legacy statuses
      if (status == 'confirmed') currentIndex = 2;
      else if (status == 'on_the_way' || status == 'arrived') currentIndex = 2;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isCompleted = index < currentIndex;
        final isCurrent = index == currentIndex;
        final isLast = index == steps.length - 1;

        return _TimelineItem(
          label: step['label']!,
          isCompleted: isCompleted,
          isCurrent: isCurrent,
          isLast: isLast,
        );
      }),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.label,
    required this.isCompleted,
    required this.isCurrent,
    required this.isLast,
  });

  final String label;
  final bool isCompleted;
  final bool isCurrent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = isCompleted
        ? AppColors.success
        : isCurrent
            ? AppColors.neonAccent
            : AppColors.onSurfaceVariant.withValues(alpha: 0.3);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? AppColors.success : Colors.transparent,
                border: Border.all(
                  color: color,
                  width: 2,
                ),
              ),
              child: isCompleted
                  ? Icon(Icons.check, size: 14, color: AppColors.background)
                  : isCurrent
                      ? Center(
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.neonAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 24,
                color: isCompleted ? AppColors.success : AppColors.onSurfaceVariant.withValues(alpha: 0.2),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              color: isCurrent || isCompleted
                  ? AppColors.onSurface
                  : AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _EstimateCard extends StatelessWidget {
  const _EstimateCard({required this.booking});

  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neonAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estimate from ${booking.technicianName}',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Estimated Price',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              Text(
                '${(booking.technicianEstimatedPrice ?? 0).toStringAsFixed(0)} MAD',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.neonAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Duration',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              Text(
                booking.technicianEstimatedDuration ?? 'TBD',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          if (booking.technicianNote != null && booking.technicianNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Divider(color: AppColors.whiteBorder5),
            const SizedBox(height: 8),
            Text(
              'Note from ${booking.technicianName}',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              booking.technicianNote!,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.onSurface,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Decline',
                  icon: Icons.close_rounded,
                  color: AppColors.onSurfaceVariant,
                  onTap: () => _decline(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  label: 'Accept',
                  icon: Icons.check_rounded,
                  color: AppColors.neonAccent,
                  filled: true,
                  onTap: () => _accept(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _CostRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          Text(
            '${amount.toStringAsFixed(0)} MAD',
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

  Future<void> _accept(BuildContext context) async {
    HapticFeedback.mediumImpact();
    try {
      await BookingService.instance.updateBookingStatus(
        bookingId: booking.id,
        newStatus: 'accepted',
        clientId: booking.clientId,
        technicianId: booking.technicianId,
        technicianName: booking.technicianName,
        serviceName: booking.serviceName,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estimate accepted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _decline(BuildContext context) async {
    HapticFeedback.lightImpact();
    try {
      await BookingService.instance.updateBookingStatus(
        bookingId: booking.id,
        newStatus: 'rejected',
        clientId: booking.clientId,
        technicianId: booking.technicianId,
        technicianName: booking.technicianName,
        serviceName: booking.serviceName,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estimate declined')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}

class _CompletionConfirmationCard extends StatefulWidget {
  const _CompletionConfirmationCard({required this.booking});

  final BookingModel booking;

  @override
  State<_CompletionConfirmationCard> createState() =>
      _CompletionConfirmationCardState();
}

class _CompletionConfirmationCardState
    extends State<_CompletionConfirmationCard> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    if (_confirmed) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.success),
                const SizedBox(width: 8),
                Text(
                  'Job completed successfully',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Later',
                    icon: Icons.schedule_rounded,
                    color: AppColors.onSurfaceVariant,
                    onTap: () {
                      setState(() => _confirmed = false);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    label: 'Leave a Review',
                    icon: Icons.star_rounded,
                    color: Colors.amberAccent,
                    filled: true,
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => ReviewRatingModal(
                          booking: widget.booking,
                          onComplete: () => Navigator.of(ctx).pop(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.whiteBorder5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Job completed by ${widget.booking.technicianName}',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: _ActionButton(
              label: 'Confirm Completion',
              icon: Icons.check_rounded,
              color: AppColors.success,
              filled: true,
              onTap: () async {
                HapticFeedback.mediumImpact();
                try {
                  await BookingService.instance.updateBookingStatus(
                    bookingId: widget.booking.id,
                    newStatus: 'completed',
                    clientId: widget.booking.clientId,
                    technicianId: widget.booking.technicianId,
                    technicianName: widget.booking.technicianName,
                    serviceName: widget.booking.serviceName,
                  );
                  if (mounted) {
                    setState(() => _confirmed = true);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? AppColors.onPrimary : color;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: filled ? color : color.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: foreground, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
