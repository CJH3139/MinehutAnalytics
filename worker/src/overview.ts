import { RANGE_SECONDS, SAMPLE_RETENTION_SECONDS, TOLERANCE_SECONDS, type ParsedResponse, type Range } from "./types";

interface Category { name: string; players: number; servers: number }
interface NetworkRow {
  ts: number; players: number; servers: number;
  listedPlayers: number; activeServers: number;
  top10Share: number | null; categories: string;
}
const COLUMNS = "ts, players, servers, listed_players AS listedPlayers, active_servers AS activeServers, top10_share AS top10Share, categories";

export async function recordNetwork(db: D1Database, parsed: ParsedResponse, ts: number): Promise<void> {
  const listedPlayers = parsed.servers.reduce((sum, server) => sum + server.players, 0);
  const topPlayers = parsed.servers.map(s => s.players).sort((a, b) => b - a).slice(0, 10).reduce((a, b) => a + b, 0);
  const categories = new Map<string, Category>();
  for (const server of parsed.servers) {
    // Assign each listed server once: first nonempty upstream category.
    const name = server.info.categories.map(c => c.trim()).find(Boolean) ?? "Uncategorized";
    const category = categories.get(name) ?? { name, players: 0, servers: 0 };
    category.players += server.players;
    category.servers += 1;
    categories.set(name, category);
  }
  await db.batch([
    db.prepare(`INSERT INTO network_samples (ts, players, servers, listed_players, active_servers, top10_share, categories)
      VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
      ON CONFLICT(ts) DO UPDATE SET players=excluded.players, servers=excluded.servers,
      listed_players=excluded.listed_players, active_servers=excluded.active_servers,
      top10_share=excluded.top10_share, categories=excluded.categories`)
      .bind(ts, parsed.totalPlayers, parsed.totalServers, listedPlayers,
        parsed.servers.filter(s => s.players > 0).length,
        listedPlayers > 0 ? topPlayers / listedPlayers * 100 : null,
        JSON.stringify([...categories.values()].sort((a, b) => b.players - a.players || a.name.localeCompare(b.name)))),
    db.prepare("DELETE FROM network_samples WHERE ts < ?1").bind(ts - SAMPLE_RETENTION_SECONDS),
  ]);
}

export async function readOverview(db: D1Database, range: Range) {
  const latest = await db.prepare(`SELECT ${COLUMNS} FROM network_samples ORDER BY ts DESC LIMIT 1`).first<NetworkRow>();
  if (!latest) return null;
  const target = latest.ts - 86400;
  const baseline = await db.prepare(`SELECT players, servers FROM network_samples
    WHERE ts BETWEEN ?1 AND ?2 ORDER BY ABS(ts - ?3), ts LIMIT 1`)
    .bind(target - TOLERANCE_SECONDS, target + TOLERANCE_SECONDS, target).first<{players: number; servers: number}>();
  const { results: points } = await db.prepare(`SELECT ts, players, servers FROM network_samples
    WHERE ts BETWEEN ?1 AND ?2 ORDER BY ts LIMIT 2881`)
    .bind(latest.ts - RANGE_SECONDS[range], latest.ts).all<{ts: number; players: number; servers: number}>();
  return {
    updatedAt: latest.ts, totalPlayers: latest.players, totalServers: latest.servers,
    listedPlayers: latest.listedPlayers, activeServers: latest.activeServers,
    playersChange24h: baseline ? latest.players - baseline.players : null,
    serverChange24h: baseline ? latest.servers - baseline.servers : null,
    top10Share: latest.top10Share, points, categories: JSON.parse(latest.categories) as Category[],
  };
}
