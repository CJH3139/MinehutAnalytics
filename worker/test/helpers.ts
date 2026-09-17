import type { ParsedServer } from "../src/types";

export async function resetDb(db: D1Database): Promise<void> {
  await db.batch([
    db.prepare("DELETE FROM network_samples"),
    db.prepare("DELETE FROM samples"),
    db.prepare("DELETE FROM snapshot_blobs"),
    db.prepare("DELETE FROM summaries"),
    db.prepare("DELETE FROM servers"),
  ]);
}

export interface RawServerOptions {
  id: string;
  name: string;
  players: number;
  maxPlayers?: number | null;
  motd?: string;
  categories?: string[];
  author?: string | null;
  icon?: string | null;
  plan?: string;
}

export function makeRawServer(o: RawServerOptions): Record<string, unknown> {
  return {
    staticInfo: { _id: o.id, rawPlan: o.plan ?? "FREE", platform: "java" },
    maxPlayers: o.maxPlayers === undefined ? 20 : o.maxPlayers,
    name: o.name,
    motd: o.motd ?? `${o.name} motd`,
    icon: o.icon === undefined ? "GRASS_BLOCK" : o.icon,
    playerData: { timeNoPlayers: 0, playerCount: o.players },
    connectable: true,
    visibility: true,
    allCategories: o.categories ?? ["smp"],
    author: o.author === undefined ? "someone" : o.author,
  };
}

export function makeRawResponse(
  servers: RawServerOptions[],
  totals?: { players?: number; servers?: number },
): Record<string, unknown> {
  return {
    servers: servers.map(makeRawServer),
    total_players: totals?.players ?? servers.reduce((n, s) => n + s.players, 0),
    total_servers: totals?.servers ?? servers.length,
    total_search_results: servers.length,
  };
}

export function makeParsed(id: string, name: string, players: number, maxPlayers: number | null = 20): ParsedServer {
  return {
    mhId: id,
    name,
    players,
    info: { motd: "", categories: [], maxPlayers, author: null, icon: null, plan: null },
  };
}

export function fakeFetch(body: unknown, status = 200): typeof fetch {
  return (async () =>
    new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } })) as unknown as typeof fetch;
}
