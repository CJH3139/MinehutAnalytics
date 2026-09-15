import { describe, expect, it } from "vitest";
import { MinehutParseError, parseServersResponse } from "../src/minehut";
import fixture from "./fixtures/minehut-servers.json";
import { makeRawResponse, makeRawServer } from "./helpers";

describe("parseServersResponse", () => {
  it("parses a well-formed server", () => {
    const raw = makeRawResponse([
      { id: "aaa", name: "TechMines", players: 239, maxPlayers: 300, motd: "<b>hi</b>", categories: ["box", "pvp"], author: "Zyptrik", icon: "END_CRYSTAL", plan: "EXTERNAL" },
    ]);
    expect(parseServersResponse(raw)).toEqual({
      servers: [
        {
          mhId: "aaa",
          name: "TechMines",
          players: 239,
          info: { motd: "<b>hi</b>", categories: ["box", "pvp"], maxPlayers: 300, author: "Zyptrik", icon: "END_CRYSTAL", plan: "EXTERNAL" },
        },
      ],
      totalPlayers: 239,
      totalServers: 1,
    });
  });

  it("maps missing or empty optional fields to null", () => {
    const raw = makeRawResponse([{ id: "a", name: "A", players: 1, maxPlayers: null, author: "", icon: null }]);
    const info = parseServersResponse(raw).servers[0].info;
    expect(info.maxPlayers).toBeNull();
    expect(info.author).toBeNull();
    expect(info.icon).toBeNull();
  });

  it("skips malformed entries and keeps the rest", () => {
    const good = makeRawServer({ id: "good", name: "Good", players: 3 });
    const noId = { ...makeRawServer({ id: "x", name: "NoId", players: 3 }), staticInfo: {} };
    const noPlayers = { ...makeRawServer({ id: "y", name: "NoPlayers", players: 3 }), playerData: {} };
    const raw = { servers: [noId, good, noPlayers, null], total_players: 9, total_servers: 3 };
    expect(parseServersResponse(raw).servers.map((s) => s.mhId)).toEqual(["good"]);
  });

  it("clamps player counts to non-negative integers", () => {
    const raw = makeRawResponse([{ id: "a", name: "A", players: -2 }, { id: "b", name: "B", players: 4.7 }]);
    expect(parseServersResponse(raw).servers.map((s) => s.players)).toEqual([0, 4]);
  });

  it("uses top-level totals when present", () => {
    const raw = makeRawResponse([{ id: "a", name: "A", players: 5 }], { players: 2400, servers: 950 });
    const parsed = parseServersResponse(raw);
    expect(parsed.totalPlayers).toBe(2400);
    expect(parsed.totalServers).toBe(950);
  });

  it("throws MinehutParseError when the shape is wrong", () => {
    expect(() => parseServersResponse(null)).toThrow(MinehutParseError);
    expect(() => parseServersResponse({ servers: "nope" })).toThrow(MinehutParseError);
  });

  it("parses the saved real Minehut response", () => {
    const parsed = parseServersResponse(fixture);
    expect(parsed.servers.length).toBeGreaterThan(100);
    expect(new Set(parsed.servers.map((s) => s.mhId)).size).toBe(parsed.servers.length);
    expect(parsed.totalPlayers).toBeGreaterThan(0);
  });
});
