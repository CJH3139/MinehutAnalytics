import { TOLERANCE_SECONDS, type Blob, type ParsedServer, type ServerInfo } from "./types";

export interface ServerRow {
  id: number;
  mhId: string;
  name: string;
  info: ServerInfo;
  firstSeen: number;
}

export interface SampleRow {
  ts: number;
  players: number;
}

export type SummaryKey = "top" | "rising_1h" | "rising_6h" | "rising_24h" | "stats";

export async function upsertServers(db: D1Database, servers: ParsedServer[], ts: number): Promise<number> {
  if (servers.length === 0) return 0;
  const payload = JSON.stringify(servers.map((s) => ({ id: s.mhId, name: s.name, info: s.info })));
  const result = await db
    .prepare(
      `INSERT INTO servers (mh_id, name, info, first_seen)
       SELECT json_extract(value, '$.id'), json_extract(value, '$.name'), json_extract(value, '$.info'), ?2
       FROM json_each(?1) WHERE true
       ON CONFLICT(mh_id) DO UPDATE SET name = excluded.name, info = excluded.info
       WHERE servers.name IS NOT excluded.name OR servers.info IS NOT excluded.info`,
    )
    .bind(payload, ts)
    .run();
  return result.meta.changes;
}

export async function insertSamples(db: D1Database, servers: ParsedServer[], ts: number): Promise<void> {
  const active = servers.filter((s) => s.players >= 1);
  if (active.length === 0) return;
  const payload = JSON.stringify(active.map((s) => ({ id: s.mhId, p: s.players })));
  await db
    .prepare(
      `INSERT INTO samples (server_id, ts, players)
       SELECT s.id, ?2, json_extract(j.value, '$.p')
       FROM json_each(?1) AS j JOIN servers AS s ON s.mh_id = json_extract(j.value, '$.id') WHERE true
       ON CONFLICT(server_id, ts) DO UPDATE SET players = excluded.players`,
    )
    .bind(payload, ts)
    .run();
}

export async function insertBlob(db: D1Database, blob: Blob): Promise<void> {
  await db
    .prepare("INSERT INTO snapshot_blobs (ts, data) VALUES (?1, ?2) ON CONFLICT(ts) DO UPDATE SET data = excluded.data")
    .bind(blob.ts, JSON.stringify(blob.counts))
    .run();
}

export async function blobExists(db: D1Database, ts: number): Promise<boolean> {
  const row = await db.prepare("SELECT 1 AS found FROM snapshot_blobs WHERE ts = ?1").bind(ts).first<{ found: number }>();
  return row !== null;
}

export async function loadBlobsNear(db: D1Database, targets: number[]): Promise<Blob[]> {
  if (targets.length === 0) return [];
  const clauses = targets.map(() => "ts BETWEEN ? AND ?").join(" OR ");
  const params = targets.flatMap((t) => [t - TOLERANCE_SECONDS, t + TOLERANCE_SECONDS]);
  const { results } = await db
    .prepare(`SELECT ts, data FROM snapshot_blobs WHERE ${clauses}`)
    .bind(...params)
    .all<{ ts: number; data: string }>();
  return results.map((r) => ({ ts: r.ts, counts: JSON.parse(r.data) as Record<string, number> }));
}

export async function oldestBlobTs(db: D1Database): Promise<number | null> {
  return (await db.prepare("SELECT MIN(ts) AS ts FROM snapshot_blobs").first<{ ts: number | null }>())?.ts ?? null;
}

export async function latestBlobTs(db: D1Database): Promise<number | null> {
  return (await db.prepare("SELECT MAX(ts) AS ts FROM snapshot_blobs").first<{ ts: number | null }>())?.ts ?? null;
}

export async function blobTimesSince(db: D1Database, sinceExclusive: number): Promise<number[]> {
  const { results } = await db
    .prepare("SELECT ts FROM snapshot_blobs WHERE ts > ?1 ORDER BY ts")
    .bind(sinceExclusive)
    .all<{ ts: number }>();
  return results.map((r) => r.ts);
}

export async function writeSummaries(
  db: D1Database,
  ts: number,
  entries: { key: SummaryKey; data: unknown }[],
): Promise<void> {
  if (entries.length === 0) return;
  const statement = db.prepare(
    `INSERT INTO summaries (key, data, updated_at) VALUES (?1, ?2, ?3)
     ON CONFLICT(key) DO UPDATE SET data = excluded.data, updated_at = excluded.updated_at`,
  );
  await db.batch(entries.map((e) => statement.bind(e.key, JSON.stringify(e.data), ts)));
}

export async function readSummary(db: D1Database, key: SummaryKey): Promise<string | null> {
  return (await db.prepare("SELECT data FROM summaries WHERE key = ?1").bind(key).first<{ data: string }>())?.data ?? null;
}

export async function pruneBlobs(db: D1Database, before: number): Promise<void> {
  await db.prepare("DELETE FROM snapshot_blobs WHERE ts < ?1").bind(before).run();
}

export async function pruneSamples(db: D1Database, before: number): Promise<void> {
  await db.prepare("DELETE FROM samples WHERE ts < ?1").bind(before).run();
}

export async function getServer(db: D1Database, mhId: string): Promise<ServerRow | null> {
  const row = await db
    .prepare("SELECT id, mh_id, name, info, first_seen FROM servers WHERE mh_id = ?1")
    .bind(mhId)
    .first<{ id: number; mh_id: string; name: string; info: string; first_seen: number }>();
  if (!row) return null;
  return { id: row.id, mhId: row.mh_id, name: row.name, info: JSON.parse(row.info) as ServerInfo, firstSeen: row.first_seen };
}

export async function samplesSince(db: D1Database, serverId: number, sinceExclusive: number): Promise<SampleRow[]> {
  const { results } = await db
    .prepare("SELECT ts, players FROM samples WHERE server_id = ?1 AND ts > ?2 ORDER BY ts")
    .bind(serverId, sinceExclusive)
    .all<SampleRow>();
  return results;
}
