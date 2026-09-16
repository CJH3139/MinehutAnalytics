import type { SampleRow } from "./db";
import { RANGE_SECONDS, type Range } from "./types";

export type Point = [number, number];

const HOUR = 3600;

const floorHour = (ts: number) => Math.floor(ts / HOUR) * HOUR;

export function buildPoints(
  range: Range,
  latestTs: number,
  samples: SampleRow[],
  blobTimes: number[],
  firstSeen: number,
): Point[] {
  if (range === "24h") {
    const playersAt = new Map(samples.map((s) => [s.ts, s.players]));
    return blobTimes
      .filter((t) => t > latestTs - RANGE_SECONDS["24h"] && t <= latestTs)
      .map((t) => [t, playersAt.get(t) ?? 0]);
  }

  const maxByHour = new Map<number, number>();
  for (const s of samples) {
    const hour = floorHour(s.ts);
    maxByHour.set(hour, Math.max(maxByHour.get(hour) ?? 0, s.players));
  }
  const lastHour = floorHour(latestTs);
  const start = Math.max(floorHour(latestTs - RANGE_SECONDS[range]) + HOUR, floorHour(firstSeen));
  const points: Point[] = [];
  for (let hour = start; hour <= lastHour; hour += HOUR) points.push([hour, maxByHour.get(hour) ?? 0]);
  return points;
}

export function peakOf(points: Point[]): { players: number; ts: number } | null {
  let peak: { players: number; ts: number } | null = null;
  for (const [ts, players] of points) {
    if (!peak || players > peak.players) peak = { players, ts };
  }
  return peak;
}
