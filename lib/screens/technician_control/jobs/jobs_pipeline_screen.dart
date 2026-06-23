import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import '../../../theme/app_colors.dart';
import '../../../models/booking_model.dart';
import '../../../services/technician_location_service.dart';
import '../../../widgets/premium/uber_style_job_card.dart';
import '../../booking_details_screen.dart';
import 'job_flow_tracker.dart';

class JobsPipelineScreen extends StatefulWidget {
  const JobsPipelineScreen({super.key});

  @override
  State<JobsPipelineScreen> createState() => _JobsPipelineScreenState();
}

class _JobsPipelineScreenState extends State<JobsPipelineScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _firestore = FirebaseFirestore.instance;
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

  int _compareRequests(TechnicianQueueItem a, TechnicianQueueItem b) {
    if (a.urgencyPriority != b.urgencyPriority) {
      return a.urgencyPriority.compareTo(b.urgencyPriority);
    }
    if (a.workflowPriority != b.workflowPriority) {
      return a.workflowPriority.compareTo(b.workflowPriority);
    }
    return b.updatedAt.compareTo(a.updatedAt);
  }

  List<TechnicianQueueItem> _mergeRequests(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> jobDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> bookingDocs,
    LatLng? techLocation,
  ) {
    final items = <TechnicianQueueItem>[
      ...jobDocs.map(TechnicianQueueItem.fromJobDoc),
      ...bookingDocs.map((doc) => TechnicianQueueItem.fromBooking(
            BookingModel.fromFirestore(doc),
            techLocation,
          )),
    ];
    items.sort(_compareRequests);
    return items;
  }

  Future<void> _updateBookingStatus(String bookingId, String status) async {
    await _firestore.collection('bookings').doc(bookingId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updateJobStatus(String jobId, String status) async {
    await _firestore.collection('jobs').doc(jobId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _acceptRequest(TechnicianQueueItem item) {
    HapticFeedback.lightImpact();
    if (item.isBooking) {
      _updateBookingStatus(item.id, 'accepted');
    } else {
      _updateJobStatus(item.id, 'accepted');
    }
    _tabController.animateTo(1); // Switch to active tab
  }

  void _declineRequest(TechnicianQueueItem item) {
    HapticFeedback.lightImpact();
    if (item.isBooking) {
      _updateBookingStatus(item.id, 'rejected');
    } else {
      _updateJobStatus(item.id, 'rejected');
    }
  }

  void _openJobTracker(TechnicianQueueItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JobFlowTracker(
          item: item,
          onStatusUpdated: (status) {
            if (item.isBooking) {
              _updateBookingStatus(item.id, status);
            } else {
              _updateJobStatus(item.id, status);
            }
          },
        ),
      ),
    );
  }

  String _timeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 60) return '\${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '\${diff.inHours}h ago';
    return '\${diff.inDays}d ago';
  }

  Color _urgencyColor(String urgency) {
    switch (urgency.toLowerCase().trim()) {
      case 'emergency': return AppColors.emergency;
      case 'high':
      case 'urgent': return AppColors.highPriority;
      case 'medium':
      case 'standard':
      case 'normal': return AppColors.mediumPriority;
      case 'low': return AppColors.lowPriority;
      default: return AppColors.mediumPriority;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Text(
              'Pipeline',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: AppColors.neonAccent,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.neonAccent.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                labelColor: AppColors.onPrimary,
                unselectedLabelColor: AppColors.onSurfaceVariant,
                labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
                unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Pending'),
                  Tab(text: 'Active'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _firestore.collection('technician_locations').doc(uid).snapshots(),
              builder: (context, techLocSnapshot) {
                LatLng? techLocation;
                final techData = techLocSnapshot.data?.data();
                if (techData != null) {
                  final lat = (techData['lat'] as num?)?.toDouble() ?? (techData['location']?['lat'] as num?)?.toDouble();
                  final lng = (techData['lng'] as num?)?.toDouble() ?? (techData['location']?['lng'] as num?)?.toDouble();
                  if (lat != null && lng != null) {
                    techLocation = LatLng(lat, lng);
                  }
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _firestore.collection('jobs').where('technicianId', isEqualTo: uid).snapshots(),
                  builder: (context, jobsSnapshot) {
                    final jobDocs = jobsSnapshot.data?.docs ?? const [];
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _firestore.collection('bookings').where('technicianId', isEqualTo: uid).snapshots(),
                      builder: (context, bookingsSnapshot) {
                        final bookingDocs = bookingsSnapshot.data?.docs ?? const [];
                        final items = _mergeRequests(jobDocs, bookingDocs, techLocation);
                        final pending = items.where((i) => i.isPending).toList();
                        final active = items.where((i) => i.isActive).toList();

                        return TabBarView(
                          controller: _tabController,
                          children: [
                            _buildList(pending, true),
                            _buildList(active, false),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<TechnicianQueueItem> items, bool isPending) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPending ? Icons.inbox_outlined : Icons.work_outline_rounded,
              size: 48,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              isPending ? 'No pending requests' : 'No active jobs',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildCard(item, isPending);
      },
    );
  }

  Widget _buildCard(TechnicianQueueItem item, bool isPending) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _firestore.collection('users').doc(item.clientId).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final clientName = (data?['fullName'] ?? data?['name'] ?? 'Client').toString();
        final clientImageUrl = data?['photoUrl'] as String?;

          return UberStyleJobCard(
            clientName: clientName,
            serviceType: item.serviceTitle,
            statusLabel: item.status.toUpperCase(),
            statusColor: AppColors.neonAccent,
            urgencyLabel: item.urgency,
            urgencyColor: _urgencyColor(item.urgency),
            timeAgo: _timeAgo(item.updatedAt),
            distance: item.distanceKm > 0 ? '${item.distanceKm.toStringAsFixed(1)} km' : null,
            clientImageUrl: clientImageUrl,
            description: item.booking?.description,
            imageUrls: item.booking?.imageUrls,
            primaryActionLabel: isPending ? 'View Details' : 'Open Tracker',
            primaryActionIcon: isPending ? Icons.visibility_rounded : Icons.open_in_new_rounded,
            onPrimaryAction: () {
              if (isPending) {
                if (item.isBooking && item.booking != null) {
                   Navigator.push(
                     context,
                     MaterialPageRoute(
                       builder: (_) => BookingDetailsScreen(
                         booking: item.booking!,
                         distanceKm: item.distanceKm > 0 ? item.distanceKm : null,
                       ),
                     ),
                   );
                } else {
                   // Fallback for generic jobs that don't have full details
                   _acceptRequest(item);
                }
              } else {
                _openJobTracker(item);
              }
            },
            secondaryActionLabel: isPending ? 'Decline' : null,
            secondaryActionIcon: isPending ? Icons.close_rounded : null,
            onSecondaryAction: isPending ? () => _declineRequest(item) : null,
            onTap: () {
              if (item.isBooking && item.booking != null) {
                 Navigator.push(
                   context,
                   MaterialPageRoute(
                     builder: (_) => BookingDetailsScreen(
                       booking: item.booking!,
                       distanceKm: item.distanceKm > 0 ? item.distanceKm : null,
                     ),
                   ),
                 );
              }
            },
          );
      },
    );
  }
}

class TechnicianQueueItem {
  final String id;
  final bool isBooking;
  final BookingModel? booking;
  final Map<String, dynamic>? jobData;
  final String clientId;
  final String serviceTitle;
  final String urgency;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double distanceKm;

  const TechnicianQueueItem._({
    required this.id,
    required this.isBooking,
    required this.clientId,
    required this.serviceTitle,
    required this.urgency,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.distanceKm,
    this.booking,
    this.jobData,
  });

  factory TechnicianQueueItem.fromJobDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate() ?? createdAt;
    return TechnicianQueueItem._(
      id: doc.id,
      isBooking: false,
      jobData: data,
      clientId: (data['userId'] ?? data['clientId'] ?? '').toString(),
      serviceTitle: (data['serviceName'] ?? data['problemDescription'] ?? 'Service request').toString(),
      urgency: (data['urgency'] ?? 'Medium').toString(),
      status: (data['status'] ?? 'pending').toString(),
      createdAt: createdAt,
      updatedAt: updatedAt,
      distanceKm: (data['distance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  factory TechnicianQueueItem.fromBooking(BookingModel booking, LatLng? techLocation) {
    double distance = 0.0;
    if (techLocation != null && booking.clientLat != null && booking.clientLng != null) {
      distance = TechnicianLocationService.distanceKmPublic(
        techLocation,
        LatLng(booking.clientLat!, booking.clientLng!),
      );
    }
    return TechnicianQueueItem._(
      id: booking.id,
      isBooking: true,
      booking: booking,
      clientId: booking.clientId,
      serviceTitle: booking.serviceName,
      urgency: booking.urgency,
      status: booking.status,
      createdAt: booking.createdAt,
      updatedAt: booking.updatedAt ?? booking.createdAt,
      distanceKm: distance,
    );
  }

  int get urgencyPriority {
    switch (urgency.toLowerCase().trim()) {
      case 'emergency': return 0;
      case 'high':
      case 'urgent': return 1;
      case 'medium':
      case 'standard':
      case 'normal': return 2;
      case 'low': return 3;
      default: return 2;
    }
  }

  int get workflowPriority {
    final normalized = status.toLowerCase().trim();
    if (isBooking) {
      return switch (normalized) {
        'in_progress' => 0,
        'arrived' => 1,
        'on_the_way' => 2,
        'accepted' => 3,
        'confirmed' => 3,
        'pending' => 4,
        _ => 5,
      };
    }
    return switch (normalized) {
      'in_progress' => 0,
      'accepted' => 1,
      'pending' => 4,
      _ => 5,
    };
  }

  bool get isPending {
    final normalized = status.toLowerCase().trim();
    return normalized == 'pending' ||
        normalized == 'pending_quote' ||
        normalized == 'inspection_requested' ||
        normalized == 'inspection_completed';
  }

  bool get isActive {
    final normalized = status.toLowerCase().trim();
    if (isBooking) {
      return normalized == 'accepted' ||
          normalized == 'quote_sent' ||
          normalized == 'confirmed' ||
          normalized == 'on_the_way' ||
          normalized == 'arrived' ||
          normalized == 'in_progress' ||
          normalized == 'inspection_accepted';
    }
    return normalized == 'accepted' || normalized == 'in_progress';
  }
}
