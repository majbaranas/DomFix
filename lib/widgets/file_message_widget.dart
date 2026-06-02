import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';

class FileMessageWidget extends StatelessWidget {
  final String fileUrl;
  final String fileName;
  final bool isCurrentUser;

  const FileMessageWidget({
    super.key,
    required this.fileUrl,
    required this.fileName,
    required this.isCurrentUser,
  });

  String _getFileExtension() {
    final parts = fileName.split('.');
    return parts.length > 1 ? parts.last.toUpperCase() : 'FILE';
  }

  IconData _getFileIcon() {
    final ext = _getFileExtension().toLowerCase();
    if (ext == 'pdf') return Icons.picture_as_pdf;
    if (['doc', 'docx'].contains(ext)) return Icons.description;
    if (['xls', 'xlsx'].contains(ext)) return Icons.table_chart;
    if (['zip', 'rar'].contains(ext)) return Icons.folder_zip;
    return Icons.insert_drive_file;
  }

  Future<void> _openFile() async {
    final uri = Uri.parse(fileUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openFile,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isCurrentUser
              ? AppColors.primaryContainer.withValues(alpha: 0.1)
              : AppColors.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // File icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? AppColors.primaryContainer.withValues(alpha: 0.2)
                    : AppColors.onSurfaceVariant.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getFileIcon(),
                color: isCurrentUser
                    ? AppColors.primaryContainer
                    : AppColors.onSurface,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            // File info
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 150,
                  child: Text(
                    fileName,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getFileExtension(),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            // Download icon
            Icon(
              Icons.download,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
