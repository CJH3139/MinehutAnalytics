import { env } from "cloudflare:workers";
import { beforeEach, afterEach, expect, it, vi } from "vitest";
import { handleRequest } from "../src/api";
import { runCollector } from "../src/collector";
import { fakeFetch, makeRawResponse, resetDb } from "./helpers";
const TS = 1_789_000_200;
const db = env.DB;
const get = (range = "24h") => handleRequest(new Request(`https://test/v1/overview?range=${range}`), env);
const collect = (ts: number, players = 100, servers = 20) => runCollector(db, ts * 1000, fakeFetch(makeRawResponse([
  { id: "a", name: "Alpha", players: 30, categories: ["smp", "pvp"] },
  { id: "b", name: "Beta", players: 10, categories: ["pvp"] },
  { id: "c", name: "Gamma", players: 0, categories: [] },
], { players, servers })));
beforeEach(() => resetDb(db));
afterEach(() => vi.restoreAllMocks());
it("returns 503 without observations and validates range", async () => {
  expect((await get()).status).toBe(503);
  expect((await get("1y")).status).toBe(400);
});
it("returns real totals, listed metrics and nonoverlapping primary categories", async () => {
  await collect(TS);
  const res = await get();
  expect(res.status).toBe(200);
  expect(res.headers.get("cache-control")).toBe("public, max-age=300");
  expect(await res.json()).toEqual({ updatedAt: TS, totalPlayers: 100, totalServers: 20,
    listedPlayers: 40, activeServers: 2, playersChange24h: null, serverChange24h: null, top10Share: 100,
    points: [{ ts: TS, players: 100, servers: 20 }],
    categories: [{ name: "smp", players: 30, servers: 1 }, { name: "pvp", players: 10, servers: 1 }, { name: "Uncategorized", players: 0, servers: 1 }],
  });
});
it("uses observed 24h baselines and leaves collection failures as gaps", async () => {
  await collect(TS, 90, 22);
  vi.spyOn(console, "error").mockImplementation(() => {});
  await runCollector(db, (TS + 900) * 1000, fakeFetch({}, 500));
  await collect(TS + 86400, 100, 20);
  expect(await (await get("7d")).json()).toMatchObject({ playersChange24h: 10, serverChange24h: -2,
    points: [{ ts: TS, players: 90, servers: 22 }, { ts: TS + 86400, players: 100, servers: 20 }] });
});
it("does not invent a baseline across a long collection gap", async () => {
  await collect(TS);
  await collect(TS + 90000);
  expect(await (await get()).json()).toMatchObject({ playersChange24h: null, serverChange24h: null });
});
it("returns null concentration for a zero listed population", async () => {
  await runCollector(db, TS * 1000, fakeFetch(makeRawResponse([])));
  expect(await (await get()).json()).toMatchObject({ totalPlayers: 0, activeServers: 0, listedPlayers: 0, top10Share: null, categories: [] });
});
it("retains exactly 30 days, survives blob pruning, and filters requested range", async () => {
  await collect(TS - 2592900);
  await collect(TS - 2592000);
  await collect(TS - 604800);
  await collect(TS - 900);
  await collect(TS);
  const points = async (range: string) => (await (await get(range)).json<{points: {ts:number}[]}>()).points.map(p => p.ts);
  expect(await points("30d")).toEqual([TS - 2592000, TS - 604800, TS - 900, TS]);
  expect(await points("7d")).toEqual([TS - 604800, TS - 900, TS]);
  expect(await points("24h")).toEqual([TS - 900, TS]);
  expect((await db.prepare("SELECT COUNT(*) AS n FROM network_samples").first<{n:number}>())?.n).toBe(4);
});

it("server history does not infer zero players from omission in a successfully collected list", async () => {
  await collect(TS);
  await runCollector(db, (TS + 3600) * 1000, fakeFetch(makeRawResponse([])));
  await collect(TS + 10800);
  const response = await handleRequest(new Request("https://test/v1/server/a?range=7d"), env);
  const body = await response.json<{points: [number, number][]}>();
  expect(body.points).toEqual([[TS - 1800, 30], [TS + 9000, 30]]);
});

it("uses a nearby observed baseline within the 20 minute tolerance", async () => {
  await collect(TS - 86400 + 900, 80, 15);
  await collect(TS);
  expect(await (await get()).json()).toMatchObject({ playersChange24h: 20, serverChange24h: 5 });
});
it("computes top ten share against all listed players and skips duplicate collection slots", async () => {
  const raw = makeRawResponse(Array.from({length: 12}, (_, i) => ({ id: `s${i}`, name: `Server${i}`, players: 10 })));
  await runCollector(db, TS * 1000, fakeFetch(raw));
  expect(await runCollector(db, TS * 1000, fakeFetch(raw))).toBe("skipped");
  const body = await (await get()).json<{top10Share: number; points: unknown[]}>();
  expect(body.top10Share).toBeCloseTo(1000 / 12);
  expect(body.points).toHaveLength(1);
});
it("additive migration preserves existing tables and enforces one network row per slot", async () => {
  const {results} = await db.prepare("SELECT name FROM sqlite_master WHERE type='table'").all<{name: string}>();
  expect(results.map(row => row.name)).toEqual(expect.arrayContaining(["servers", "samples", "summaries", "snapshot_blobs", "network_samples"]));
  await collect(TS);
  await expect(db.prepare("INSERT INTO network_samples SELECT * FROM network_samples").run()).rejects.toThrow();
});
