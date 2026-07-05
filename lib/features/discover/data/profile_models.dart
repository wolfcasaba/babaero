import 'dart:ui';

/// Predefined prompt questions members answer on their profile.
const List<String> kPromptQuestions = [
  'My ideal first date is…',
  'A perfect weekend for me…',
  'The way to my heart is…',
  'My simple pleasures…',
  'I\'m looking for someone who…',
  'Ask me about…',
  'My favorite Filipino dish is…',
  'A fact that surprises people…',
  'My love language is…',
  'We\'ll get along if…',
];

/// One profile prompt (a chosen question + the member's answer).
class ProfilePrompt {
  final String question;
  final String answer;
  const ProfilePrompt({required this.question, required this.answer});

  factory ProfilePrompt.fromMap(Map<String, dynamic> m) => ProfilePrompt(
        question: (m['q'] ?? '').toString(),
        answer: (m['a'] ?? '').toString(),
      );

  Map<String, dynamic> toMap() => {'q': question, 'a': answer};
}

/// A discover-able member profile. Parsed at the boundary; plain Dart.
class Profile {
  final String id;
  final String name;
  final int age;
  final String city; // e.g. "Cebu, PH"
  final String country; // e.g. "Philippines"
  final String bio;
  final List<String> interests;
  final bool verified;
  final bool online;
  final int distanceKm;
  final String languages; // e.g. "English, Tagalog, Cebuano"

  /// 'male' | 'female' | 'other' — used by the profile editor. Nullable
  /// because the discover/browse reads don't need it.
  final String? gender;

  /// 'foreigner' | 'local'. Same note as [gender].
  final String? role;

  /// Hinge-style prompt cards (question + answer).
  final List<ProfilePrompt> prompts;

  /// Babaero Gold member. Free launch → false for everyone; the premium gates
  /// read this so membership can be switched on later without code changes.
  final bool isGold;

  /// All photo URLs (public storage URLs). First = primary avatar.
  final List<String> photos;

  /// Two colors used to render a gradient placeholder avatar (shown when a
  /// member has no photo). Deterministic per profile.
  final Color colorA;
  final Color colorB;

  const Profile({
    required this.id,
    required this.name,
    required this.age,
    required this.city,
    required this.country,
    required this.bio,
    required this.interests,
    required this.verified,
    required this.online,
    required this.distanceKm,
    required this.languages,
    required this.colorA,
    required this.colorB,
    this.photos = const [],
    this.gender,
    this.role,
    this.prompts = const [],
    this.isGold = false,
  });

  /// Primary photo URL, or null when the member has none.
  String? get photoUrl => photos.isNotEmpty ? photos.first : null;
  bool get hasPhoto => photoUrl != null && photoUrl!.isNotEmpty;

  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';

  /// Parse a `babaero.profiles` row. Colors are derived deterministically
  /// from the id (the DB has no color columns) so avatars are stable.
  factory Profile.fromMap(Map<String, dynamic> m) {
    final id = (m['id'] ?? '').toString();
    final palette = _paletteFor(id);
    final interests = (m['interests'] as List?)?.cast<String>() ?? const [];
    final photos = (m['photos'] as List?)?.cast<String>() ?? const [];
    final prompts = [
      for (final p in (m['prompts'] as List?) ?? const [])
        if (p is Map<String, dynamic>) ProfilePrompt.fromMap(p),
    ];
    return Profile(
      photos: photos,
      prompts: prompts,
      id: id,
      name: (m['name'] ?? '').toString(),
      age: (m['age'] as num?)?.toInt() ?? 0,
      city: (m['city'] ?? '').toString(),
      country: (m['country'] ?? '').toString(),
      bio: (m['bio'] ?? '').toString(),
      interests: interests,
      verified: m['verified'] == true,
      online: m['is_online'] == true,
      distanceKm: (m['distance_km'] as num?)?.toInt() ?? 0,
      languages: (m['languages'] ?? '').toString(),
      gender: m['gender'] as String?,
      role: m['role'] as String?,
      isGold: m['is_gold'] == true,
      colorA: palette.$1,
      colorB: palette.$2,
    );
  }
}

/// Stable two-color gradient from an id hash — matches the brand palette.
(Color, Color) _paletteFor(String seed) {
  const pairs = [
    (Color(0xFFE01E5A), Color(0xFFFF7A59)),
    (Color(0xFF7A1338), Color(0xFFF5B54A)),
    (Color(0xFF2A0A1E), Color(0xFFE01E5A)),
    (Color(0xFFFF7A59), Color(0xFFF5B54A)),
  ];
  var h = 0;
  for (final c in seed.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return pairs[h % pairs.length];
}

/// In-memory seed used for mock mode / previews / golden screenshots.
/// Replaced by the Supabase repository once signed in.
const List<Profile> sampleProfiles = [
  Profile(
    id: 'p1',
    name: 'Maria',
    age: 26,
    city: 'Cebu City',
    country: 'Philippines',
    bio:
        'Coffee, karaoke and long walks by the sea. Looking for someone kind '
        'and honest. 🌸',
    interests: ['Karaoke', 'Beach', 'Cooking', 'Travel'],
    verified: true,
    online: true,
    distanceKm: 3,
    languages: 'English, Tagalog, Cebuano',
    colorA: Color(0xFFE01E5A),
    colorB: Color(0xFFFF7A59),
  ),
  Profile(
    id: 'p2',
    name: 'Angel',
    age: 24,
    city: 'Davao City',
    country: 'Philippines',
    bio: 'Nurse by day, foodie by night. Teach me your language and I\'ll '
        'teach you mine. 😊',
    interests: ['Foodie', 'Movies', 'Fitness'],
    verified: true,
    online: false,
    distanceKm: 8,
    languages: 'English, Tagalog',
    colorA: Color(0xFF7A1338),
    colorB: Color(0xFFF5B54A),
  ),
  Profile(
    id: 'p3',
    name: 'Jasmine',
    age: 29,
    city: 'Manila',
    country: 'Philippines',
    bio: 'Small business owner. Family-oriented, faith is important to me. '
        'Serious connections only.',
    interests: ['Business', 'Faith', 'Family', 'Dogs'],
    verified: false,
    online: true,
    distanceKm: 14,
    languages: 'English, Tagalog',
    colorA: Color(0xFF2A0A1E),
    colorB: Color(0xFFE01E5A),
  ),
  Profile(
    id: 'p4',
    name: 'Camille',
    age: 27,
    city: 'Iloilo City',
    country: 'Philippines',
    bio: 'Teacher who loves the mountains and the sea equally. Looking for my '
        'travel partner. ✈️',
    interests: ['Hiking', 'Books', 'Photography', 'Travel'],
    verified: true,
    online: true,
    distanceKm: 21,
    languages: 'English, Tagalog, Hiligaynon',
    colorA: Color(0xFFFF7A59),
    colorB: Color(0xFFF5B54A),
  ),
];
