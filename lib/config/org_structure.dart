/// Organisation structure: the offices ALIVE Nigeria is built from.\n/// One office in the organisation.
///
/// About > Leadership currently shows five people, but between them they hold
/// TEN combined roles ("Director, Evangelism, Programming, and Health" is
/// really four). Modelling each office separately means:
///   * a person can hold several of them (true today),
///   * a new office can be added as the organisation grows without rewriting
///     the leadership list,
///   * reporting lines and permissions attach to the OFFICE, not to a person,
///     so they survive a change of holder.
///
/// This is the single source of truth. `about_alive_screen.dart` renders it and
/// `scripts/seed_org_offices.mjs` mirrors it into the `org_offices` table.
class OrgOffice {
  /// Stable slug stored as `office_id`. Never change it once seeded: reports
  /// and chat rooms are routed by this value.
  final String id;

  final String title;

  /// Icon shown on the About > Leadership card.
  final String iconName;

  /// The office this one reports into. null for the top of the chain.
  final String? reportsTo;

  /// Who currently holds it. A person may appear under several offices.
  final String? holderName;

  /// When true, the people behind this office are shown to leadership only.
  /// The office itself is still listed publicly, so members can see that the
  /// structure exists -- just not who fills it.
  final bool namesRestrictedToLeadership;

  /// Everyone serving in this office, when the office has more than one
  /// holder (a board, for example). [holderName] is the chair/lead.
  final List<String> memberNames;

  const OrgOffice({
    required this.id,
    required this.title,
    required this.iconName,
    this.reportsTo,
    this.holderName,
    this.namesRestrictedToLeadership = false,
    this.memberNames = const [],
  });
}

/// The reporting chain:
///   Trustees (apex, reports to no one)
///     └── Board of Directors (governance, oversight, strategy)
///           └── Executive President & Directors (operations, ministry execution)
///               * Nwoko Patience Mfon and Timothy Olodude hold dual functions
///                 connecting Directors to the Board of Directors on affairs and finance.
const List<OrgOffice> kOrgOffices = [
  // ── Trustees (Apex - reports to no one) ──────────────────────────────────
  OrgOffice(
    id: 'board_of_trustees',
    title: 'Trustees',
    iconName: 'shield',
    reportsTo: null,
    holderName: 'Jerry Kwarba',
    namesRestrictedToLeadership: true,
    memberNames: [
      'Jerry Kwarba',
      'Imoh Imeh',
    ],
  ),
  OrgOffice(
    id: 'trustee',
    title: 'Trustee (Board Member)',
    iconName: 'verified_user',
    reportsTo: null,
    holderName: 'Jerry Kwarba',
    namesRestrictedToLeadership: true,
  ),

  // ── Board of Directors (BOD - reports to Board of Trustees) ───────────────
  OrgOffice(
    id: 'board_of_directors',
    title: 'Board of Directors',
    iconName: 'business_center',
    reportsTo: 'board_of_trustees',
    holderName: 'Nwoko Patience Mfon',
    memberNames: [
      'Nwoko Patience Mfon',
      'Timothy Olodude',
      'Okechukwu Elechi',
      'Imoh Imeh',
      'Ajibade Ayodeji',
      'Fatola Samson',
      'Bassey Etido',
      'Joshua Umahi',
      'Frank A',
      'Emeka Okoro',
      'Nancy Elechi',
    ],
  ),
  OrgOffice(
    id: 'bod',
    title: 'Director (Board Member)',
    iconName: 'business_center',
    reportsTo: 'board_of_directors',
  ),

  // ── Executive Directorate (reports to Board of Directors) ─────────────────
  OrgOffice(
    id: 'executive_president',
    title: 'Executive President',
    iconName: 'person',
    reportsTo: 'board_of_directors',
    holderName: 'Nwoko Patience Mfon',
  ),

  // ── Directors (report to Executive President) ─────────────────────────────
  OrgOffice(
    id: 'secretary',
    title: 'Secretary',
    iconName: 'description',
    reportsTo: 'executive_president',
    holderName: 'Caleb Peters',
  ),
  OrgOffice(
    id: 'communication_director',
    title: 'Communication Director',
    iconName: 'chat',
    reportsTo: 'executive_president',
    holderName: 'Caleb Peters',
  ),
  OrgOffice(
    id: 'speaker',
    title: 'Speaker',
    iconName: 'record_voice_over',
    reportsTo: 'executive_president',
    holderName: 'Godstime Esuku',
  ),
  OrgOffice(
    id: 'director_amtc',
    title: 'Director, ALIVE Mission Training Center (AMTC)',
    iconName: 'school',
    reportsTo: 'executive_president',
    holderName: 'Godstime Esuku',
  ),
  OrgOffice(
    id: 'treasurer',
    title: 'Treasurer',
    iconName: 'account_balance_wallet',
    reportsTo: 'executive_president',
    holderName: 'Timothy Olodude',
  ),
  OrgOffice(
    id: 'director_logistics',
    title: 'Director of Logistics',
    iconName: 'local_shipping',
    reportsTo: 'executive_president',
    holderName: 'Timothy Olodude',
  ),
  OrgOffice(
    id: 'director_evangelism',
    title: 'Director of Evangelism',
    iconName: 'campaign',
    reportsTo: 'executive_president',
    holderName: 'Emenike Ekechi',
  ),
  OrgOffice(
    id: 'director_programming',
    title: 'Director of Programming',
    iconName: 'event_note',
    reportsTo: 'executive_president',
    holderName: 'Emenike Ekechi',
  ),
  OrgOffice(
    id: 'director_health',
    title: 'Director of Health',
    iconName: 'health_and_safety',
    reportsTo: 'executive_president',
    holderName: 'Emenike Ekechi',
  ),
];

/// Look up an office by its stable id, or null when unknown.
OrgOffice? orgOfficeById(String id) {
  for (final office in kOrgOffices) {
    if (office.id == id) return office;
  }
  return null;
}

/// A person, and every office they hold.
///
/// [kOrgOffices] is keyed on one row per office because routing and the seed
/// script both depend on a unique `office_id`. But a person may hold several
/// offices, and showing "Timothy Olodude" twice -- once as Treasurer, once as
/// Director of Logistics -- reads as duplicated people. This view groups the
/// offices under one name instead. The office registry stays untouched; this
/// is only how the About page presents it.
class OrgPerson {
  final String name;

  /// Every office this person holds, in reporting order.
  final List<OrgOffice> offices;

  const OrgPerson({required this.name, required this.offices});

  bool get isRestricted =>
      offices.every((o) => o.namesRestrictedToLeadership);

  /// The chair of the board is the first named member, and is called out
  /// rather than being lost among the other trustees.
  bool get isBoardChair => offices.any((o) => o.id == 'board_of_trustees');

  /// True if this person is a Trustee (Jerry Kwarba, Imoh Imeh).
  bool get isTrustee =>
      offices.any((o) => o.id == 'trustee' || o.id == 'board_of_trustees');

  /// True if this person is a member of the Board of Directors (BOD).
  bool get isBodMember =>
      offices.any((o) => o.id == 'bod' || o.id == 'board_of_directors');

  /// True if this person is an Executive / Departmental Director (Nwoko, Caleb, Godstime, Timothy, Emenike).
  bool get isDirector =>
      offices.any((o) => o.id != 'trustee' && o.id != 'board_of_trustees' && o.id != 'bod' && o.id != 'board_of_directors');

  /// True if this leader holds a dual function connecting Directors to the Board of Directors
  /// (Nwoko Patience Mfon on affairs, Timothy Olodude on finance).
  bool get hasDualFunction => isDirector && isBodMember;
}

/// The leadership roster, one entry per person, grouped from [kOrgOffices].
///
/// Order follows the registry, so the board chair comes first and each
/// person's offices stay in the order they were declared.
final List<OrgPerson> leadershipPeople = _buildLeadershipPeople();

List<OrgPerson> _buildLeadershipPeople() {
  final people = <String, List<OrgOffice>>{};

  void add(String name, OrgOffice office) {
    if (name.trim().isEmpty) return;
    // A person cannot hold the same office twice.
    final list = people.putIfAbsent(name, () => <OrgOffice>[]);
    if (!list.any((o) => o.id == office.id)) list.add(office);
  }

  for (final office in kOrgOffices) {
    if (office.holderName != null) {
      add(office.holderName!, office);
    }
    if (office.memberNames.isEmpty) continue;

    final memberOffice = office.id == 'board_of_directors'
        ? (orgOfficeById('bod') ??
            const OrgOffice(
              id: 'bod',
              title: 'Director (Board Member)',
              iconName: 'business_center',
              reportsTo: 'board_of_directors',
            ))
        : office.id == 'board_of_trustees'
            ? (orgOfficeById('trustee') ??
                const OrgOffice(
                  id: 'trustee',
                  title: 'Trustee (Board Member)',
                  iconName: 'verified_user',
                  reportsTo: null,
                  namesRestrictedToLeadership: true,
                ))
            : null;

    if (memberOffice == null) continue;

    for (final member in office.memberNames) {
      if (member == office.holderName) continue; // added above
      add(member, memberOffice);
    }
  }

  return people.entries
      .map((e) => OrgPerson(name: e.key, offices: e.value))
      .toList(growable: false);
}

/// Asserts the registry is internally consistent. Routing and the seed script
/// are both keyed on `office_id`, so a duplicate id would silently break which
/// office a report or room resolves to.
void assertOrgOfficesAreConsistent() {
  assert(
    () {
      final seen = <String>{};
      for (final office in kOrgOffices) {
        assert(
          seen.add(office.id),
          'Duplicate office id "${office.id}". Every office needs a unique id; '
          'a body with several holders belongs in memberNames, not in a '
          'repeated office entry.',
        );
      }
      // Every reportsTo must point at an office that actually exists.
      for (final office in kOrgOffices) {
        final target = office.reportsTo;
        if (target == null) continue;
        assert(
          seen.contains(target),
          'Office "${office.id}" reports into "$target", which is not a known '
            'office.',
        );
      }
      return true;
    }(),
  );
}

/// The offices held by one person, in declaration order.
List<OrgOffice> orgOfficesFor(String holderName) {
  return kOrgOffices
      .where((o) => o.holderName == holderName)
      .toList(growable: false);
}

