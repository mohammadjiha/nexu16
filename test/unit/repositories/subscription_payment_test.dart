// test/unit/repositories/subscription_payment_test.dart
//
// Subscription & Payment system tests — covers all 4 roles:
//   • Coach      → renewSubscription, editSubscription
//   • Admin      → updatePlayerSubscription
//   • Super Admin→ collectionGroup payments query (cross-gym visibility)
//   • Player     → subscription expiry date logic

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexus/src/features/coach/data/coach_repository.dart';
import 'package:nexus/src/features/admin/data/admin_repository.dart';

// ─── Shared helpers ───────────────────────────────────────────────────────────

const String kGymId      = 'gym_001';
const String kPlayerUid  = 'player_uid_1';
const String kCoachUid   = 'coach_uid_1';
const String kAdminUid   = 'admin_uid_1';
const String kPlayerName = 'أحمد العلي';
const String kPlan       = 'اشتراك شهري';

/// Seed a minimal user doc so the repos that read existing amountPaid work.
Future<void> seedPlayer(
  FakeFirebaseFirestore db, {
  String uid = kPlayerUid,
  double amountPaid = 0,
  double totalAmount = 0,
  DateTime? subscriptionEnd,
}) async {
  await db.collection('users').doc(uid).set({
    'uid': uid,
    'gymId': kGymId,
    'firstName': 'أحمد',
    'lastName': 'العلي',
    'role': 'player',
    'amountPaid': amountPaid,
    'totalAmount': totalAmount,
    'amountRemaining': totalAmount - amountPaid,
    'isDeleted': false,
    if (subscriptionEnd != null)
      'subscriptionEnd': Timestamp.fromDate(subscriptionEnd),
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// COACH TESTS
// ═══════════════════════════════════════════════════════════════════════════════

void main() {
  // ── Coach ─────────────────────────────────────────────────────────────────

  group('Coach — renewSubscription', () {
    late FakeFirebaseFirestore db;
    late CoachRepository repo;
    late DateTime start;
    late DateTime end;

    setUp(() async {
      db   = FakeFirebaseFirestore();
      repo = CoachRepository(firestore: db, auth: MockFirebaseAuth());
      start = DateTime(2026, 7, 1);
      end   = DateTime(2026, 7, 31);
      await seedPlayer(db, amountPaid: 50, totalAmount: 100);
    });

    test('uses SET semantics — calling twice does NOT double amountPaid', () async {
      // First renewal
      await repo.renewSubscription(
        uid: kPlayerUid,
        startDate: start,
        endDate: end,
        totalAmount: 100,
        amountPaid: 80,
        amountRemaining: 20,
        planName: kPlan,
        paymentMethod: 'cash',
        gymId: kGymId,
        coachUid: kCoachUid,
        playerName: kPlayerName,
      );

      // Second renewal with same values (e.g. retry)
      await repo.renewSubscription(
        uid: kPlayerUid,
        startDate: start,
        endDate: end,
        totalAmount: 100,
        amountPaid: 80,
        amountRemaining: 20,
        planName: kPlan,
        paymentMethod: 'cash',
        gymId: kGymId,
        coachUid: kCoachUid,
        playerName: kPlayerName,
      );

      final doc  = await db.collection('users').doc(kPlayerUid).get();
      final data = doc.data()!;

      // SET: should stay at 80, not accumulate to 160 or 210
      expect(data['amountPaid'], equals(80.0),
          reason: 'amountPaid must be SET, not incremented each call');
      expect(data['totalAmount'], equals(100.0),
          reason: 'totalAmount must be SET');
      expect(data['amountRemaining'], equals(20.0),
          reason: 'amountRemaining must be SET');
    });

    test('payment record contains required identity + financial fields', () async {
      await repo.renewSubscription(
        uid: kPlayerUid,
        startDate: start,
        endDate: end,
        totalAmount: 100,
        amountPaid: 80,
        amountRemaining: 20,
        planName: kPlan,
        paymentMethod: 'cash',
        gymId: kGymId,
        coachUid: kCoachUid,
        playerName: kPlayerName,
      );

      final payments = await db
          .collection('users')
          .doc(kPlayerUid)
          .collection('payments')
          .get();

      expect(payments.docs.length, equals(1));
      final p = payments.docs.first.data();

      // Financial fields
      expect(p['type'],            equals('renewal'));
      expect(p['amount'],          equals(80.0));
      expect(p['totalAmount'],     equals(100.0));
      expect(p['amountRemaining'], equals(20.0));
      expect(p['discountAmount'],  equals(0.0));
      expect(p['durationDays'],    equals(30));
      expect(p['planName'],        equals(kPlan));
      expect(p['paymentMethod'],   equals('cash'));

      // Identity fields (needed for admin collectionGroup query)
      expect(p['gymId'],       equals(kGymId));
      expect(p['playerUid'],   equals(kPlayerUid));
      expect(p['registeredBy'],equals(kCoachUid));
      expect(p['playerName'],  equals(kPlayerName));

      // Date fields
      expect(p['startDate'], isA<Timestamp>());
      expect(p['endDate'],   isA<Timestamp>());
    });

    test('user doc is marked isActive after renewal', () async {
      await repo.renewSubscription(
        uid: kPlayerUid,
        startDate: start,
        endDate: end,
        totalAmount: 100,
        amountPaid: 100,
        amountRemaining: 0,
        planName: kPlan,
        paymentMethod: 'cash',
        gymId: kGymId,
        coachUid: kCoachUid,
      );

      final doc = await db.collection('users').doc(kPlayerUid).get();
      expect(doc.data()!['isActive'], isTrue);
    });
  });

  // ── Coach — editSubscription ───────────────────────────────────────────────

  group('Coach — editSubscription', () {
    late FakeFirebaseFirestore db;
    late CoachRepository repo;

    setUp(() async {
      db   = FakeFirebaseFirestore();
      repo = CoachRepository(firestore: db, auth: MockFirebaseAuth());
      // Player previously paid 60 JD
      await seedPlayer(db, amountPaid: 60, totalAmount: 100);
    });

    test('creates payment record only when new money is paid (delta > 0)', () async {
      final start = DateTime(2026, 7, 1);
      final end   = DateTime(2026, 7, 31);

      // New amountPaid = 80 → delta = 20 → record created
      await repo.editSubscription(
        uid: kPlayerUid,
        startDate: start,
        endDate: end,
        totalAmount: 100,
        amountPaid: 80,
        planName: kPlan,
        paymentMethod: 'cash',
        gymId: kGymId,
        coachUid: kCoachUid,
      );

      final payments = await db
          .collection('users')
          .doc(kPlayerUid)
          .collection('payments')
          .get();

      expect(payments.docs.length, equals(1),
          reason: 'delta > 0 so one payment record must be written');
      expect(payments.docs.first.data()['amount'], equals(20.0),
          reason: 'amount recorded is the delta, not the full amountPaid');
    });

    test('no payment record when amountPaid stays the same', () async {
      final start = DateTime(2026, 7, 1);
      final end   = DateTime(2026, 7, 31);

      // Same amountPaid as before (60) → delta = 0 → no record
      await repo.editSubscription(
        uid: kPlayerUid,
        startDate: start,
        endDate: end,
        totalAmount: 100,
        amountPaid: 60,
        planName: 'اشتراك جديد',
        paymentMethod: 'cash',
        gymId: kGymId,
        coachUid: kCoachUid,
      );

      final payments = await db
          .collection('users')
          .doc(kPlayerUid)
          .collection('payments')
          .get();

      expect(payments.docs.isEmpty, isTrue,
          reason: 'no new money paid → no phantom payment record');
    });

    test('user fields are SET (not incremented)', () async {
      final start = DateTime(2026, 7, 1);
      final end   = DateTime(2026, 7, 31);

      await repo.editSubscription(
        uid: kPlayerUid,
        startDate: start,
        endDate: end,
        totalAmount: 120,
        amountPaid: 90,
        planName: kPlan,
        paymentMethod: 'cash',
      );

      final doc  = await db.collection('users').doc(kPlayerUid).get();
      final data = doc.data()!;
      expect(data['totalAmount'],     equals(120.0));
      expect(data['amountPaid'],      equals(90.0));
      expect(data['amountRemaining'], equals(30.0));
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════
  // ADMIN (GYM OWNER) TESTS
  // ═════════════════════════════════════════════════════════════════════════════

  group('Admin — updatePlayerSubscription', () {
    late FakeFirebaseFirestore db;
    late AdminRepository repo;

    setUp(() async {
      db   = FakeFirebaseFirestore();
      repo = AdminRepository(firestore: db);
      await seedPlayer(db, amountPaid: 0, totalAmount: 100);
    });

    test('uses SET semantics — calling twice does NOT accumulate amountPaid', () async {
      final start = DateTime(2026, 7, 1);
      final end   = DateTime(2026, 7, 31);

      for (var i = 0; i < 2; i++) {
        await repo.updatePlayerSubscription(
          playerUid: kPlayerUid,
          plan: kPlan,
          startDate: start,
          endDate: end,
          totalAmount: 100,
          amountPaid: 70,
          paymentMethod: 'cash',
          gymId: kGymId,
          playerName: kPlayerName,
          registeredByUid: kAdminUid,
        );
      }

      final doc  = await db.collection('users').doc(kPlayerUid).get();
      final data = doc.data()!;
      expect(data['amountPaid'],      equals(70.0));
      expect(data['totalAmount'],     equals(100.0));
      expect(data['amountRemaining'], equals(30.0));
    });

    test('payment record has full schema matching coach record', () async {
      final start = DateTime(2026, 7, 1);
      final end   = DateTime(2026, 7, 31);

      await repo.updatePlayerSubscription(
        playerUid: kPlayerUid,
        plan: kPlan,
        startDate: start,
        endDate: end,
        totalAmount: 100,
        amountPaid: 70,
        paymentMethod: 'cash',
        gymId: kGymId,
        playerName: kPlayerName,
        registeredByUid: kAdminUid,
      );

      final payments = await db
          .collection('users')
          .doc(kPlayerUid)
          .collection('payments')
          .get();

      expect(payments.docs.length, equals(1));
      final p = payments.docs.first.data();

      // Unified schema — same fields as coach
      expect(p['totalAmount'],     equals(100.0));
      expect(p['amountRemaining'], equals(30.0));
      expect(p['discountAmount'],  equals(0.0));
      expect(p['durationDays'],    equals(30));
      expect(p['startDate'],       isA<Timestamp>());
      expect(p['endDate'],         isA<Timestamp>());
      expect(p['gymId'],           equals(kGymId));
      expect(p['playerUid'],       equals(kPlayerUid));
      expect(p['registeredBy'],    equals(kAdminUid));
      expect(p['playerName'],      equals(kPlayerName));
    });

    test('no payment record when no new money paid', () async {
      // Pre-seed player with 70 already paid
      await seedPlayer(db, amountPaid: 70, totalAmount: 100);
      final start = DateTime(2026, 7, 1);
      final end   = DateTime(2026, 7, 31);

      // Edit without adding money
      await repo.updatePlayerSubscription(
        playerUid: kPlayerUid,
        plan: 'اشتراك معدّل',
        startDate: start,
        endDate: end,
        totalAmount: 100,
        amountPaid: 70,  // same as existing → delta = 0
        paymentMethod: 'cash',
        gymId: kGymId,
        playerName: kPlayerName,
        registeredByUid: kAdminUid,
      );

      final payments = await db
          .collection('users')
          .doc(kPlayerUid)
          .collection('payments')
          .get();

      expect(payments.docs.isEmpty, isTrue,
          reason: 'no delta → no phantom record');
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════
  // SUPER ADMIN TESTS
  // ═════════════════════════════════════════════════════════════════════════════

  group('Super Admin — cross-gym collectionGroup payments query', () {
    late FakeFirebaseFirestore db;

    setUp(() async {
      db = FakeFirebaseFirestore();
    });

    test('sees payment records from both coach and admin for the same gym', () async {
      final start = DateTime(2026, 7, 1);
      final end   = DateTime(2026, 7, 31);

      // Seed two players
      const p1 = 'player_1';
      const p2 = 'player_2';
      await seedPlayer(db, uid: p1);
      await seedPlayer(db, uid: p2);

      // Coach writes a renewal for player_1
      final coachRepo = CoachRepository(firestore: db, auth: MockFirebaseAuth());
      await coachRepo.renewSubscription(
        uid: p1,
        startDate: start,
        endDate: end,
        totalAmount: 100,
        amountPaid: 80,
        amountRemaining: 20,
        planName: kPlan,
        paymentMethod: 'cash',
        gymId: kGymId,
        coachUid: kCoachUid,
        playerName: 'لاعب ١',
      );

      // Admin writes a subscription update for player_2
      final adminRepo = AdminRepository(firestore: db);
      await adminRepo.updatePlayerSubscription(
        playerUid: p2,
        plan: kPlan,
        startDate: start,
        endDate: end,
        totalAmount: 120,
        amountPaid: 120,
        paymentMethod: 'transfer',
        gymId: kGymId,
        playerName: 'لاعب ٢',
        registeredByUid: kAdminUid,
      );

      // Super admin queries collectionGroup by gymId
      final snap = await db
          .collectionGroup('payments')
          .where('gymId', isEqualTo: kGymId)
          .get();

      expect(snap.docs.length, equals(2),
          reason: 'super admin must see payments from both coach and admin');

      final types = snap.docs.map((d) => d.data()['type']).toSet();
      expect(types, containsAll(['renewal', 'subscription']));
    });

    test('does NOT see payments from a different gym', () async {
      const otherGym = 'gym_other';
      await seedPlayer(db);

      // Write a payment for a different gym
      await db
          .collection('users')
          .doc('other_player')
          .collection('payments')
          .add({
        'gymId':     otherGym,
        'type':      'renewal',
        'amount':    50,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Query for kGymId — should be empty
      final snap = await db
          .collectionGroup('payments')
          .where('gymId', isEqualTo: kGymId)
          .get();

      expect(snap.docs.isEmpty, isTrue,
          reason: 'super admin query is scoped to their gymId');
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════
  // PLAYER TESTS — subscription expiry date logic
  // ═════════════════════════════════════════════════════════════════════════════

  group('Player — subscription expiry logic', () {
    /// Mirrors the logic in _AuthChangeNotifier:
    ///   final newSubExpired = subEndTs is Timestamp
    ///       ? subEndTs.toDate().isBefore(DateTime.now())
    ///       : false;
    bool isExpired(Timestamp? ts) {
      if (ts == null) return false;
      return ts.toDate().isBefore(DateTime.now());
    }

    test('subscription expired yesterday → isExpired true', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(isExpired(Timestamp.fromDate(yesterday)), isTrue);
    });

    test('subscription expires tomorrow → isExpired false', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(isExpired(Timestamp.fromDate(tomorrow)), isFalse);
    });

    test('no subscriptionEnd field (null) → isExpired false', () {
      expect(isExpired(null), isFalse);
    });

    test('subscription expires today (same minute) → isExpired false', () {
      // isBefore(now) is false when the date equals now (within same second)
      final inOneMinute = DateTime.now().add(const Duration(minutes: 1));
      expect(isExpired(Timestamp.fromDate(inOneMinute)), isFalse);
    });

    test('after coach renews, subscriptionEnd is in the future → no longer expired', () async {
      final db   = FakeFirebaseFirestore();
      final repo = CoachRepository(firestore: db, auth: MockFirebaseAuth());

      // Player with expired subscription
      final pastEnd = DateTime.now().subtract(const Duration(days: 5));
      await seedPlayer(db, subscriptionEnd: pastEnd);

      final beforeRenew = await db.collection('users').doc(kPlayerUid).get();
      final beforeTs = beforeRenew.data()!['subscriptionEnd'] as Timestamp;
      expect(isExpired(beforeTs), isTrue, reason: 'should be expired before renewal');

      // Coach renews
      final newEnd = DateTime.now().add(const Duration(days: 30));
      await repo.renewSubscription(
        uid: kPlayerUid,
        startDate: DateTime.now(),
        endDate: newEnd,
        totalAmount: 100,
        amountPaid: 100,
        amountRemaining: 0,
        planName: kPlan,
        paymentMethod: 'cash',
        gymId: kGymId,
        coachUid: kCoachUid,
      );

      final afterRenew = await db.collection('users').doc(kPlayerUid).get();
      final afterTs = afterRenew.data()!['subscriptionEnd'] as Timestamp;
      expect(isExpired(afterTs), isFalse, reason: 'should NOT be expired after renewal');
    });
  });
}
