CREATE TABLE network_samples (
  ts INTEGER PRIMARY KEY,
  players INTEGER NOT NULL CHECK (players >= 0),
  servers INTEGER NOT NULL CHECK (servers >= 0),
  listed_players INTEGER NOT NULL CHECK (listed_players >= 0),
  active_servers INTEGER NOT NULL CHECK (active_servers >= 0),
  top10_share REAL,
  categories TEXT NOT NULL
);
