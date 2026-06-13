import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/smart_device.dart';
import '../../../theme/app_colors.dart';

class SmartHomeSearchDelegate extends SearchDelegate<SmartDevice?> {
  final List<SmartDevice> devices;

  SmartHomeSearchDelegate(this.devices);

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: GoogleFonts.inter(color: AppColors.onSurfaceVariant.withValues(alpha: 0.5)),
        border: InputBorder.none,
      ),
      textTheme: TextTheme(
        titleLarge: GoogleFonts.inter(
          color: AppColors.onSurface,
          fontSize: 18,
        ),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded, color: AppColors.onSurfaceVariant),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.onSurface),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildList();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildList();
  }

  Widget _buildList() {
    final filtered = devices.where((d) {
      final text = query.toLowerCase();
      return d.name.toLowerCase().contains(text) ||
          d.room.toLowerCase().contains(text) ||
          d.type.label.toLowerCase().contains(text);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No devices found',
          style: GoogleFonts.inter(color: AppColors.onSurfaceVariant),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        return ListTile(
          onTap: () => close(context, item),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.type.getIcon(item.isOn),
              color: item.isOn ? AppColors.neonAccent : AppColors.onSurfaceVariant,
            ),
          ),
          title: Text(
            item.name,
            style: GoogleFonts.inter(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            SmartRoom.fromString(item.room).label,
            style: GoogleFonts.inter(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          trailing: Text(
            item.statusText,
            style: GoogleFonts.inter(
              color: item.isOn ? AppColors.neonAccent : AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      },
    );
  }
}
