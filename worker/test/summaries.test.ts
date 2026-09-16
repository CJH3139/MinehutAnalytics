import { describe, expect, it } from "vitest";
import { blobCounts, computeRising, computeStats, computeTop, pickBlob } from "../src/summaries";
import { makeParsed } from "./helpers";

const TS = 1_789_000_200;

describe("blobCounts", () => {
  it("keeps only servers with at least 1 player", () => {
    expect(blobCounts([makeParsed("a", "A", 0), makeParsed("b", "B", 3)])).toEqual({ b: 3 });
  });
});

describe("pickBlob", () => {
  const target = TS - 3600;

  it("returns null for no blobs", () => {
    expect(pickBlob([], target)).toBeNull();
  });

  it("returns the nearest blob within 1200 seconds", () => {
    const blobs = [
      { ts: target - 900, counts: {} },
      { ts: target + 300, counts: {} },
    ];
    expect(pickBlob(blobs, target)?.ts).toBe(target + 300);
  });

  it("ignores blobs further than 1200 seconds away", () => {
    expect(pickBlob([{ ts: target - 1201, counts: {} }], target)).toBeNull();
    expect(pickBlob([{ ts: target + 1200, counts: {} }], target)?.ts).toBe(target + 1200);
  });

  it("prefers the earlier blob on an exact tie", () => {
    const blobs = [
      { ts: target + 600, counts: {} },
      { ts: target - 600, counts: {} },
    ];
    expect(pickBlob(blobs, target)?.ts).toBe(target - 600);
  });
});

describe("computeRising", () => {
  it("is not ready without a comparison blob", () => {
    expect(computeRising([makeParsed("a", "A", 50)], TS, "1h", null, TS - 900)).toEqual({
      updatedAt: TS,
      window: "1h",
      ready: false,
      readyAt: TS - 900 + 3600,
      comparedTo: null,
      servers: [],
    });
  });

  it("has a null readyAt when there are no blobs at all", () => {
    expect(computeRising([], TS, "24h", null, null).readyAt).toBeNull();
  });

  it("counts a server missing from the blob as 0 players then", () => {
    const body = computeRising([makeParsed("a", "A", 12)], TS, "1h", { ts: TS - 3600, counts: {} }, TS - 3600);
    expect(body.ready).toBe(true);
    expect(body.comparedTo).toBe(TS - 3600);
    expect(body.servers).toEqual([{ id: "a", name: "A", players: 12, then: 0, gain: 12, pct: null }]);
  });

  it("drops servers under 5 players now or without a gain", () => {
    const servers = [makeParsed("small", "Small", 4), makeParsed("flat", "Flat", 30), makeParsed("down", "Down", 20)];
    const blob = { ts: TS - 3600, counts: { small: 1, flat: 30, down: 25 } };
    expect(computeRising(servers, TS, "1h", blob, blob.ts).servers).toEqual([]);
  });

  it("sorts by gain, then pct with nulls last, then name", () => {
    const servers = [
      makeParsed("n", "NewOne", 10),
      makeParsed("b", "Beta", 20),
      makeParsed("a", "Alpha", 20),
      makeParsed("big", "Big", 100),
      makeParsed("c", "Gamma", 15),
    ];
    const blob = { ts: TS - 3600, counts: { b: 10, a: 10, big: 50, c: 12 } };
    const body = computeRising(servers, TS, "1h", blob, blob.ts);
    expect(body.servers.map((s) => s.name)).toEqual(["Big", "Alpha", "Beta", "NewOne", "Gamma"]);
    expect(body.servers.find((s) => s.name === "Gamma")?.pct).toBe(25);
  });

  it("rounds pct to one decimal", () => {
    const blob = { ts: TS - 3600, counts: { a: 3 } };
    expect(computeRising([makeParsed("a", "A", 7)], TS, "1h", blob, blob.ts).servers[0].pct).toBe(133.3);
  });

  it("returns at most 50 servers", () => {
    const servers = Array.from({ length: 60 }, (_, i) => makeParsed(`s${i}`, `S${i}`, 10 + i));
    const blob = { ts: TS - 3600, counts: {} };
    expect(computeRising(servers, TS, "1h", blob, blob.ts).servers).toHaveLength(50);
  });
});

describe("computeTop", () => {
  const servers = [makeParsed("a", "Alpha", 10, 50), makeParsed("b", "Beta", 30, null), makeParsed("c", "Charlie", 10)];

  it("sorts by players then name and maps fields", () => {
    const body = computeTop(servers, TS, null);
    expect(body).toEqual({
      updatedAt: TS,
      servers: [
        { id: "b", name: "Beta", players: 30, maxPlayers: null, change24h: null },
        { id: "a", name: "Alpha", players: 10, maxPlayers: 50, change24h: null },
        { id: "c", name: "Charlie", players: 10, maxPlayers: 20, change24h: null },
      ],
    });
  });

  it("computes change24h from the 24h blob, missing counts as 0", () => {
    const body = computeTop(servers, TS, { ts: TS - 86400, counts: { a: 15, b: 30 } });
    expect(body.servers.map((s) => s.change24h)).toEqual([0, -5, 10]);
  });

  it("returns at most 50 servers", () => {
    const many = Array.from({ length: 60 }, (_, i) => makeParsed(`s${i}`, `S${i}`, i));
    expect(computeTop(many, TS, null).servers).toHaveLength(50);
  });
});

describe("computeStats", () => {
  it("copies totals", () => {
    expect(computeStats({ servers: [], totalPlayers: 2400, totalServers: 950 }, TS)).toEqual({
      updatedAt: TS,
      totalPlayers: 2400,
      totalServers: 950,
    });
  });
});
