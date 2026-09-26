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

  const OrgOffice({
    required this.id,
    required this.title,
    required this.iconName,
    this.reportsTo,
    this.holderName,
  });
}

/// The reporting chain:
///   Board of Trustees -> President -> Directors
/// A director is supervised by a trustee.
const List<OrgOffice> kOrgOffices = [
  // ── Board of Trustees ────────────────────────────────────────────────────
  OrgOffice(
    id: 'board_of_trustees',
    title: 'Board of Trustees',
    iconName: 'shield',
    holderName: 'Emenike Ekechi',
  ),
  OrgOffice(
    id: 'trustee',
    title: 'Trustee',
    iconName: 'verified_user',
    reportsTo: 'board_of_trustees',
    holderName: 'Emenike Ekechi',
  ),

  // ── Executive ────────────────────────────────────────────────────────────
  OrgOffice(
    id: 'executive_president',
    title: 'Executive President',
    iconName: 'person',
    reportsTo: 'board_of_trustees',
    holderName: 'Nwoko Patience Mfon',
  ),

  // ── Directors (each supervised by a trustee) ─────────────────────────────
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

/// The offices held by one person, in declaration order.
List<OrgOffice> orgOfficesFor(String holderName) {
  return kOrgOffices
      .where((o) => o.holderName == holderName)
      .toList(growable: false);
}

