import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashcards/utils/typedefs.dart';

class UserClaims {
  final List<String> roles;
  final List<String> entitlements;
  final int cardsExpMs; // packsExp || cardsExp
  final int osceExpMs; // osceExp
  final int allExpMs; // bothExp || allExp

  const UserClaims({
    required this.roles,
    required this.entitlements,
    required this.cardsExpMs,
    required this.osceExpMs,
    required this.allExpMs,
  });

  bool get isAdmin => roles.contains('admin');

  int get _nowMs => DateTime.now().millisecondsSinceEpoch;

  bool get hasCards {
    if (entitlements.contains('both') || entitlements.contains('packs')) {
      return true;
    }
    return (allExpMs > _nowMs) || (cardsExpMs > _nowMs);
  }

  bool get hasOsce {
    if (entitlements.contains('both') || entitlements.contains('osce')) {
      return true;
    }
    return (allExpMs > _nowMs) || (osceExpMs > _nowMs);
  }

  static int _toMs(dynamic v) {
    if (v is num) {
      final n = v.toDouble();
      if (n <= 0) return 0;
      return n < 1e12 ? (n * 1000).round() : n.round();
    }
    return 0;
  }

  static List<String> _asStrList(dynamic v) {
    if (v is List) {
      return v
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const <String>[];
  }

  factory UserClaims.fromMap(JsonMap? map) {
    final roles = _asStrList(map?['roles']);
    final ents = _asStrList(map?['entitlements']);

    final packsOrCardsMs = [
      _toMs(map?['packsExp']),
      _toMs(map?['cardsExp']),
    ].reduce((a, b) => a > b ? a : b);

    final bothOrAllMs = [
      _toMs(map?['bothExp']),
      _toMs(map?['allExp']),
    ].reduce((a, b) => a > b ? a : b);

    final osceMs = _toMs(map?['osceExp']);

    final claims = UserClaims(
      roles: roles,
      entitlements: ents,
      cardsExpMs: packsOrCardsMs,
      osceExpMs: osceMs,
      allExpMs: bothOrAllMs,
    );

    final now = DateTime.now().millisecondsSinceEpoch;

    print(
      '[Claims] ents=$ents packs/cards=$packsOrCardsMs both/all=$bothOrAllMs osce=$osceMs',
    );
    print(
      "Packs valid: ${(claims.allExpMs > now) || (claims.cardsExpMs > now)}",
    );
    print("Osce valid: ${(claims.allExpMs > now) || (claims.osceExpMs > now)}");
    print("Has cards: ${claims.hasCards}, hasOsce: ${claims.hasOsce}");

    return claims;
  }

  /// When the sign-in token was last renewed on purpose, and for whom.
  static DateTime? _renewedAt;
  static String? _renewedFor;

  /// How often the token is renewed to pick up subscription changes. In
  /// between, the token the app already has is used (no network), so
  /// opening packs and sessions doesn't wait. Purchases renew it at once.
  static const renewEvery = Duration(minutes: 10);

  static Future<UserClaims> current() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const UserClaims(
        roles: [],
        entitlements: [],
        cardsExpMs: 0,
        osceExpMs: 0,
        allExpMs: 0,
      );
    }
    final now = DateTime.now();
    final renewedAt = _renewedAt;
    final renew =
        _renewedFor != user.uid ||
        renewedAt == null ||
        now.difference(renewedAt) > renewEvery;
    if (renew) {
      _renewedAt = now;
      _renewedFor = user.uid;
    }
    IdTokenResult token;
    try {
      token = await user.getIdTokenResult(renew);
    } catch (_) {
      if (!renew) rethrow;
      // Offline: the token the app has.
      _renewedAt = null;
      token = await user.getIdTokenResult();
    }
    final map =
        token.claims?.map((k, v) => MapEntry(k, v)) ?? <String, dynamic>{};
    return UserClaims.fromMap(map);
  }
}
