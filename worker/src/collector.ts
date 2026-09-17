import { recordNetwork } from "./overview";
import {
  blobExists,
  insertBlob,
  insertSamples,
  loadBlobsNear,
  oldestBlobTs,
  pruneBlobs,
  pruneSamples,
  samplesForServers,
  upsertServers,
  writeSummaries,
  type SummaryKey,
} from "./db";
import { MINEHUT_SERVERS_URL, parseServersResponse } from "./minehut";
import { computeTopSeries } from "./series";
import { blobCounts, computeRising, computeStats, computeTop, pickBlob } from "./summaries";
import {
  BLOB_RETENTION_SECONDS,
  SAMPLE_RETENTION_SECONDS,
  SERIES_LIMIT,
  SERIES_SECONDS,
  SNAPSHOT_SECONDS,
  WINDOWS,
  WINDOW_SECONDS,
  type ParsedResponse,
} from "./types";

export type CollectorResult = "ok" | "skipped" | "fetch_failed";

const USER_AGENT = "MinehutAnalytics/1.0 (+https://github.com/CJH3139/MinehutAnalytics)";

export function snapshotTs(scheduledTimeMs: number): number {
  return Math.floor(scheduledTimeMs / 1000 / SNAPSHOT_SECONDS) * SNAPSHOT_SECONDS;
}

async function fetchMinehut(fetchFn: typeof fetch): Promise<ParsedResponse | null> {
  try {
    const res = await fetchFn(MINEHUT_SERVERS_URL, {
      headers: { "User-Agent": USER_AGENT, Accept: "application/json" },
    });
    if (!res.ok) {
      console.error(`minehut fetch failed: HTTP ${res.status}`);
      return null;
    }
    return parseServersResponse(await res.json());
  } catch (err) {
    console.error("minehut fetch failed:", err);
    return null;
  }
}

export async function runCollector(
  db: D1Database,
  scheduledTimeMs: number,
  fetchFn: typeof fetch = fetch,
): Promise<CollectorResult> {
  const ts = snapshotTs(scheduledTimeMs);
  if (await blobExists(db, ts)) return "skipped";
  const parsed = await fetchMinehut(fetchFn);
  if (!parsed) return "fetch_failed";

  await upsertServers(db, parsed.servers, ts);
  await insertSamples(db, parsed.servers, ts);
  await recordNetwork(db, parsed, ts);
  await insertBlob(db, { ts, counts: blobCounts(parsed.servers) });

  const blobs = await loadBlobsNear(db, WINDOWS.map((w) => ts - WINDOW_SECONDS[w]));
  const oldest = await oldestBlobTs(db);
  const topBody = computeTop(parsed.servers, ts, pickBlob(blobs, ts - WINDOW_SECONDS["24h"]));
  const seriesSamples = await samplesForServers(
    db,
    topBody.servers.slice(0, SERIES_LIMIT).map((s) => s.id),
    ts - SERIES_SECONDS,
  );
  const entries: { key: SummaryKey; data: unknown }[] = [
    { key: "top", data: topBody },
    { key: "top_series", data: computeTopSeries(topBody.servers, seriesSamples, ts, SERIES_LIMIT) },
    { key: "stats", data: computeStats(parsed, ts) },
    ...WINDOWS.map((w) => ({
      key: `rising_${w}` as SummaryKey,
      data: computeRising(parsed.servers, ts, w, pickBlob(blobs, ts - WINDOW_SECONDS[w]), oldest),
    })),
  ];
  await writeSummaries(db, ts, entries);

  await pruneBlobs(db, ts - BLOB_RETENTION_SECONDS);
  if (ts % 86400 === 0) await pruneSamples(db, ts - SAMPLE_RETENTION_SECONDS);
  return "ok";
}
