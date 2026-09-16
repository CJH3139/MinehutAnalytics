import {
  LIST_LIMIT,
  MIN_RISING_PLAYERS,
  TOLERANCE_SECONDS,
  WINDOW_SECONDS,
  type Blob,
  type ParsedResponse,
  type ParsedServer,
  type Window,
} from "./types";

export interface RisingEntry {
  id: string;
  name: string;
  players: number;
  then: number;
  gain: number;
  pct: number | null;
}

export interface RisingBody {
  updatedAt: number;
  window: Window;
  ready: boolean;
  readyAt: number | null;
  comparedTo: number | null;
  servers: RisingEntry[];
}

export interface TopEntry {
  id: string;
  name: string;
  players: number;
  maxPlayers: number | null;
  change24h: number | null;
}

export interface TopBody {
  updatedAt: number;
  servers: TopEntry[];
}

export interface StatsBody {
  updatedAt: number;
  totalPlayers: number;
  totalServers: number;
}

export function blobCounts(servers: ParsedServer[]): Record<string, number> {
  const counts: Record<string, number> = {};
  for (const s of servers) if (s.players >= 1) counts[s.mhId] = s.players;
  return counts;
}

export function pickBlob(blobs: Blob[], target: number): Blob | null {
  let best: Blob | null = null;
  for (const b of blobs) {
    const distance = Math.abs(b.ts - target);
    if (distance > TOLERANCE_SECONDS) continue;
    const bestDistance = best ? Math.abs(best.ts - target) : Infinity;
    if (distance < bestDistance || (distance === bestDistance && best !== null && b.ts < best.ts)) best = b;
  }
  return best;
}

function compareName(a: { name: string }, b: { name: string }): number {
  return a.name < b.name ? -1 : a.name > b.name ? 1 : 0;
}

function comparePctDesc(a: number | null, b: number | null): number {
  if (a === b) return 0;
  if (a === null) return 1;
  if (b === null) return -1;
  return b - a;
}

export function computeRising(
  servers: ParsedServer[],
  ts: number,
  window: Window,
  blob: Blob | null,
  oldestBlobTs: number | null,
): RisingBody {
  if (!blob) {
    return {
      updatedAt: ts,
      window,
      ready: false,
      readyAt: oldestBlobTs === null ? null : oldestBlobTs + WINDOW_SECONDS[window],
      comparedTo: null,
      servers: [],
    };
  }
  const entries: RisingEntry[] = [];
  for (const s of servers) {
    if (s.players < MIN_RISING_PLAYERS) continue;
    const then = blob.counts[s.mhId] ?? 0;
    const gain = s.players - then;
    if (gain < 1) continue;
    const pct = then === 0 ? null : Math.round((gain / then) * 1000) / 10;
    entries.push({ id: s.mhId, name: s.name, players: s.players, then, gain, pct });
  }
  entries.sort((a, b) => b.gain - a.gain || comparePctDesc(a.pct, b.pct) || compareName(a, b));
  return { updatedAt: ts, window, ready: true, readyAt: null, comparedTo: blob.ts, servers: entries.slice(0, LIST_LIMIT) };
}

export function computeTop(servers: ParsedServer[], ts: number, blob24h: Blob | null): TopBody {
  const top = [...servers].sort((a, b) => b.players - a.players || compareName(a, b)).slice(0, LIST_LIMIT);
  return {
    updatedAt: ts,
    servers: top.map((s) => ({
      id: s.mhId,
      name: s.name,
      players: s.players,
      maxPlayers: s.info.maxPlayers,
      change24h: blob24h ? s.players - (blob24h.counts[s.mhId] ?? 0) : null,
    })),
  };
}

export function computeStats(parsed: ParsedResponse, ts: number): StatsBody {
  return { updatedAt: ts, totalPlayers: parsed.totalPlayers, totalServers: parsed.totalServers };
}
