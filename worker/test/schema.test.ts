import { env } from "cloudflare:workers";
import { beforeEach, expect, it } from "vitest";
import { resetDb } from "./helpers";

beforeEach(() => resetDb(env.DB));

it("creates all four tables", async () => {
  const { results } = await env.DB.prepare(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('servers','samples','snapshot_blobs','summaries') ORDER BY name",
  ).all<{ name: string }>();
  expect(results.map((r) => r.name)).toEqual(["samples", "servers", "snapshot_blobs", "summaries"]);
});

it("rejects duplicate mh_id in servers", async () => {
  const insert = "INSERT INTO servers (mh_id, name, info, first_seen) VALUES ('a', 'A', '{}', 0)";
  await env.DB.prepare(insert).run();
  await expect(env.DB.prepare(insert).run()).rejects.toThrow();
});
