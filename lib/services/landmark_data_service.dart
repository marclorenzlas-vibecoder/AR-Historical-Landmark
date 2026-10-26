import '../models/landmark.dart';

class LandmarkDataService {
  static final List<Landmark> allLandmarks = [
    const Landmark(
      id: 'cathedral',
      labelKey: 'cathedral',
      name: 'San Sebastian Cathedral',
      nativeName: 'Katedral ng San Sebastian',
      location: 'Rizal Street, Bacolod City',
      country: 'Philippines',
      era: 'Late 19th Century (Spanish Colonial)',
      yearBuilt: '1876 – 1882',
      architecturalStyle: 'Coral Stone Renaissance Revival',
      architect: 'Fr. Mauricio Ferrero, OAR',
      description:
          'The historic cathedral of the Roman Catholic Diocese of Bacolod, constructed with coral stone blocks quarried from Guimaras island. Featuring twin bell towers and an imposing classical façade, it has served as the spiritual and civic heart of Negros Occidental for over a century.',
      funFacts: [
        'Built using coral stone blocks and centuries-old lumber shipped across the Guimaras Strait.',
        'Houses two large antique bells cast in the late 19th century that still chime today.',
        'Served as a historical sanctuary and gathering point during the historic Negros Revolution of 1898.',
      ],
      timeline: [
        TimelineEvent(
          year: '1876',
          title: 'Foundation Laid',
          description: 'Fr. Mauricio Ferrero initiated construction using coral stone masonry.',
        ),
        TimelineEvent(
          year: '1882',
          title: 'Consecration',
          description: 'Inaugurated as the principal church of Bacolod.',
        ),
        TimelineEvent(
          year: '1933',
          title: 'Cathedral Designation',
          description: 'Elevated to cathedral status upon the formal establishment of the Diocese of Bacolod.',
        ),
      ],
      audioGuideScript:
          'Welcome to San Sebastian Cathedral. Built in the late 19th century using coral stone quarried from Guimaras, this majestic coral church stands as a testament to deep faith, artistry, and historic resilience.',
      imageAsset: 'assets/landmarks/cathedral.jpg',
      estimatedDistanceMeters: 45.0,
    ),
    const Landmark(
      id: 'lccb',
      labelKey: 'lccb',
      name: 'La Consolacion College Bacolod',
      nativeName: 'LCC Bacolod Heritage Campus',
      location: 'Gatuslao Street, Bacolod City',
      country: 'Philippines',
      era: 'Early 20th Century (1919)',
      yearBuilt: '1919',
      architecturalStyle: 'Augustinian Academic Heritage',
      architect: 'Augustinian Sisters of Our Lady of Consolation',
      description:
          'The pioneer Catholic institution of higher learning in Bacolod City, established in 1919 by three Augustinian sisters. Celebrated for its distinguished contributions to architecture, fine arts, and education throughout Western Visayas.',
      funFacts: [
        'Founded by three Augustinian sisters responding to urgent petitions for higher education in Negros.',
        'Its heritage campus buildings survived World War II and continue in active educational use.',
        'Pioneered the very first professional school of architecture in Negros Occidental.',
      ],
      timeline: [
        TimelineEvent(
          year: '1919',
          title: 'Institution Founded',
          description: 'Founded as an exclusive academy by the Augustinian Sisters.',
        ),
        TimelineEvent(
          year: '1945',
          title: 'Post-War Expansion',
          description: 'Classes promptly resumed and expanded into architecture and fine arts.',
        ),
        TimelineEvent(
          year: '2019',
          title: 'Centennial Celebration',
          description: 'Celebrated 100 years of cultural and academic excellence.',
        ),
      ],
      audioGuideScript:
          'You are standing near La Consolacion College Bacolod, a century-old institution of higher learning founded in 1919. Generations of artists and architects have been nurtured within its historic grounds.',
      imageAsset: 'assets/landmarks/lccb.jpg',
      estimatedDistanceMeters: 55.0,
    ),
    const Landmark(
      id: 'plaza',
      labelKey: 'plaza',
      name: 'Bacolod Public Plaza & Bandstand',
      nativeName: 'Plaza del Seis de Noviembre',
      location: 'Downtown Bacolod City',
      country: 'Philippines',
      era: 'Early 20th Century (1927)',
      yearBuilt: '1927',
      architecturalStyle: 'Neoclassical Civic Plaza & Gazebo',
      architect: 'City of Bacolod Public Works',
      description:
          'A historic town plaza located at the heart of downtown Bacolod across from the cathedral. Its famous neoclassical bandstand gazebo is inscribed with the names of world-renowned classical composers and serves as the vibrant center for civic festivals.',
      funFacts: [
        'The bandstand roof perimeter honors great classical composers: Beethoven, Mozart, Wagner, and Haydn.',
        'Epicenter of the world-famous MassKara Festival street dancing competitions held every October.',
        'Shaded by century-old acacia trees planted during the early 20th century.',
      ],
      timeline: [
        TimelineEvent(
          year: '1927',
          title: 'Gazebo Bandstand Built',
          description: 'The iconic neoclassical musical gazebo was constructed for civic orchestra performances.',
        ),
        TimelineEvent(
          year: '1938',
          title: 'City Charter Assembly',
          description: 'Hosted monumental civic celebrations when Bacolod officially became a chartered city.',
        ),
        TimelineEvent(
          year: '1980',
          title: 'Inaugural MassKara Festival',
          description: 'Became the permanent host arena for the vibrant MassKara street dance competitions.',
        ),
      ],
      audioGuideScript:
          'Welcome to the Bacolod Public Plaza. Created in 1927, this leafy public square features an ornate musical gazebo inscribed with classical composers, standing as the cultural pulse of the City of Smiles.',
      imageAsset: 'assets/landmarks/plaza.jpg',
      estimatedDistanceMeters: 30.0,
    ),
  ];

  /// Resolves a landmark strictly by trained model label key.
  /// Returns null if no landmark matches (never returns fake fallback!).
  static Landmark? findByLabel(String? label) {
    if (label == null || label.trim().isEmpty) return null;
    final clean = label.trim().toLowerCase();
    if (clean == 'searching' || clean == 'none' || clean == 'unknown') return null;

    for (final l in allLandmarks) {
      if (l.labelKey.toLowerCase() == clean ||
          l.id.toLowerCase() == clean ||
          l.name.toLowerCase() == clean) {
        return l;
      }
    }
    return null;
  }

  static Landmark? getById(String? id) {
    if (id == null || id.trim().isEmpty) return null;
    final clean = id.trim().toLowerCase();
    for (final l in allLandmarks) {
      if (l.id.toLowerCase() == clean || l.labelKey.toLowerCase() == clean) {
        return l;
      }
    }
    return allLandmarks.isNotEmpty ? allLandmarks.first : null;
  }
}
