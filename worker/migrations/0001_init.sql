CREATE TABLE servers (
  id         INTEGER PRIMARY KEY,
  mh_id      TEXT NOT NULL UNIQUE,
  name       TEXT NOT NULL,
  info       TEXT NOT NULL,
  first_seen INTEGER NOT NULL
);
CREATE INDEX servers_name ON servers(name);

CREATE TABLE samples (
  server_id INTEGER NOT NULL,
  ts        INTEGER NOT NULL,
  players   INTEGER NOT NULL,
  PRIMARY KEY (server_id, ts)
) WITHOUT ROWID;

CREATE TABLE snapshot_blobs (
  ts   INTEGER PRIMARY KEY,
  data TEXT NOT NULL
);

CREATE TABLE summaries (
  key        TEXT PRIMARY KEY,
  data       TEXT NOT NULL,
  updated_at INTEGER NOT NULL
);
