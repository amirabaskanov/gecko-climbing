// Grade display formatting for notification copy. Mirrors the client's
// GradeDisplay tables (Gecko Climbing/Core/Models/GradeDisplay.swift) — keep
// the two in sync when editing. Canonical value is always the V-scale numeric.
import { db } from '../admin';

export type GradeSystem = 'vScale' | 'font' | 'circuit';

// Ties resolve to the lower Font grade so a send is never overstated.
const FONT_LABELS: readonly string[] = [
  '4', // V0
  '5', // V1
  '5+', // V2
  '6A', // V3
  '6B', // V4
  '6C', // V5
  '7A', // V6
  '7A+', // V7
  '7B', // V8
  '7C', // V9
  '7C+', // V10
  '8A', // V11
  '8A+', // V12
  '8B', // V13
  '8B+', // V14
  '8C', // V15
  '8C+', // V16
  '9A', // V17
];

function circuitBand(numeric: number): string {
  if (numeric < 0) return '?';
  if (numeric === 0) return 'V0';
  if (numeric <= 2) return 'V1–V2';
  if (numeric <= 4) return 'V3–V4';
  if (numeric <= 6) return 'V5–V6';
  if (numeric <= 8) return 'V7–V8';
  if (numeric <= 11) return 'V9–V11';
  return 'V12+';
}

export function formatGrade(numeric: number, system: GradeSystem): string {
  switch (system) {
    case 'font':
      return numeric >= 0 && numeric < FONT_LABELS.length ? FONT_LABELS[numeric] : '?';
    case 'circuit':
      return circuitBand(numeric);
    case 'vScale':
    default:
      return `V${numeric}`;
  }
}

/** The recipient's grade-system display preference; defaults to V scale. */
export async function lookupGradeSystem(uid: string): Promise<GradeSystem> {
  const snap = await db.collection('users').doc(uid).get();
  const prefs = snap.exists ? (snap.data()?.displayPrefs as Record<string, unknown> | undefined) : undefined;
  const raw = prefs?.gradeSystem;
  if (raw === 'font' || raw === 'circuit' || raw === 'vScale') {
    return raw;
  }
  return 'vScale';
}
