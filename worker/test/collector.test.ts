import { createScheduledController } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { runCollector, snapshotTs } from "../src/collector";
import { getServer, insertBlob, insertSamples, oldestBlobTs, readSummary, samplesSince, upsertServers } from "../src/db";
import worker from "../src/index";
import { fakeFetch, makeParsed, makeRawResponse, resetDb } from "./helpers";

const db = env.DB;
const TS = 1_789_000_200;
const MIDNIGHT = 1_788_998_400;
const ms = (seconds: number) => seconds * 1000;

beforeEach(() => resetDb(db));
afterEach(() => vi.restoreAllMocks());

describe("snapshotTs", () => {
  it("floors to the 15-minute mark", () => {
    expect(snapshotTs(ms(TS) + 899_999)).toBe(TS);
    expect(snapshotTs(ms(TS))).toBe(TS);
  });
});

describe("runCollector", () => {
  const first = makeRawResponse(
    [
      { id: "a", name: "Alpha", players: 40 },
      { id: "b", name: "Beta", players: 0 },
    ],
    { players: 2000, servers: 900 },
  );

  it("records servers, samples, blob, and summaries on the first run", async () => {
    expect(await runCollector(db, ms(TS) + 5000, fakeFetch(first))).toBe("ok");

    const alpha = await getServer(db, "a");
    expect(await samplesSince(db, alpha!.id, 0)).toEqual([{ ts: TS, players: 40 }]);
    expect(await getServer(db, "b")).not.toBeNull();
    expect(await oldestBlobTs(db)).toBe(TS);

    const rising = JSON.parse((await readSummary(db, "rising_1h"))!);
    expect(rising).toMatchObject({ updatedAt: TS, ready: false, readyAt: TS + 3600 });
    const top = JSON.parse((await readSummary(db, "top"))!);
    expect(top.servers[0]).toEqual({ id: "a", name: "Alpha", players: 40, maxPlayers: 20, change24h: null });
    expect(JSON.parse((await readSummary(db, "stats"))!)).toEqual({ updatedAt: TS, totalPlayers: 2000, totalServers: 900 });
  });

  it("produces a ready rising list one hour later", async () => {
    await runCollector(db, ms(TS), fakeFetch(first));
    const later = makeRawResponse([
      { id: "a", name: "Alpha", players: 55 },
      { id: "b", name: "Beta", players: 9 },
    ]);
    await runCollector(db, ms(TS + 3600), fakeFetch(later));
    const rising = JSON.parse((await readSummary(db, "rising_1h"))!);
    expect(rising.ready).toBe(true);
    expect(rising.comparedTo).toBe(TS);
    expect(rising.servers.map((s: { id: string; gain: number }) => [s.id, s.gain])).toEqual([
      ["a", 15],
      ["b", 9],
    ]);
  });

  it("skips a snapshot that already exists without fetching Minehut", async () => {
    await runCollector(db, ms(TS), fakeFetch(first));
    const before = await readSummary(db, "top");
    const spy = vi.fn(fakeFetch(first));
    expect(await runCollector(db, ms(TS) + 60_000, spy as unknown as typeof fetch)).toBe("skipped");
    expect(spy).not.toHaveBeenCalled();
    expect(await readSummary(db, "top")).toBe(before);
  });

  it("leaves summaries untouched when Minehut returns an error", async () => {
    await runCollector(db, ms(TS), fakeFetch(first));
    const before = await readSummary(db, "top");
    vi.spyOn(console, "error").mockImplementation(() => {});
    expect(await runCollector(db, ms(TS + 900), fakeFetch({ message: "down" }, 500))).toBe("fetch_failed");
    expect(await runCollector(db, ms(TS + 900), fakeFetch({ servers: "nope" }))).toBe("fetch_failed");
    expect(await readSummary(db, "top")).toBe(before);
    expect(await oldestBlobTs(db)).toBe(TS);
  });

  it("prunes blobs older than 25 hours", async () => {
    await insertBlob(db, { ts: TS - 90001, counts: {} });
    await insertBlob(db, { ts: TS - 90000, counts: {} });
    await runCollector(db, ms(TS), fakeFetch(first));
    expect(await oldestBlobTs(db)).toBe(TS - 90000);
  });

  it("prunes samples older than 30 days only on the midnight run", async () => {
    const old = [makeParsed("a", "Alpha", 3)];
    await upsertServers(db, old, 0);
    const id = (await getServer(db, "a"))!.id;

    await insertSamples(db, old, TS - 2592001);
    await runCollector(db, ms(TS), fakeFetch(first));
    expect((await samplesSince(db, id, 0)).map((s) => s.ts)).toContain(TS - 2592001);

    await insertSamples(db, old, MIDNIGHT - 2592001);
    await runCollector(db, ms(MIDNIGHT), fakeFetch(first));
    const remaining = (await samplesSince(db, id, 0)).map((s) => s.ts);
    expect(remaining).not.toContain(MIDNIGHT - 2592001);
    expect(remaining).toContain(MIDNIGHT);
  });
});

describe("scheduled handler", () => {
  it("runs the collector with the global fetch", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(
      fakeFetch(makeRawResponse([{ id: "a", name: "Alpha", players: 12 }])),
    );
    const controller = createScheduledController({ scheduledTime: new Date(ms(TS)), cron: "*/15 * * * *" });
    await worker.scheduled(controller, env);
    expect(JSON.parse((await readSummary(db, "top"))!).servers[0].id).toBe("a");
  });
});

describe("top series summary", () => {
  it("records a line per top server across runs", async () => {
    const first = makeRawResponse([
      { id: "a", name: "Alpha", players: 40, maxPlayers: 100 },
      { id: "b", name: "Beta", players: 12 },
    ]);
    const later = makeRawResponse([
      { id: "a", name: "Alpha", players: 55, maxPlayers: 100 },
      { id: "b", name: "Beta", players: 9 },
    ]);
    await runCollector(db, ms(TS), fakeFetch(first));
    await runCollector(db, ms(TS + 900), fakeFetch(later));

    const body = JSON.parse((await readSummary(db, "top_series"))!);
    expect(body.updatedAt).toBe(TS + 900);
    expect(body.servers.map((s: { id: string }) => s.id)).toEqual(["a", "b"]);
    expect(body.servers[0]).toMatchObject({ name: "Alpha", players: 55, maxPlayers: 100 });
    expect(body.servers[0].points).toEqual([
      [TS, 40],
      [TS + 900, 55],
    ]);
    expect(body.servers[1].points).toEqual([
      [TS, 12],
      [TS + 900, 9],
    ]);
  });
});
