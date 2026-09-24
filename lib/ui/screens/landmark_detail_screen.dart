import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/landmark.dart';

class LandmarkDetailScreen extends StatefulWidget {
  final Landmark landmark;

  const LandmarkDetailScreen({super.key, required this.landmark});

  @override
  State<LandmarkDetailScreen> createState() => _LandmarkDetailScreenState();
}

class _LandmarkDetailScreenState extends State<LandmarkDetailScreen> {
  bool _isPlayingAudio = false;

  @override
  Widget build(BuildContext context) {
    final l = widget.landmark;

    const goldPrimary = Color(0xFFD4AF37);
    const goldLight = Color(0xFFE5C158);
    const deepEspresso = Color(0xFF12100E);
    const surfaceBrown = Color(0xFF1C1814);
    const textParchment = Color(0xFFF7EBE1);

    return Scaffold(
      backgroundColor: deepEspresso,
      body: CustomScrollView(
        slivers: [
          // 1. Hero Image App Bar
          SliverAppBar(
            expandedHeight: 330,
            pinned: true,
            backgroundColor: surfaceBrown,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                  border: Border.all(color: goldPrimary.withValues(alpha: 0.5)),
                ),
                child: const Icon(Icons.arrow_back, color: Color(0xFFFFF0B8), size: 18),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                    border: Border.all(color: goldPrimary.withValues(alpha: 0.5)),
                  ),
                  child: const Icon(Icons.bookmark_border, color: goldLight, size: 18),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${l.name} saved to field notebook!',
                        style: GoogleFonts.outfit(color: textParchment),
                      ),
                      backgroundColor: const Color(0xFF28221B),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    l.imageAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: surfaceBrown,
                      child: const Center(
                        child: Icon(Icons.account_balance, size: 80, color: goldPrimary),
                      ),
                    ),
                  ),
                  // Warm gradient vignette
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.35),
                          deepEspresso,
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: goldPrimary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: goldPrimary, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified, color: goldLight, size: 13),
                              const SizedBox(width: 6),
                              Text(
                                l.unescoStatus.toUpperCase(),
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFFFF0B8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l.name,
                          style: GoogleFonts.playfairDisplay(
                            color: textParchment,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                        Text(
                          l.nativeName,
                          style: GoogleFonts.outfit(
                            color: goldLight,
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Body Details
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location badge
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFFD47A55), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '${l.location}, ${l.country}',
                        style: GoogleFonts.outfit(color: const Color(0xFFC7B9AC), fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Quick Stats Grid
                  _buildQuickSpecsGrid(l, surfaceBrown, goldPrimary, textParchment),
                  const SizedBox(height: 24),

                  // Audio Guide Interactive Player
                  _buildAudioGuidePlayer(l, surfaceBrown, goldPrimary, goldLight, textParchment),
                  const SizedBox(height: 26),

                  // Historical Overview Section
                  Text(
                    'HISTORICAL OVERVIEW',
                    style: GoogleFonts.outfit(
                      color: goldLight,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l.description,
                    style: GoogleFonts.outfit(
                      color: textParchment,
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Interactive Timeline
                  Text(
                    'CHRONOLOGICAL TIMELINE',
                    style: GoogleFonts.outfit(
                      color: goldLight,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ...l.timeline.map((event) => _buildTimelineCard(event, goldPrimary, textParchment)),
                  const SizedBox(height: 24),

                  // Fun Facts / Secrets
                  Text(
                    'ARCHITECTURAL SECRETS & TRIVIA',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFE5C158),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...l.funFacts.map((fact) => _buildFactCard(fact, surfaceBrown, goldPrimary, textParchment)),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSpecsGrid(
    Landmark l,
    Color surfaceBrown,
    Color goldPrimary,
    Color textParchment,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceBrown,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: goldPrimary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSpecItem('ERA', l.era, Icons.history_edu, goldPrimary, textParchment),
              ),
              Expanded(
                child: _buildSpecItem('BUILT', l.yearBuilt, Icons.calendar_today, goldPrimary, textParchment),
              ),
            ],
          ),
          Divider(color: goldPrimary.withValues(alpha: 0.2), height: 24),
          Row(
            children: [
              Expanded(
                child: _buildSpecItem('ARCHITECT', l.architect, Icons.architecture, goldPrimary, textParchment),
              ),
              Expanded(
                child: _buildSpecItem('STYLE', l.architecturalStyle, Icons.palette_outlined, goldPrimary, textParchment),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpecItem(
    String title,
    String value,
    IconData icon,
    Color goldPrimary,
    Color textParchment,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: goldPrimary, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  color: const Color(0xFFA5978B),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.outfit(
                  color: textParchment,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAudioGuidePlayer(
    Landmark l,
    Color surfaceBrown,
    Color goldPrimary,
    Color goldLight,
    Color textParchment,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF231C16),
            Color(0xFF1B1612),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: goldPrimary.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.headphones, color: goldLight, size: 18),
              const SizedBox(width: 8),
              Text(
                'MUSEUM AUDIO TOUR GUIDE',
                style: GoogleFonts.outfit(
                  color: goldLight,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Text(
                _isPlayingAudio ? 'PLAYING 01:24' : 'DURATION 02:45',
                style: GoogleFonts.outfit(color: const Color(0xFFA5978B), fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '"${l.audioGuideScript}"',
            style: GoogleFonts.playfairDisplay(
              color: textParchment,
              fontSize: 14,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isPlayingAudio = !_isPlayingAudio;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: goldLight,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: goldLight.withValues(alpha: 0.35),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isPlayingAudio ? Icons.pause : Icons.play_arrow,
                        color: Colors.black,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isPlayingAudio ? 'PAUSE GUIDE' : 'LISTEN TO GUIDE',
                        style: GoogleFonts.outfit(
                          color: Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Animated golden sound wave equalizer
              if (_isPlayingAudio)
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      14,
                      (index) => Container(
                        width: 3,
                        height: 8 + (index % 5) * 4.0,
                        decoration: BoxDecoration(
                          color: goldLight,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scaleY(
                            begin: 0.3,
                            end: 1.8,
                            delay: (index * 60).ms,
                            duration: 350.ms,
                          ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(TimelineEvent event, Color goldPrimary, Color textParchment) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: goldPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: goldPrimary.withValues(alpha: 0.6)),
            ),
            child: Text(
              event.year,
              style: GoogleFonts.outfit(
                color: const Color(0xFFFFF0B8),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: GoogleFonts.playfairDisplay(
                    color: textParchment,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  event.description,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFC7B9AC),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactCard(
    String fact,
    Color surfaceBrown,
    Color goldPrimary,
    Color textParchment,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceBrown,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: goldPrimary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_stories, color: goldPrimary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              fact,
              style: GoogleFonts.outfit(
                color: textParchment,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
