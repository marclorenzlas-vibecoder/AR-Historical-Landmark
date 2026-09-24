import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/scanner_provider.dart';
import '../../services/landmark_data_service.dart';
import 'landmark_detail_screen.dart';

class GallerySimScreen extends StatelessWidget {
  const GallerySimScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final landmarks = LandmarkDataService.allLandmarks;
    final scanner = Provider.of<ScannerProvider>(context);

    const goldPrimary = Color(0xFFD4AF37);
    const goldLight = Color(0xFFE5C158);
    const deepEspresso = Color(0xFF12100E);
    const surfaceBrown = Color(0xFF1C1814);
    const textParchment = Color(0xFFF7EBE1);

    return Scaffold(
      backgroundColor: deepEspresso,
      appBar: AppBar(
        backgroundColor: surfaceBrown,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFFFF0B8)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'World Heritage Archive',
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textParchment,
              ),
            ),
            Text(
              'Monument Catalog & AR Testing',
              style: GoogleFonts.outfit(fontSize: 11, color: goldLight),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Project Architecture Overview Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF261F18), Color(0xFF1B1612)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: goldPrimary.withValues(alpha: 0.45)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: goldPrimary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'COLLABORATIVE AI PIPELINE',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFFFF0B8),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.account_balance, color: goldLight, size: 18),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Heritage Landmark Recognition',
                  style: GoogleFonts.playfairDisplay(
                    color: textParchment,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select any historical landmark below to simulate the AR camera lens, test YOLO localization, and inspect CNN architectural classifications.',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFC7B9AC),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'HISTORICAL SITES',
            style: GoogleFonts.outfit(
              color: goldLight,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          // Landmarks list
          ...landmarks.map((l) {
            final isSelected = scanner.activeSimulatedLandmarkKey == l.labelKey;

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: surfaceBrown,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? goldPrimary : goldPrimary.withValues(alpha: 0.2),
                  width: isSelected ? 1.5 : 1.0,
                ),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: goldPrimary.withValues(alpha: 0.2),
                      blurRadius: 10,
                    ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 68,
                    height: 68,
                    child: Image.asset(
                      l.imageAsset,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: const Color(0xFF28221B),
                        child: const Icon(Icons.account_balance, color: goldPrimary),
                      ),
                    ),
                  ),
                ),
                title: Text(
                  l.name,
                  style: GoogleFonts.playfairDisplay(
                    color: textParchment,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      '${l.country} • ${l.era}',
                      style: GoogleFonts.outfit(color: const Color(0xFFA5978B), fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: goldPrimary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'EST RANGE: ~${l.estimatedDistanceMeters.toStringAsFixed(0)}m',
                            style: GoogleFonts.outfit(
                              color: goldLight,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          Text(
                            'ACTIVE IN LENS',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF68D391),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected ? goldPrimary : const Color(0xFF2D251E),
                    foregroundColor: isSelected ? Colors.black : const Color(0xFFFFF0B8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: isSelected ? 2 : 0,
                  ),
                  onPressed: () {
                    scanner.setActiveLandmark(l.labelKey);
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    isSelected ? 'SELECTED' : 'TEST IN AR',
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LandmarkDetailScreen(landmark: l),
                    ),
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}
