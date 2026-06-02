import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../widgets/scroll_reveal.dart';
import 'nearby_technicians_map_screen.dart';

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
  static const _filters = ['Electrician', 'Plumber', 'AC Repair', 'Smart Home'];

  static const _featured = [
    _FeaturedTech(name: 'Marcus Chen', role: 'Master Electrician', rating: 5.0,
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBYHStyv6hCK3LR_QvLh4fxlzuqK-K6KoV1SS8Fx28ExWPyi-nqCkWh1QH_joy8VBZa3-lY6vVCDAmqapjM9azgmzrX-N_NP9nE39ZxBfhT-4qSxbLaj-jxxFXAwsrt3JqS7uT0lvN0ttEa_4A5VTg3TR1DPXaDnuJE17eUO7RxvR3aZFTNiNwxJ6ETmb2xFc0OfOLcLiUTqT7qIBP9rpH_9MtF5kPc33-_6s4CoKqNuKeaWTfhXCtJPF9DyuvFKiPXEleRXxwUSK0'),
    _FeaturedTech(name: 'David Miller', role: 'HVAC Expert', rating: 4.9,
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuA5aOohgty6RQbgYza0SPtrM9IU9-e2znYHALsQ-yYjgZhYTh6bGVSinlcRMVvQsA-2gmhax04UChRX26rgGrHPEhzgsyWQYKnYd-WyNsCIUjClz2cVgzw8Wv469q4K14Io7QrhpUd1uL__WFmEZz7_6OHePaJmtefR9m3YY9LgiDuCz_0lEyEOb3wRZUND0BeEFXr4QbAsySMu229jxXI9uSyHI3fHwzsRRp54gq0ceLjGS71vducNwGAY8odR96NmFxpK4MJpfsY'),
  ];

  static const _nearby = [
    _ListTech(name: 'Alex Rivera', role: 'Senior Electrician', rateLabel: r'$45', rating: 4.9, distanceKm: 2.3, tagline: 'Certified specialist in smart circuit integration.',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCTolk3hRuZ_BeH7YH5ALokCxt2YBQA1lQZfSY8yvaXQyHqi9TWRA3OZBhAy8L87bNA-f1gUtLRDCMS7kr25jU4qiNBIIWXbDoDW7xYw5moHLMqilJw8HwleTNrgE39w8kDVz7UP_a5_JdJQ5K1dhuwY9wo0IOvWvbQTOP4f28UqyrotwpcPsk_c9YGvjAyRFm2n9ycGOIpHGi8dR394Lfk_X7s-EK0s7kQN2l8EvM4Pr6Xq8dkIs_oCYG-tyX_PSn6oPumL5S1b9c'),
    _ListTech(name: 'Sarah Jenkins', role: 'Plumbing Expert', rateLabel: r'$50', rating: 4.8, distanceKm: 1.5, tagline: 'Emergency repairs and installations specialist.',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCZIYXV4_F_1mHFEZEiDbeMUesNjve78Jr0jbg3riONxPU8SyLVucU6sHOoRGOUvVcp-VCN8yRC8N5mqCkSPNtg2XbT3qlmYx2C0GCtnTaSX0CpKclMZoY_amzMnrhzwwFZOkNWHf1_lZdMfFezQDCXZBrzdIi6wQ7xGvtBtBVzph6n7db56k8Zy5xJmI-uXdugO66J3BTX09JizCyZcs7ozBPW36wKKWVZ_DQVp84B7239qQ4DwSKhtWJXOZKMbjL6vitP8EE57FQ'),
    _ListTech(name: 'James Wilson', role: 'Appliance Repair', rateLabel: r'$38', rating: 4.7, distanceKm: 3.1, tagline: 'Expert in all major household appliance brands.',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDkI_oKbPnUKA3KG5EyDZtegPnGwfDK4_exMxlV9QkjybaAm9hj1OKdhbYlBBRI_a9m3qwY03X47WmHpLqQPuoCrz0kre11ljSnw6RMkEsjnhP18hhpvSPvhp42pqJIY-WQy0WpsD6LOGkVIjCPoCkv5IjnHxy2tP3S2fyCzHK68ACokJARIU66leJwLeN_2FjEZvGvbH_ocaZl4T-P9ZOEqbCz-SQshI0Annlf6fB0QsGi8XIerYgszO-viAXb6plI0I9IzQPviw'),
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
            // Featured
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Top Rated', style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                Text('View all', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.neonAccent)),
              ]),
            )),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: HorizontalFadeHint(
                color: AppColors.background,
                child: SizedBox(height: 210, child: ListView.separated(
                  scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _featured.length, separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => RevealItem(
                    delay: Duration(milliseconds: i * 90),
                    child: _FeaturedCard(tech: _featured[i]),
                  ),
                )),
              ),
            )),
            // Nearby
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Text('Nearby Specialists', style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
            )),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              sliver: SliverList(delegate: SliverChildBuilderDelegate(
                (_, i) => RevealItem(
                  delay: Duration(milliseconds: i * 70 > 210 ? 210 : i * 70),
                  child: Padding(padding: const EdgeInsets.only(bottom: 12), child: _NearbyCard(tech: _nearby[i])),
                ),
                childCount: _nearby.length,
              )),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedTech { final String name, role, imageUrl; final double rating; const _FeaturedTech({required this.name, required this.role, required this.rating, required this.imageUrl}); }

class _FeaturedCard extends StatelessWidget {
  final _FeaturedTech tech;
  const _FeaturedCard({required this.tech});
  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 180, child: Material(
      color: AppColors.surface, borderRadius: BorderRadius.circular(12), clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(height: 140, child: Stack(fit: StackFit.expand, children: [
          Image.network(tech.imageUrl, fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(color: AppColors.surfaceContainerHigh, child: Icon(Icons.engineering_outlined, color: AppColors.onSurfaceVariant, size: 40))),
          Positioned(top: 8, right: 8, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: AppColors.background.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(6)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.star_rounded, size: 13, color: AppColors.neonAccent),
              const SizedBox(width: 3),
              Text(tech.rating.toStringAsFixed(1), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
            ]),
          )),
        ])),
        Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tech.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
          const SizedBox(height: 2),
          Text(tech.role, style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
        ])),
      ]),
    ));
  }
}

class _ListTech {
  final String name, role, rateLabel, tagline, imageUrl; final double rating, distanceKm;
  const _ListTech({required this.name, required this.role, required this.rateLabel, required this.rating, required this.distanceKm, required this.tagline, required this.imageUrl});
}

class _NearbyCard extends StatelessWidget {
  final _ListTech tech;
  const _NearbyCard({required this.tech});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(borderRadius: BorderRadius.circular(10),
          child: Image.network(tech.imageUrl, width: 72, height: 72, fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(width: 72, height: 72, color: AppColors.surfaceContainerHigh, child: Icon(Icons.person_outline, color: AppColors.onSurfaceVariant)))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tech.name, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(tech.role, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.neonAccent)),
            ])),
            Text.rich(TextSpan(children: [
              TextSpan(text: tech.rateLabel, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.neonAccent)),
              TextSpan(text: '/hr', style: GoogleFonts.inter(fontSize: 10, color: AppColors.onSurfaceVariant)),
            ])),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.star_rounded, size: 14, color: AppColors.neonAccent), const SizedBox(width: 3),
            Text(tech.rating.toStringAsFixed(1), style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
            const SizedBox(width: 14),
            Icon(Icons.near_me_outlined, size: 14, color: AppColors.onSurfaceVariant), const SizedBox(width: 3),
            Text('${tech.distanceKm} km', style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
          ]),
        ])),
      ]),
    );
  }
}
