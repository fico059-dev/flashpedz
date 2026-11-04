import 'dart:math';

/// A study level, earned with XP (see `StudyLog.xp`).
class LevelInfo {
  final int level;
  final int xp;

  /// Total XP at which [level] started and the next one starts.
  final int levelStartXp;
  final int nextLevelXp;

  const LevelInfo({
    required this.level,
    required this.xp,
    required this.levelStartXp,
    required this.nextLevelXp,
  });

  factory LevelInfo.fromXp(int xp) {
    final safeXp = max(0, xp);
    var level = 1;
    while (xpForLevel(level + 1) <= safeXp) {
      level++;
    }
    return LevelInfo(
      level: level,
      xp: safeXp,
      levelStartXp: xpForLevel(level),
      nextLevelXp: xpForLevel(level + 1),
    );
  }

  int get xpIntoLevel => xp - levelStartXp;
  int get xpToNextLevel => nextLevelXp - xp;
  double get progress =>
      (xpIntoLevel / (nextLevelXp - levelStartXp)).clamp(0.0, 1.0);

  /// The bird badge of this level.
  BirdBadge get badge => birdBadgeFor(level);

  /// The badge's name, e.g. "Robin" or "Phoenix ★2".
  String get title => badge.displayName(level);

  /// The badge earned at the next level.
  String get nextTitle => birdBadgeFor(level + 1).displayName(level + 1);
}

/// Total XP needed to reach [level]: 0, 100, 300, 600, 1000, … Each level
/// takes 100 XP more than the one before (about 10 more new cards).
int xpForLevel(int level) => level <= 1 ? 0 : 50 * level * (level - 1);

/// How rare a bird badge is.
enum BirdRarity { common, uncommon, rare, epic, legendary }

extension BirdRarityX on BirdRarity {
  String get label => switch (this) {
    BirdRarity.common => 'Common',
    BirdRarity.uncommon => 'Uncommon',
    BirdRarity.rare => 'Rare',
    BirdRarity.epic => 'Epic',
    BirdRarity.legendary => 'Legendary',
  };
}

/// A badge: each level earns a rarer bird, from a pigeon to a phoenix.
class BirdBadge {
  final String name;
  final BirdRarity rarity;

  const BirdBadge(this.name, this.rarity);

  /// Past the last bird, more phoenix stars: "Phoenix ★2".
  String displayName(int level) {
    final extra = level - birdBadges.length;
    return extra > 0 ? '$name ★${extra + 1}' : name;
  }
}

/// The badges in the order they are earned, one per level.
const birdBadges = [
  BirdBadge('Pigeon', BirdRarity.common),
  BirdBadge('Sparrow', BirdRarity.common),
  BirdBadge('Robin', BirdRarity.common),
  BirdBadge('Swallow', BirdRarity.uncommon),
  BirdBadge('Kingfisher', BirdRarity.uncommon),
  BirdBadge('Woodpecker', BirdRarity.uncommon),
  BirdBadge('Parrot', BirdRarity.rare),
  BirdBadge('Owl', BirdRarity.rare),
  BirdBadge('Toucan', BirdRarity.rare),
  BirdBadge('Flamingo', BirdRarity.rare),
  BirdBadge('Hummingbird', BirdRarity.epic),
  BirdBadge('Peacock', BirdRarity.epic),
  BirdBadge('Falcon', BirdRarity.epic),
  BirdBadge('Golden Eagle', BirdRarity.epic),
  BirdBadge('Bird of Paradise', BirdRarity.legendary),
  BirdBadge('Quetzal', BirdRarity.legendary),
  BirdBadge('Phoenix', BirdRarity.legendary),
];

BirdBadge birdBadgeFor(int level) =>
    birdBadges[(level - 1).clamp(0, birdBadges.length - 1)];
