import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/cupertino.dart';

import '../../models/automation.dart';
import '../../services/automation_service.dart';
import '../../theme/app_colors.dart';

class AutomationsScreen extends StatelessWidget {
  const AutomationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.onSurface),
        title: Text(
          'Automations',
          style: GoogleFonts.spaceGrotesk(
            color: AppColors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: StreamBuilder<List<AutomationRule>>(
        stream: AutomationService.instance.getRules(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.neonAccent),
            );
          }

          final rules = snapshot.data ?? [];
          if (rules.isEmpty) {
            return Center(
              child: Text(
                'No automations set',
                style: GoogleFonts.inter(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            itemCount: rules.length,
            itemBuilder: (context, index) {
              final rule = rules[index];
              return _AutomationCard(rule: rule);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Open Automation Builder
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Automation Builder coming soon')),
          );
        },
        backgroundColor: AppColors.neonAccent,
        child: const Icon(Icons.add_rounded, color: AppColors.onPrimary),
      ),
    );
  }
}

class _AutomationCard extends StatelessWidget {
  const _AutomationCard({required this.rule});
  final AutomationRule rule;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                rule.name,
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppColors.onSurface,
                ),
              ),
              CupertinoSwitch(
                value: rule.isEnabled,
                activeColor: AppColors.neonAccent,
                onChanged: (val) {
                  AutomationService.instance.toggleRule(rule.id, val);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildConditionRow(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 8),
            child: Icon(Icons.arrow_downward_rounded, size: 16, color: AppColors.onSurfaceVariant),
          ),
          _buildActionRow(),
        ],
      ),
    );
  }

  Widget _buildConditionRow() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.sensor_door_outlined, size: 20, color: Colors.orangeAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'IF ${rule.condition.attribute} ${rule.condition.operator.name} ${rule.condition.targetValue}',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.flash_on_rounded, size: 20, color: AppColors.neonAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'THEN Set ${rule.action.attribute} to ${rule.action.value}',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
