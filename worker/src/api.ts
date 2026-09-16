import { runCollector, snapshotTs } from "./collector";
import { blobTimesSince, getServer, latestBlobTs, readSummary, samplesSince, type SummaryKey } from "./db";
import { buildPoints, peakOf } from "./series";
import { RANGE_SECONDS, WINDOWS, type Range, type Window } from "./types";

export interface ApiEnv {
  DB: D1Database;
  COLLECT_SECRET?: string;
}

const RANGES: Range[] = ["24h", "7d", "30d"];

function respond(bodyText: string, status: number, cacheable = status === 200): Response {
  return new Response(bodyText, {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": cacheable ? "public, max-age=300" : "no-store",
    },
  });
}

const ok = (body: unknown) => respond(JSON.stringify(body), 200);
const notFound = () => respond('{"error":"not_found"}', 404);
const badRequest = () => respond('{"error":"bad_request"}', 400);
const noData = () => respond('{"error":"no_data"}', 503);
const unauthorized = () => respond('{"error":"unauthorized"}', 401);

async function summary(db: D1Database, key: SummaryKey): Promise<Response> {
  const data = await readSummary(db, key);
  return data === null ? noData() : respond(data, 200);
}

async function serverDetail(db: D1Database, mhId: string, rangeParam: string): Promise<Response> {
  if (!(RANGES as string[]).includes(rangeParam)) return badRequest();
  const range = rangeParam as Range;
  const server = await getServer(db, mhId);
  if (!server) return notFound();
  const latest = await latestBlobTs(db);
  if (latest === null) return noData();

  const since = latest - RANGE_SECONDS[range];
  const samples = await samplesSince(db, server.id, since);
  const blobTimes = range === "24h" ? await blobTimesSince(db, since) : [];
  const points = buildPoints(range, latest, samples, blobTimes, server.firstSeen);

  return ok({
    updatedAt: latest,
    server: {
      id: server.mhId,
      name: server.name,
      ip: `${server.name.toLowerCase()}.minehut.gg`,
      players: samples.find((s) => s.ts === latest)?.players ?? 0,
      maxPlayers: server.info.maxPlayers,
      motd: server.info.motd,
      categories: server.info.categories,
      author: server.info.author,
      firstSeen: server.firstSeen,
    },
    range,
    points,
    peak: peakOf(points),
  });
}

function hasCollectSecret(request: Request, secret: string | undefined): boolean {
  if (!secret) return false;
  const header = request.headers.get("authorization") ?? "";
  const expected = `Bearer ${secret}`;
  if (header.length !== expected.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) diff |= header.charCodeAt(i) ^ expected.charCodeAt(i);
  return diff === 0;
}

async function collect(request: Request, env: ApiEnv): Promise<Response> {
  if (!hasCollectSecret(request, env.COLLECT_SECRET)) return unauthorized();
  const now = Date.now();
  const result = await runCollector(env.DB, now);
  if (result === "fetch_failed") return respond('{"error":"fetch_failed"}', 502);
  return respond(JSON.stringify({ result, ts: snapshotTs(now) }), 200, false);
}

export async function handleRequest(request: Request, env: ApiEnv): Promise<Response> {
  const url = new URL(request.url);
  const path = url.pathname.replace(/\/+$/, "");

  if (path === "/v1/collect") return request.method === "POST" ? collect(request, env) : notFound();
  if (request.method !== "GET") return notFound();

  if (path === "/v1/top") return summary(env.DB, "top");
  if (path === "/v1/top/series") return summary(env.DB, "top_series");
  if (path === "/v1/stats") return summary(env.DB, "stats");
  if (path === "/v1/rising") {
    const window = url.searchParams.get("window") ?? "24h";
    if (!(WINDOWS as string[]).includes(window)) return badRequest();
    return summary(env.DB, `rising_${window as Window}`);
  }
  const match = /^\/v1\/server\/([^/]+)$/.exec(path);
  if (match) return serverDetail(env.DB, decodeURIComponent(match[1]), url.searchParams.get("range") ?? "24h");
  return notFound();
}
