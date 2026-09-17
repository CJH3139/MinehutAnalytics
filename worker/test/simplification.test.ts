import { env } from "cloudflare:workers";
import { beforeEach, expect, it } from "vitest";
import { runCollector } from "../src/collector";
import { handleRequest } from "../src/api";
import { insertBlob, oldestBlobTs } from "../src/db";
import { fakeFetch, makeRawResponse, resetDb } from "./helpers";

const TS = 1_789_000_200;
const get = (path: string) => handleRequest(new Request(`https://test${path}`), env);
beforeEach(() => resetDb(env.DB));

it.each([["12h", 43200], ["7d", 604800]] as const)("compares %s with its actual baseline", async (window, seconds) => {
  await runCollector(env.DB, (TS - seconds) * 1000, fakeFetch(makeRawResponse([{ id: "a", name: "Alpha", players: 10 }])));
  // Daily collection must not prune the week-old baseline before it can be used.
  await runCollector(env.DB, (TS - 900) * 1000, fakeFetch(makeRawResponse([{ id: "a", name: "Alpha", players: 18 }])));
  await runCollector(env.DB, TS * 1000, fakeFetch(makeRawResponse([{ id: "a", name: "Alpha", players: 25, icon: "END_CRYSTAL" }])));
  const response = await get(`/v1/rising?window=${window}`);
  expect(response.status).toBe(200);
  expect(await response.json()).toMatchObject({ window, ready: true, comparedTo: TS - seconds,
    servers: [{ id: "a", then: 10, gain: 15, icon: "END_CRYSTAL" }] });
});

it("reports weekly warm-up without inventing a baseline", async () => {
  await runCollector(env.DB, TS * 1000, fakeFetch(makeRawResponse([{ id: "a", name: "Alpha", players: 25 }])));
  const response = await get("/v1/rising?window=7d");
  expect(response.status).toBe(200);
  expect(await response.json()).toMatchObject({ ready: false, readyAt: TS + 604800, comparedTo: null, servers: [] });
});

it("passes the official icon through rankings and server detail", async () => {
  await runCollector(env.DB, TS * 1000, fakeFetch(makeRawResponse([{ id: "a", name: "Alpha", players: 25, icon: "END_CRYSTAL" }])));
  expect(await (await get("/v1/top")).json()).toMatchObject({ servers: [{ icon: "END_CRYSTAL" }] });
  expect(await (await get("/v1/server/a")).json()).toMatchObject({ server: { icon: "END_CRYSTAL" } });
});

it("bounds snapshot retention while preserving a week plus baseline tolerance", async () => {
  await insertBlob(env.DB, { ts: TS - 608401, counts: {} });
  await insertBlob(env.DB, { ts: TS - 608400, counts: {} });
  await runCollector(env.DB, TS * 1000, fakeFetch(makeRawResponse([])));
  expect(await oldestBlobTs(env.DB)).toBe(TS - 608400);
});
