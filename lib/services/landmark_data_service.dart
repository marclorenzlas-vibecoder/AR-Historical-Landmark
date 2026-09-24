import '../models/landmark.dart';

class LandmarkDataService {
  static final List<Landmark> allLandmarks = [
    const Landmark(
      id: 'eiffel_tower',
      labelKey: 'eiffel_tower',
      name: 'Eiffel Tower',
      nativeName: 'Tour Eiffel',
      location: 'Champ de Mars, Paris',
      country: 'France',
      era: 'Late 19th Century (Belle Époque)',
      yearBuilt: '1887 – 1889',
      architecturalStyle: 'Structural Puddle Iron Lattice',
      architect: 'Gustave Eiffel & Stephen Sauvestre',
      description:
          'Constructed as the centerpiece of the 1889 World\'s Fair (Exposition Universelle) celebrating the centenary of the French Revolution. Standing 330 meters tall, it remained the tallest man-made structure in the world for 41 years until 1930.',
      funFacts: [
        'It shrinks by up to 15 centimeters during winter due to thermal contraction of the puddle iron.',
        'Originally intended to be dismantled after 20 years, it was saved due to its value as a radio transmission tower.',
        'Over 18,000 metallic parts and 2.5 million rivets hold the structure together.',
        'Repainted by hand every 7 years with 60 tonnes of paint to prevent rust.',
      ],
      timeline: [
        TimelineEvent(
          year: '1884',
          title: 'Initial Blueprint',
          description: 'Engineers Maurice Koechlin and Émile Nouguier conceived the initial tower draft.',
        ),
        TimelineEvent(
          year: '1887',
          title: 'Groundbreaking',
          description: 'Foundations laid on the Champ de Mars in central Paris.',
        ),
        TimelineEvent(
          year: '1889',
          title: 'Grand Inauguration',
          description: 'Officially inaugurated on March 31, 1889 for the Exposition Universelle.',
        ),
        TimelineEvent(
          year: '1944',
          title: 'Liberation of Paris',
          description: 'Hitler ordered Dietrich von Choltitz to demolish the tower, but the order was defied.',
        ),
        TimelineEvent(
          year: '1991',
          title: 'UNESCO Recognition',
          description: 'Inscribed as a UNESCO World Heritage site alongside the banks of the Seine.',
        ),
      ],
      audioGuideScript:
          'Welcome to the Eiffel Tower. Rising above the Champ de Mars, this wrought-iron wonder is the quintessential symbol of Paris. Completed in just two years, two months, and five days, Gustave Eiffel\'s bold engineering triumphed over initial skepticism from prominent French artists, transforming into the most-visited paid monument in the world.',
      imageAsset: 'assets/landmarks/eiffel_tower.jpg',
      estimatedDistanceMeters: 85.0,
    ),
    const Landmark(
      id: 'colosseum',
      labelKey: 'colosseum',
      name: 'Colosseum',
      nativeName: 'Amphitheatrum Flavium',
      location: 'Piazza del Colosseo, Rome',
      country: 'Italy',
      era: 'Imperial Roman (Flavian Dynasty)',
      yearBuilt: '70 – 80 AD',
      architecturalStyle: 'Roman Classical / Travertine & Concrete',
      architect: 'Commissioned by Emperor Vespasian, finished by Titus',
      description:
          'The largest ancient amphitheatre ever built, capable of holding an estimated 50,000 to 80,000 spectators. It hosted gladiatorial contests, battle reenactments, classical dramas, and public spectacles, embodying Roman architectural mastery.',
      funFacts: [
        'Could be flooded with water using underground aqueducts to hold mock naval battles (naumachiae).',
        'Featured an enormous retractable fabric awning called the Velarium to shade spectators from Roman heat.',
        'The hypogeum beneath the arena floor contained a two-level subterranean network of tunnels and 80 animal lifts.',
        'Over two-thirds of the original structure was scavenged in the Middle Ages to build Roman palaces and St. Peter\'s Basilica.',
      ],
      timeline: [
        TimelineEvent(
          year: '70 AD',
          title: 'Construction Begins',
          description: 'Emperor Vespasian initiated construction using spoils from the Jewish-Roman war.',
        ),
        TimelineEvent(
          year: '80 AD',
          title: 'Inaugural Games',
          description: 'Emperor Titus inaugurated the Colosseum with 100 consecutive days of celebratory games.',
        ),
        TimelineEvent(
          year: '217 AD',
          title: 'Major Fire & Repair',
          description: 'Lightning strike gutted upper wooden levels, repaired under Emperor Alexander Severus.',
        ),
        TimelineEvent(
          year: '1349',
          title: 'The Great Earthquake',
          description: 'Severe earthquake caused the massive collapse of the outer south side.',
        ),
        TimelineEvent(
          year: '2007',
          title: 'New Seven Wonders',
          description: 'Named one of the New Seven Wonders of the World by international consensus.',
        ),
      ],
      audioGuideScript:
          'You are standing before the Flavian Amphitheatre, universally known as the Colosseum. Built in the heart of ancient Rome, this monumental elliptical arena stands as testament to the scale, engineering genius, and fierce spectacles of the Roman Empire.',
      imageAsset: 'assets/landmarks/colosseum.jpg',
      estimatedDistanceMeters: 62.0,
    ),
    const Landmark(
      id: 'taj_mahal',
      labelKey: 'taj_mahal',
      name: 'Taj Mahal',
      nativeName: 'تاج محل (Crown of the Palaces)',
      location: 'Dharmapuri, Agra, Uttar Pradesh',
      country: 'India',
      era: 'Mughal Empire (Golden Age)',
      yearBuilt: '1632 – 1653',
      architecturalStyle: 'Indo-Islamic / Pietra Dura Marble Inlay',
      architect: 'Ustad Ahmad Lahori (Chief Architect)',
      description:
          'An immense ivory-white marble mausoleum on the southern bank of the Yamuna river, commissioned by Mughal Emperor Shah Jahan to house the tomb of his favorite wife, Mumtaz Mahal. Celebrated as the jewel of Muslim art in India.',
      funFacts: [
        'The four perimeter minarets are deliberately angled slightly outward so that in the event of an earthquake, they fall away from the central tomb.',
        'The translucent white Makrana marble subtly shifts colors depending on the time of day: blush pink at dawn, milky white at midday, and burnished gold under moonlight.',
        'Employed over 20,000 artisans and 1,000 elephants to transport building materials across India and Asia.',
        'The calligraphy across the entry gates gradually increases in font size as it goes higher up, appearing perfectly uniform to observers on the ground.',
      ],
      timeline: [
        TimelineEvent(
          year: '1631',
          title: 'Passing of Mumtaz Mahal',
          description: 'Empress Mumtaz Mahal passed away, inspiring Shah Jahan to construct this eternal monument.',
        ),
        TimelineEvent(
          year: '1632',
          title: 'Groundbreaking',
          description: 'Excavation of deep well foundations along the Yamuna river bank.',
        ),
        TimelineEvent(
          year: '1648',
          title: 'Mausoleum Completion',
          description: 'Central dome and tomb complex finalized; outbuildings continued until 1653.',
        ),
        TimelineEvent(
          year: '1983',
          title: 'UNESCO Inscription',
          description: 'Inscribed as a World Heritage Site, noted as a masterpiece of symmetry and harmony.',
        ),
      ],
      audioGuideScript:
          'Welcome to the Taj Mahal, widely regarded as the ultimate architectural tribute to love. Gazing across the charbagh reflecting gardens, note the flawless bilateral symmetry, marble latticework, and semi-precious stone inlays known as pietra dura.',
      imageAsset: 'assets/landmarks/taj_mahal.jpg',
      estimatedDistanceMeters: 110.0,
    ),
    const Landmark(
      id: 'pyramids_giza',
      labelKey: 'pyramids_giza',
      name: 'Great Pyramid of Giza',
      nativeName: 'Akhet Khufu (Khufu\'s Horizon)',
      location: 'Giza Plateau, Greater Cairo',
      country: 'Egypt',
      era: 'Old Kingdom (Fourth Dynasty)',
      yearBuilt: 'c. 2580 – 2560 BC',
      architecturalStyle: 'Ancient Egyptian Ashlar Masonry',
      architect: 'Hemiunu (Royal Vizier & Overseer of Works)',
      description:
          'The oldest and only remaining intact monument among the Seven Wonders of the Ancient World. Built as a tomb for the Fourth Dynasty Pharaoh Khufu over an estimated 27-year period.',
      funFacts: [
        'Constructed using approximately 2.3 million limestone and granite blocks weighing an average of 2.5 tonnes each.',
        'Originally covered in smooth, polished Tura white limestone casing stones that reflected sunlight like a mirror.',
        'Its corners are aligned almost perfectly to the four cardinal directions with less than 4 arcminutes of error.',
        'Remained the tallest human-made structure in the world for over 3,800 years until Lincoln Cathedral\'s spire was completed in 1311.',
      ],
      timeline: [
        TimelineEvent(
          year: 'c. 2580 BC',
          title: 'Pharaoh Khufu Ascends',
          description: 'Royal architect Hemiunu commissions quarrying and leveling of the Giza bedrock.',
        ),
        TimelineEvent(
          year: 'c. 2560 BC',
          title: 'Pyramid Dedicated',
          description: 'Casing stones laid and the gilded capstone (pyramidion) placed at apex.',
        ),
        TimelineEvent(
          year: '1303 AD',
          title: 'Crete Earthquake',
          description: 'Violent tremors loosened external casing stones, subsequently repurposed for mosques in Cairo.',
        ),
        TimelineEvent(
          year: '1979',
          title: 'UNESCO World Heritage',
          description: 'Memphis and its Necropolis inscribed into world cultural heritage.',
        ),
      ],
      audioGuideScript:
          'You are gazing upon the Great Pyramid of Giza, the sole survivor of the Seven Wonders of the Ancient World. For more than 4,500 years, this colossal monument of stone has anchored the edge of the Sahara, embodying the celestial aspirations and mathematical prowess of ancient Egypt.',
      imageAsset: 'assets/landmarks/pyramids_giza.jpg',
      estimatedDistanceMeters: 140.0,
    ),
    const Landmark(
      id: 'intramuros_san_agustin',
      labelKey: 'intramuros_san_agustin',
      name: 'San Agustin Church & Intramuros',
      nativeName: 'Simbahan ng San Agustin',
      location: 'General Luna St, Intramuros, Manila',
      country: 'Philippines',
      era: 'Spanish Colonial Period (16th Century)',
      yearBuilt: '1586 – 1607',
      architecturalStyle: 'Earthquake Baroque',
      architect: 'Juan Macías',
      description:
          'The oldest stone church in the Philippines, located inside the historic walled city of Intramuros. Designed in Earthquake Baroque style with massive buttresses, it survived seven major earthquakes, the Battle of Manila in 1945, and centuries of typhoons.',
      funFacts: [
        'The interior vault ceiling features stunning trompe-l\'œil frescoes painted in 1875 by Italian artists Cesare Alberoni and Giovanni Dibella.',
        'The main doors are intricately hand-carved molave wood depicting Saint Augustine and Saint Monica.',
        'It served as a concentration camp during the final days of the Battle of Manila, yet emerged as the only one of the original seven Intramuros churches left standing.',
        'The foundation is built in the shape of a cross with interlocking volcanic stone blocks that flex during seismic tremors.',
      ],
      timeline: [
        TimelineEvent(
          year: '1571',
          title: 'Intramuros Founded',
          description: 'Miguel López de Legazpi established Manila as the Spanish colonial capital.',
        ),
        TimelineEvent(
          year: '1607',
          title: 'Stone Church Dedicated',
          description: 'The Augustinian order completed the permanent volcanic tuff stone structure.',
        ),
        TimelineEvent(
          year: '1945',
          title: 'Survival of Battle of Manila',
          description: 'Though surrounding Intramuros was leveled, San Agustin Church miraculously survived.',
        ),
        TimelineEvent(
          year: '1993',
          title: 'UNESCO Inscription',
          description: 'Declared a UNESCO World Heritage site as part of the Baroque Churches of the Philippines.',
        ),
      ],
      audioGuideScript:
          'Welcome to San Agustin Church within the historic ramparts of Intramuros. Standing for over four centuries, this Earthquake Baroque sanctuary has witnessed colonial history, catastrophic quakes, and the fires of World War II.',
      imageAsset: 'assets/landmarks/intramuros.jpg',
      estimatedDistanceMeters: 35.0,
    ),
  ];

  static Landmark? findByLabel(String label) {
    try {
      return allLandmarks.firstWhere(
        (l) => l.labelKey.toLowerCase() == label.toLowerCase(),
      );
    } catch (_) {
      // Fallback to Eiffel Tower for demo
      return allLandmarks.first;
    }
  }

  static Landmark getById(String id) {
    return allLandmarks.firstWhere(
      (l) => l.id == id,
      orElse: () => allLandmarks.first,
    );
  }
}
