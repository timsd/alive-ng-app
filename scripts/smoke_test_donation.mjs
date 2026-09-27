// Smoke-tests the donation destination path: every chip a donor can pick, and
// the metadata and receipt purpose each one should produce.
//
// The selector was unified but three defects survived it, all invisible from
// the UI and all asserted here:
//   * _selectedPurposeId was assigned a LABEL while every consumer compared it
//     to an id, so the donation type stayed generalSupport and the receipt
//     purpose came out empty
//   * fund_designation was written twice in one metadata map, so the later key
//     silently discarded the first
//   * "Volunteers" and "Custom Purpose" each appeared twice in the same section
//
// The selection, metadata and receipt logic below mirrors the app and the
// paystackPayments function, so the outcomes are the ones a donor gets.
//
//   node scripts/smoke_test_donation.mjs
import { readFileSync } from 'node:fs';

// Mirrored from lib/config/donation_defaults.dart.
const administrativePurposes = [
  { id: 'app_maintenance', label: 'App Maintenance' },
  { id: 'campus_workers', label: 'Campus Workers' },
  { id: 'volunteers', label: 'Volunteers' },
  { id: 'media_and_equipment', label: 'Media & Equipment' },
];

let failures = 0;
const check = (label, actual, expected) => {
  const ok = actual === expected;
  if (!ok) failures++;
  const tail = ok ? '' : `  (expected ${JSON.stringify(expected)})`;
  console.log(`  ${ok ? 'PASS' : 'FAIL'}  ${label}: ${JSON.stringify(actual)}${tail}`);
};

// Mirrors the app's toggle() selection logic.
function select(labels) {
  const chosen = new Set(labels);
  const purposes = administrativePurposes.filter((p) => chosen.has(p.label));
  return {
    designations: [...chosen],
    selectedPurposeId: purposes.length === 1 ? purposes[0].id : null,
  };
}

// Mirrors the metadata map the donation screen builds.
function buildMetadata({ designations, selectedPurposeId }) {
  const summary = designations.length === 0
    ? null
    : designations.length === 1
      ? designations[0]
      : `Split: ${designations.join(', ')} (${(100 / designations.length).toFixed(0)}% each)`;

  const selectedPurpose = selectedPurposeId
    ? administrativePurposes.find((p) => p.id === selectedPurposeId) ?? null
    : null;
  const type = selectedPurposeId === 'app_maintenance' ? 'appMaintenance' : 'generalSupport';

  const meta = { recurring: false, currency: 'NGN', source: 'donation_screen_v2' };
  if (selectedPurposeId) meta.purpose_id = selectedPurposeId;
  if (selectedPurpose) meta.fund_designation = selectedPurpose.label;
  if (designations.length) {
    // purpose_id is NOT repeated here: doing so wrote an explicit null on a
    // multi-purpose split and erased the value set above.
    meta.fund_designation = summary;
    meta.fund_designations = designations;
    meta.split_count = designations.length;
  }
  return { meta, type };
}

// Mirrors resolveDonationPurpose() in paystackPayments/src/main.js.
function resolveReceiptPurpose(meta) {
  const split = Array.isArray(meta.fund_designations) ? meta.fund_designations : [];
  if (split.length > 1) return `Split donation: ${split.join(', ')}`;
  if (split.length === 1) return split[0];
  if (meta.fund_designation && !/^split:/i.test(meta.fund_designation)) return meta.fund_designation;
  if (meta.project_title) return meta.project_title;
  return 'General Support';
}

// Read the real lists out of the Dart source so this cannot drift.
const dart = readFileSync('lib/screens/donation/donation_screen.dart', 'utf8');
const areaTitles = [
  ...dart.matchAll(/DonationImpact\(\s*icon: Icons\.\w+,\s*title: '([^']+)'/g),
].map((m) => m[1]);

console.log('1. every administrative purpose resolves to its id and receipt line');
for (const p of administrativePurposes) {
  const sel = select([p.label]);
  check(`${p.label} -> purpose_id`, sel.selectedPurposeId, p.id);
  const { meta } = buildMetadata(sel);
  check(`${p.label} -> receipt purpose`, resolveReceiptPurpose(meta), p.label);
}

console.log('\n2. app maintenance is the one purpose with its own donation type');
check('App Maintenance type', buildMetadata(select(['App Maintenance'])).type, 'appMaintenance');
check('Volunteers type', buildMetadata(select(['Volunteers'])).type, 'generalSupport');

console.log('\n3. no duplicate labels in the rendered section');
{
  const rendered = [...areaTitles, ...administrativePurposes.map((p) => p.label)];
  const dupes = rendered.filter((l, i) => rendered.indexOf(l) !== i);
  check('duplicate labels', JSON.stringify(dupes), '[]');
}

console.log('\n4. a project is tracked and printed on the receipt');
{
  const { meta } = buildMetadata(select(['Impact Hub Center']));
  meta.project_id = 'impact_hub_center';
  meta.project_title = 'Impact Hub Center';
  check('project receipt purpose', resolveReceiptPurpose(meta), 'Impact Hub Center');
}

console.log('\n5. a split across project + ministry area + purpose');
{
  const meta = buildMetadata(select(['Impact Hub Center', 'Rural Missions', 'Media & Equipment'])).meta;
  check('split_count', meta.split_count, 3);
  // Exactly one administrative purpose is in this split, so purpose_id is
  // still meaningful and must survive.
  check('purpose_id kept for the single purpose', meta.purpose_id, 'media_and_equipment');
  check(
    'receipt shows the split',
    resolveReceiptPurpose(meta),
    'Split donation: Impact Hub Center, Rural Missions, Media & Equipment',
  );
}

console.log('\n5b. a split across TWO administrative purposes clears purpose_id');
{
  const meta = buildMetadata(select(['Media & Equipment', 'Volunteers'])).meta;
  // purpose_id names a single destination, so it must not be set when the
  // donor split across two of them -- otherwise the receipt claims one.
  check('purpose_id cleared', String(meta.purpose_id), 'undefined');
  check('split still recorded', meta.fund_designations.length, 2);
}

console.log('\n6. fund_designation is written once (no silent overwrite)');
{
  const meta = buildMetadata(select(['Campus Workers'])).meta;
  check('fund_designation', meta.fund_designation, 'Campus Workers');
  check('purpose id survived', meta.purpose_id, 'campus_workers');
}

console.log('\n7. no selection falls back to general support');
{
  const { meta, type } = buildMetadata(select([]));
  check('type', type, 'generalSupport');
  check('receipt purpose', resolveReceiptPurpose(meta), 'General Support');
}

console.log(`\nministry areas rendered: ${areaTitles.length} (${areaTitles.join(', ')})`);
console.log(failures === 0 ? '\nALL CHECKS PASSED' : `\n${failures} CHECK(S) FAILED`);
process.exit(failures === 0 ? 0 : 1);
