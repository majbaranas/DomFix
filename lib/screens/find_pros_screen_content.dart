import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../widgets/scroll_reveal.dart';
import 'nearby_technicians_map_screen.dart';
import '../services/technician_profile_service.dart';
import '../models/marketplace_technician.dart';
import 'technician_profile_screen.dart';

class FindProsScreenContent extends StatefulWidget {
  const FindProsScreenContent({super.key});
  @override
  State<FindProsScreenContent> createState() => _FindProsScreenContentState();
}

class _FindProsScreenContentState extends State<FindProsScreenContent> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  int _selectedChip = 0;
  final _searchFocus = FocusNode();
  String _searchQuery = '';
  static const _filters = [
    'All',
    'Smart Home',
    'Electrical Installation',
    'Solar Panels',
    'CCTV & Security',
    'Networking',
    'Home Automation',
    'Lighting Systems',
    'Energy Monitoring',
    'IoT Systems',
    'Access Control',
    'Intercom Systems'
  ];

  @override
  void dispose() { _searchFocus.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(children: [
                Text('Find Pros', style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NearbyTechniciansMapScreen())),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.divider)),
                    child: Icon(Icons.map_rounded, color: AppColors.neonAccent, size: 20),
                  ),
                ),
              ]),
            )),
            // Search
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: TextField(
                focusNode: _searchFocus,
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurface),
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search for services...', hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant.withValues(alpha: 0.4)),
                  prefixIcon: Icon(Icons.search_rounded, color: AppColors.onSurfaceVariant.withValues(alpha: 0.4), size: 20),
                  filled: true, fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            )),
            // Filter chips
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 0, 0),
              child: SizedBox(height: 38, child: ListView.separated(
                scrollDirection: Axis.horizontal, itemCount: _filters.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final sel = _selectedChip == i;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedChip = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(color: sel ? AppColors.neonAccent : AppColors.surface, borderRadius: BorderRadius.circular(20),
                        border: sel ? null : Border.all(color: AppColors.divider)),
                      child: Text(_filters[i], style: GoogleFonts.inter(fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? AppColors.onPrimary : AppColors.onSurfaceVariant)),
                    ),
                  );
                },
              )),
            )),
            // Results
            SliverFillRemaining(
              hasScrollBody: false,
              child: StreamBuilder<List<MarketplaceTechnician>>(
                stream: TechnicianProfileService().watchMarketplaceTechnicians(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: AppColors.neonAccent));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Could not load technicians', style: GoogleFonts.inter(color: AppColors.onSurfaceVariant)));
                  }
                  
                  var allTechs = snapshot.data ?? [];
                  
                  // Filter by search query
                  if (_searchQuery.isNotEmpty) {
                    allTechs = allTechs.where((t) => 
                      t.fullName.toLowerCase().contains(_searchQuery) ||
                      t.speciality.toLowerCase().contains(_searchQuery)
                    ).toList();
                  }
                  
                  // Filter by category chip
                  final selectedCategory = _filters[_selectedChip];
                  if (selectedCategory != 'All') {
                    allTechs = allTechs.where((t) {
                      final lowerQuery = selectedCategory.toLowerCase();
                      if (t.speciality.toLowerCase().contains(lowerQuery)) return true;
                      if (t.specialties.any((s) => s.toLowerCase().contains(lowerQuery))) return true;
                      return false;
                    }).toList();
                  }
                  
                  if (allTechs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.engineering_outlined, size: 48, color: AppColors.onSurfaceVariant.withValues(alpha: 0.3)),
                          const SizedBox(height: 16),
                          Text('No professionals found', style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                          const SizedBox(height: 8),
                          Text('Try adjusting your search filters.', style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant)),
                        ],
                      ),
                    );
                  }
                  
                  // Top 3 go to featured, rest go to nearby
                  final featured = allTechs.take(3).toList();
                  final nearby = allTechs.skip(3).toList();
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Featured Section
                      if (featured.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text('Top Rated', style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                            Text('View all', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.neonAccent)),
                          ]),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: HorizontalFadeHint(
                            color: AppColors.background,
                            child: SizedBox(height: 210, child: ListView.separated(
                              scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20),
                              itemCount: featured.length, separatorBuilder: (_, _) => const SizedBox(width: 12),
                              itemBuilder: (_, i) => RevealItem(
                                delay: Duration(milliseconds: i * 90),
                                child: _FeaturedCard(tech: featured[i]),
                              ),
                            )),
                          ),
                        ),
                      ],
                      
                      // Nearby Section
                      if (nearby.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                          child: Text('More Specialists', style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                        ),
                        ...List.generate(nearby.length, (i) => Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          child: RevealItem(
                            delay: Duration(milliseconds: i * 70 > 210 ? 210 : i * 70),
                            child: _NearbyCard(tech: nearby[i]),
                          ),
                        )),
                      ],
                      const SizedBox(height: 120), // Bottom padding
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final MarketplaceTechnician tech;
  const _FeaturedCard({required this.tech});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TechnicianProfileScreen(technicianId: tech.id))),
      child: SizedBox(width: 180, child: Material(
        color: AppColors.surface, borderRadius: BorderRadius.circular(12), clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(height: 140, child: Stack(fit: StackFit.expand, children: [
            if (tech.profileImage != null)
              Image.network(tech.profileImage!, fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(color: AppColors.surfaceContainerHigh, child: Icon(Icons.engineering_outlined, color: AppColors.onSurfaceVariant, size: 40)))
            else
              Container(color: AppColors.surfaceContainerHigh, child: Icon(Icons.engineering_outlined, color: AppColors.onSurfaceVariant, size: 40)),
            
            Positioned(top: 8, right: 8, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AppColors.background.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(6)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.star_rounded, size: 13, color: AppColors.neonAccent),
                const SizedBox(width: 3),
                Text(tech.rating > 0 ? tech.rating.toStringAsFixed(1) : 'New', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
              ]),
            )),
            
            if (tech.isOnline)
              Positioned(bottom: 8, left: 8, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.success.withValues(alpha: 0.5))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text('Live', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.success)),
                ]),
              )),
          ])),
          Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tech.fullName, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(tech.speciality, style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
        ]),
      )),
    );
  }
}

class _NearbyCard extends StatelessWidget {
  final MarketplaceTechnician tech;
  const _NearbyCard({required this.tech});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TechnicianProfileScreen(technicianId: tech.id))),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(borderRadius: BorderRadius.circular(10),
            child: tech.profileImage != null
              ? Image.network(tech.profileImage!, width: 72, height: 72, fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(width: 72, height: 72, color: AppColors.surfaceContainerHigh, child: Icon(Icons.person_outline, color: AppColors.onSurfaceVariant)))
              : Container(width: 72, height: 72, color: AppColors.surfaceContainerHigh, child: Icon(Icons.person_outline, color: AppColors.onSurfaceVariant))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(
                  children: [
                    Expanded(child: Text(tech.fullName, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (tech.isOnline)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        width: 8, height: 8,
                        decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.success.withValues(alpha: 0.5), blurRadius: 4)]),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(tech.speciality, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.neonAccent), maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.star_rounded, size: 14, color: AppColors.neonAccent), const SizedBox(width: 3),
              Text(tech.rating > 0 ? tech.rating.toStringAsFixed(1) : 'New', style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
              const SizedBox(width: 14),
              Icon(Icons.work_rounded, size: 12, color: AppColors.onSurfaceVariant), const SizedBox(width: 3),
              Text('${tech.jobsCompleted} jobs', style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
              if (tech.distanceKm < double.infinity) ...[
                const SizedBox(width: 14),
                Icon(Icons.near_me_outlined, size: 12, color: AppColors.onSurfaceVariant), const SizedBox(width: 3),
                Text('${tech.distanceKm.toStringAsFixed(1)} km', style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
              ]
            ]),
          ])),
        ]),
      ),
    );
  }
}
