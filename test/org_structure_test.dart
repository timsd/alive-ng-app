import 'package:alive_flutter_app/config/org_structure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('leadershipPeople', () {
    test('lists one entry per person, not per office', () {
      // 10 trustees (Jerry + 9) plus the 5 other office holders. Before
      // grouping, kOrgOffices had 12 rows and repeated several names.
      expect(leadershipPeople.length, 15);

      final names = leadershipPeople.map((p) => p.name).toList();
      // A person holding two offices must appear once, not twice.
      expect(names.toSet().length, names.length);
    });

    test('groups every office a person holds under their name', () {
      OrgPerson personNamed(String name) =>
          leadershipPeople.firstWhere((p) => p.name == name);

      expect(
        personNamed('Timothy Olodude').offices.map((o) => o.id),
        containsAll(<String>['treasurer', 'director_logistics']),
      );
      expect(
        personNamed('Emenike Ekechi').offices.map((o) => o.id),
        containsAll(<String>[
          'director_evangelism',
          'director_programming',
          'director_health',
        ]),
      );
      // The board chair also holds the trustee office, and must not be
      // listed twice because of it.
      final chair = personNamed('Jerry Kwarba');
      expect(chair.isBoardChair, isTrue);
      expect(
        chair.offices.map((o) => o.id),
        containsAll(<String>['board_of_trustees', 'trustee']),
      );
    });

    test('the remaining trustees each hold the trustee office alone', () {
      for (final name in ['Okey Elechi', 'Imoh Imeh', 'Nancy Elechi']) {
        final person = leadershipPeople.firstWhere((p) => p.name == name);
        expect(person.offices.length, 1);
        expect(person.offices.single.id, 'trustee');
      }
    });

    test('trustees are flagged restricted, other officers are not', () {
      expect(
        leadershipPeople
            .where((p) => p.name == 'Okey Elechi')
            .single
            .isRestricted,
        isTrue,
      );
      expect(
        leadershipPeople
            .where((p) => p.name == 'Timothy Olodude')
            .single
            .isRestricted,
        isFalse,
      );
    });
  });
}
