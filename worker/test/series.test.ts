import { describe, expect, it } from "vitest";
import { buildPoints, peakOf } from "../src/series";

const TS = 1_789_000_200;
const HOUR_OF_TS = TS - 1800;

describe("buildPoints 24h", () => {
  it("follows blob times inside the last 24 hours, filling 0 for missing samples", () => {
    const points = buildPoints("24h", TS, [{ ts: TS - 900, players: 5 }], [TS - 86400, TS - 1800, TS - 900, TS], 0);
    expect(points).toEqual([
      [TS - 1800, 0],
      [TS - 900, 5],
      [TS, 0],
    ]);
  });

  it("has no point where the collector did not run", () => {
    expect(buildPoints("24h", TS, [], [TS - 1800, TS], 0).map((p) => p[0])).toEqual([TS - 1800, TS]);
  });
});

describe("buildPoints 7d and 30d", () => {
  it("returns 168 hourly points for 7d and 720 for 30d when first seen long ago", () => {
    const week = buildPoints("7d", TS, [], [], 0);
    expect(week).toHaveLength(168);
    expect(week[167]).toEqual([HOUR_OF_TS, 0]);
    expect(week[0][0]).toBe(HOUR_OF_TS - 167 * 3600);
    expect(buildPoints("30d", TS, [], [], 0)).toHaveLength(720);
  });

  it("uses the max sample within each hour", () => {
    const samples = [
      { ts: HOUR_OF_TS, players: 4 },
      { ts: HOUR_OF_TS + 900, players: 9 },
      { ts: HOUR_OF_TS - 900, players: 2 },
    ];
    const week = buildPoints("7d", TS, samples, [], 0);
    expect(week[167]).toEqual([HOUR_OF_TS, 9]);
    expect(week[166]).toEqual([HOUR_OF_TS - 3600, 2]);
  });

  it("starts at the hour the server was first seen", () => {
    const points = buildPoints("7d", TS, [], [], HOUR_OF_TS - 7200 + 100);
    expect(points.map((p) => p[0])).toEqual([HOUR_OF_TS - 7200, HOUR_OF_TS - 3600, HOUR_OF_TS]);
  });
});

describe("peakOf", () => {
  it("returns the highest point, earliest on ties", () => {
    expect(
      peakOf([
        [1, 3],
        [2, 8],
        [3, 8],
      ]),
    ).toEqual({ players: 8, ts: 2 });
  });

  it("returns null for no points", () => {
    expect(peakOf([])).toBeNull();
  });
});
