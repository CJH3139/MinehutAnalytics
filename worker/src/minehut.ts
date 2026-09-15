import type { ParsedResponse, ParsedServer } from "./types";

export const MINEHUT_SERVERS_URL = "https://api.minehut.com/servers";

export class MinehutParseError extends Error {}

function isRecord(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

function nonEmptyString(v: unknown): string | null {
  return typeof v === "string" && v.length > 0 ? v : null;
}

function parseServer(item: unknown): ParsedServer | null {
  if (!isRecord(item) || !isRecord(item.staticInfo) || !isRecord(item.playerData)) return null;
  const mhId = item.staticInfo._id;
  const count = item.playerData.playerCount;
  if (typeof mhId !== "string" || typeof item.name !== "string" || typeof count !== "number") return null;
  return {
    mhId,
    name: item.name,
    players: Math.max(0, Math.floor(count)),
    info: {
      motd: typeof item.motd === "string" ? item.motd : "",
      categories: Array.isArray(item.allCategories)
        ? item.allCategories.filter((c): c is string => typeof c === "string")
        : [],
      maxPlayers: typeof item.maxPlayers === "number" ? item.maxPlayers : null,
      author: nonEmptyString(item.author),
      icon: nonEmptyString(item.icon),
      plan: nonEmptyString(item.staticInfo.rawPlan),
    },
  };
}

export function parseServersResponse(raw: unknown): ParsedResponse {
  if (!isRecord(raw)) throw new MinehutParseError("response is not an object");
  if (!Array.isArray(raw.servers)) throw new MinehutParseError("servers is not an array");
  const servers: ParsedServer[] = [];
  for (const item of raw.servers) {
    const parsed = parseServer(item);
    if (parsed) servers.push(parsed);
  }
  return {
    servers,
    totalPlayers: typeof raw.total_players === "number" ? raw.total_players : servers.reduce((n, s) => n + s.players, 0),
    totalServers: typeof raw.total_servers === "number" ? raw.total_servers : servers.length,
  };
}
