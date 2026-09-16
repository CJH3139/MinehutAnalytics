import { env } from "cloudflare:workers";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { handleRequest } from "../src/api";
import { runCollector } from "../src/collector";
import { readSummary, writeSummaries } from "../src/db";
import worker from "../src/index";
import { fakeFetch, makeRawResponse, resetDb } from "./helpers";

const db = env.DB;
const TS = 1_789_000_200;
const HOUR_OF_TS = TS - 1800;

const get = (path: string, method = "GET") => handleRequest(new Request(`https://api.test${path}`, { method }), env);

beforeEach(() => resetDb(db));

describe("summary endpoints", () => {
  it("return 503 no_data before the collector has run", async () => {
    for (const path of ["/v1/top", "/v1/stats", "/v1/rising?window=1h"]) {
      const res = await get(path);
      expect(res.status).toBe(503);
      expect(res.headers.get("cache-control")).toBe("no-store");
      expect(await res.json()).toEqual({ error: "no_data" });
    }
  });

  it("return the stored JSON with a 5-minute cache header", async () => {
    await writeSummaries(db, TS, [
      { key: "top", data: { which: "top" } },
      { key: "stats", data: { which: "stats" } },
      { key: "rising_1h", data: { which: "1h" } },
      { key: "rising_24h", data: { which: "24h" } },
    ]);
    const top = await get("/v1/top");
    expect(top.status).toBe(200);
    expect(top.headers.get("cache-control")).toBe("public, max-age=300");
    expect(top.headers.get("content-type")).toContain("application/json");
    expect(await top.json()).toEqual({ which: "top" });
    expect(await (await get("/v1/stats")).json()).toEqual({ which: "stats" });
    expect(await (await get("/v1/rising?window=1h")).json()).toEqual({ which: "1h" });
    expect(await (await get("/v1/rising")).json()).toEqual({ which: "24h" });
  });

  it("rejects an unknown rising window", async () => {
    const res = await get("/v1/rising?window=2h");
    expect(res.status).toBe(400);
    expect(await res.json()).toEqual({ error: "bad_request" });
  });
});

describe("routing", () => {
  it("returns 404 for unknown paths and non-GET methods", async () => {
    expect((await get("/")).status).toBe(404);
    expect((await get("/v2/top")).status).toBe(404);
    expect((await get("/v1/top", "POST")).status).toBe(404);
  });

  it("is wired into the Worker fetch handler", async () => {
    const request = new Request("https://api.test/v1/top") as Request<unknown, IncomingRequestCfProperties>;
    const res = await worker.fetch(request, env);
    expect(res.status).toBe(503);
  });
});

describe("server detail", () => {
  beforeEach(async () => {
    await runCollector(db, TS * 1000, fakeFetch(makeRawResponse([{ id: "a", name: "TechMines", players: 40, maxPlayers: 300 }])));
    await runCollector(db, (TS + 900) * 1000, fakeFetch(makeRawResponse([{ id: "a", name: "TechMines", players: 55, maxPlayers: 300 }])));
  });

  it("returns info, current players, 24h points, and peak", async () => {
    const res = await get("/v1/server/a");
    expect(res.status).toBe(200);
    expect(res.headers.get("cache-control")).toBe("public, max-age=300");
    expect(await res.json()).toEqual({
      updatedAt: TS + 900,
      server: {
        id: "a",
        name: "TechMines",
        ip: "techmines.minehut.gg",
        players: 55,
        maxPlayers: 300,
        motd: "TechMines motd",
        categories: ["smp"],
        author: "someone",
        firstSeen: TS,
      },
      range: "24h",
      points: [
        [TS, 40],
        [TS + 900, 55],
      ],
      peak: { players: 55, ts: TS + 900 },
    });
  });

  it("buckets 7d by hour starting at first seen", async () => {
    const body = await (await get("/v1/server/a?range=7d")).json<{ points: [number, number][] }>();
    expect(body.points).toEqual([[HOUR_OF_TS, 55]]);
  });

  it("reports 0 players when the server is missing from the latest snapshot", async () => {
    await runCollector(db, (TS + 1800) * 1000, fakeFetch(makeRawResponse([{ id: "z", name: "Other", players: 5 }])));
    const body = await (await get("/v1/server/a")).json<{ server: { players: number } }>();
    expect(body.server.players).toBe(0);
  });

  it("returns 400 for a bad range and 404 for an unknown server", async () => {
    expect((await get("/v1/server/a?range=1y")).status).toBe(400);
    expect((await get("/v1/server/missing")).status).toBe(404);
  });
});

describe("collect endpoint", () => {
  const post = (secret?: string) =>
    handleRequest(
      new Request("https://api.test/v1/collect", {
        method: "POST",
        headers: secret === undefined ? {} : { authorization: `Bearer ${secret}` },
      }),
      env,
    );

  afterEach(() => vi.restoreAllMocks());

  it("rejects a missing or wrong secret without running the collector", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch");
    for (const res of [await post(), await post("wrong")]) {
      expect(res.status).toBe(401);
      expect(res.headers.get("cache-control")).toBe("no-store");
      expect(await res.json()).toEqual({ error: "unauthorized" });
    }
    expect(fetchSpy).not.toHaveBeenCalled();
    expect(await readSummary(db, "top")).toBeNull();
  });

  it("runs the collector with the right secret", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(fakeFetch(makeRawResponse([{ id: "a", name: "Alpha", players: 12 }])));
    const res = await post("test-collect-secret");
    expect(res.status).toBe(200);
    expect(res.headers.get("cache-control")).toBe("no-store");
    const body = await res.json<{ result: string; ts: number }>();
    expect(body.result).toBe("ok");
    expect(body.ts % 900).toBe(0);
    expect(JSON.parse((await readSummary(db, "top"))!).servers[0].id).toBe("a");
  });

  it("returns 502 when Minehut cannot be fetched", async () => {
    vi.spyOn(console, "error").mockImplementation(() => {});
    vi.spyOn(globalThis, "fetch").mockImplementation(fakeFetch({ message: "down" }, 500));
    const res = await post("test-collect-secret");
    expect(res.status).toBe(502);
    expect(await res.json()).toEqual({ error: "fetch_failed" });
  });

  it("rejects every key when no secret is configured", async () => {
    const request = new Request("https://api.test/v1/collect", { method: "POST", headers: { authorization: "Bearer " } });
    expect((await handleRequest(request, { DB: db })).status).toBe(401);
  });

  it("only accepts POST", async () => {
    expect((await get("/v1/collect")).status).toBe(404);
  });
});
