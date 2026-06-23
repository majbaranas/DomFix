import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import 'glass_card.dart';

class UberStyleJobCard extends StatelessWidget {
  final String clientName;
  final String serviceType;
  final String statusLabel;
  final Color statusColor;
  final String urgencyLabel;
  final Color urgencyColor;
  final String timeAgo;
  final String? distance;
  final String? clientImageUrl;
  final String? description;
  final List<String>? imageUrls;
  
  final VoidCallback? onPrimaryAction;
  final String? primaryActionLabel;
  final IconData? primaryActionIcon;
  
  final VoidCallback? onSecondaryAction;
  final String? secondaryActionLabel;
  final IconData? secondaryActionIcon;

  final VoidCallback? onTap;

  const UberStyleJobCard({
    super.key,
    required this.clientName,
    required this.serviceType,
    required this.statusLabel,
    required this.statusColor,
    required this.urgencyLabel,
    required this.urgencyColor,
    required this.timeAgo,
    this.distance,
    this.clientImageUrl,
    this.description,
    this.imageUrls,
    this.onPrimaryAction,
    this.primaryActionLabel,
    this.primaryActionIcon,
    this.onSecondaryAction,
    this.secondaryActionLabel,
    this.secondaryActionIcon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header section: client & status
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Client Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.surfaceContainerHigh,
                  backgroundImage: clientImageUrl != null && clientImageUrl!.isNotEmpty
                      ? NetworkImage(clientImageUrl!)
                      : null,
                  child: clientImageUrl == null || clientImageUrl!.isEmpty
                      ? Text(
                          clientName.isNotEmpty ? clientName[0].toUpperCase() : '?',
                          style: GoogleFonts.spaceGrotesk(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                // Client Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              clientName,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              statusLabel,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        serviceType,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Meta info: Urgency, Time, Distance
                      Row(
                        children: [
                          _buildMetaChip(urgencyLabel, urgencyColor, Icons.local_fire_department_rounded),
                          const SizedBox(width: 8),
                          _buildMetaChip(timeAgo, AppColors.onSurfaceVariant, Icons.schedule_rounded),
                          if (distance != null) ...[
                            const SizedBox(width: 8),
                            _buildMetaChip(distance!, AppColors.onSurfaceVariant, Icons.location_on_rounded),
                          ],
                        ],
                      ),
                      
                      // Booking Description
                      if (description != null && description!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          description!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.onSurfaceVariant,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      
                      // Booking Images
                      if (imageUrls != null && imageUrls!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 60,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: imageUrls!.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final url = imageUrls![index];
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: url.isNotEmpty
                                    ? Image.network(
                                        url,
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 60,
                                          height: 60,
                                          color: AppColors.surfaceContainerHigh,
                                          child: Icon(Icons.broken_image_rounded, color: AppColors.onSurfaceVariant, size: 20),
                                        ),
                                      )
                                    : Container(
                                        width: 60,
                                        height: 60,
                                        color: AppColors.surfaceContainerHigh,
                                        child: Icon(Icons.image_not_supported_rounded, color: AppColors.onSurfaceVariant, size: 20),
                                      ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Action Buttons Section
          if (onPrimaryAction != null || onSecondaryAction != null)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.glassBorder),
                ),
                color: AppColors.surfaceContainerLowest.withValues(alpha: 0.3),
              ),
              child: Row(
                children: [
                  if (onSecondaryAction != null)
                    Expanded(
                      child: _buildActionButton(
                        onSecondaryAction!,
                        secondaryActionLabel ?? 'Decline',
                        secondaryActionIcon ?? Icons.close_rounded,
                        AppColors.onSurfaceVariant,
                        isPrimary: false,
                      ),
                    ),
                  if (onSecondaryAction != null && onPrimaryAction != null)
                    Container(
                      width: 1,
                      height: 48,
                      color: AppColors.glassBorder,
                    ),
                  if (onPrimaryAction != null)
                    Expanded(
                      child: _buildActionButton(
                        onPrimaryAction!,
                        primaryActionLabel ?? 'Accept',
                        primaryActionIcon ?? Icons.check_rounded,
                        AppColors.neonAccent,
                        isPrimary: true,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(String label, Color color, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    VoidCallback onTap,
    String label,
    IconData icon,
    Color color, {
    required bool isPrimary,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: isPrimary ? FontWeight.bold : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
