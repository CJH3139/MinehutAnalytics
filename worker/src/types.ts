export interface ServerInfo {
  motd: string;
  categories: string[];
  maxPlayers: number | null;
  author: string | null;
  icon: string | null;
  plan: string | null;
}

export interface ParsedServer {
  mhId: string;
  name: string;
  players: number;
  info: ServerInfo;
}

export interface ParsedResponse {
  servers: ParsedServer[];
  totalPlayers: number;
  totalServers: number;
}

export interface Blob {
  ts: number;
  counts: Record<string, number>;
}

export type Window = "1h" | "6h" | "24h";
export const WINDOWS: Window[] = ["1h", "6h", "24h"];
export const WINDOW_SECONDS: Record<Window, number> = { "1h": 3600, "6h": 21600, "24h": 86400 };

export type Range = "24h" | "7d" | "30d";
export const RANGE_SECONDS: Record<Range, number> = { "24h": 86400, "7d": 604800, "30d": 2592000 };

export const SNAPSHOT_SECONDS = 900;
export const TOLERANCE_SECONDS = 1200;
export const MIN_RISING_PLAYERS = 5;
export const LIST_LIMIT = 50;
export const BLOB_RETENTION_SECONDS = 90000;
export const SAMPLE_RETENTION_SECONDS = 2592000;
