import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, it } from "vitest";
import {
  blobTimesSince,
  getServer,
  insertBlob,
  insertSamples,
  latestBlobTs,
  loadBlobsNear,
  oldestBlobTs,
  pruneBlobs,
  pruneSamples,
  readSummary,
  samplesSince,
  upsertServers,
  writeSummaries,
} from "../src/db";
import { makeParsed, resetDb } from "./helpers";

const db = env.DB;
const TS = 1_789_000_200;

beforeEach(() => resetDb(db));

describe("servers", () => {
  it("inserts new servers with first_seen and returns rows changed", async () => {
    expect(await upsertServers(db, [makeParsed("a", "Alpha", 3), makeParsed("b", "Beta", 0)], TS)).toBe(2);
    const alpha = await getServer(db, "a");
    expect(alpha).toMatchObject({ mhId: "a", name: "Alpha", firstSeen: TS });
    expect(alpha?.info).toEqual({ motd: "", categories: [], maxPlayers: 20, author: null, icon: null, plan: null });
  });

  it("does not write unchanged servers and keeps first_seen", async () => {
    await upsertServers(db, [makeParsed("a", "Alpha", 3)], TS);
    expect(await upsertServers(db, [makeParsed("a", "Alpha", 9)], TS + 900)).toBe(0);
    expect((await getServer(db, "a"))?.firstSeen).toBe(TS);
  });

  it("renames in place when the name changes", async () => {
    await upsertServers(db, [makeParsed("a", "Alpha", 3)], TS);
    const before = await getServer(db, "a");
    expect(await upsertServers(db, [makeParsed("a", "AlphaTwo", 3)], TS + 900)).toBe(1);
    const after = await getServer(db, "a");
    expect(after?.id).toBe(before?.id);
    expect(after?.name).toBe("AlphaTwo");
  });

  it("returns null for an unknown server", async () => {
    expect(await getServer(db, "missing")).toBeNull();
  });
});

describe("samples", () => {
  it("stores only servers with players >= 1 and upserts on rerun", async () => {
    const servers = [makeParsed("a", "Alpha", 3), makeParsed("b", "Beta", 0)];
    await upsertServers(db, servers, TS);
    await insertSamples(db, servers, TS);
    await insertSamples(db, [makeParsed("a", "Alpha", 7)], TS);
    const alpha = await getServer(db, "a");
    const beta = await getServer(db, "b");
    expect(await samplesSince(db, alpha!.id, TS - 1)).toEqual([{ ts: TS, players: 7 }]);
    expect(await samplesSince(db, beta!.id, TS - 1)).toEqual([]);
  });

  it("samplesSince is exclusive and ascending; pruneSamples deletes older rows", async () => {
    const servers = [makeParsed("a", "Alpha", 3)];
    await upsertServers(db, servers, TS);
    for (const t of [TS + 900, TS, TS + 1800]) await insertSamples(db, servers, t);
    const id = (await getServer(db, "a"))!.id;
    expect((await samplesSince(db, id, TS)).map((s) => s.ts)).toEqual([TS + 900, TS + 1800]);
    await pruneSamples(db, TS + 900);
    expect((await samplesSince(db, id, 0)).map((s) => s.ts)).toEqual([TS + 900, TS + 1800]);
  });
});

describe("snapshot blobs", () => {
  it("loads only blobs within tolerance of a target", async () => {
    for (const t of [TS - 86400, TS - 3600 - 900, TS - 3600 - 1500, TS]) {
      await insertBlob(db, { ts: t, counts: { a: 1 } });
    }
    const loaded = await loadBlobsNear(db, [TS - 3600, TS - 21600, TS - 86400]);
    expect(loaded.map((b) => b.ts).sort((x, y) => x - y)).toEqual([TS - 86400, TS - 3600 - 900]);
    expect(loaded[0].counts).toEqual({ a: 1 });
  });

  it("reports oldest, latest, and times since; prunes old blobs", async () => {
    expect(await oldestBlobTs(db)).toBeNull();
    expect(await latestBlobTs(db)).toBeNull();
    for (const t of [TS, TS - 900, TS - 1800]) await insertBlob(db, { ts: t, counts: {} });
    expect(await oldestBlobTs(db)).toBe(TS - 1800);
    expect(await latestBlobTs(db)).toBe(TS);
    expect(await blobTimesSince(db, TS - 1800)).toEqual([TS - 900, TS]);
    await pruneBlobs(db, TS - 900);
    expect(await oldestBlobTs(db)).toBe(TS - 900);
  });
});

describe("summaries", () => {
  it("writes, overwrites, and reads raw JSON", async () => {
    expect(await readSummary(db, "top")).toBeNull();
    await writeSummaries(db, TS, [{ key: "top", data: { n: 1 } }, { key: "stats", data: { n: 2 } }]);
    await writeSummaries(db, TS + 900, [{ key: "top", data: { n: 3 } }]);
    expect(await readSummary(db, "top")).toBe('{"n":3}');
    expect(await readSummary(db, "stats")).toBe('{"n":2}');
  });
});
