import Foundation

enum Fixtures {
    static func data(_ json: String) -> Data { Data(json.utf8) }

    static let top = """
    {"updatedAt":1789000200,"servers":[
      {"id":"aaa","name":"TechMines","players":239,"maxPlayers":300,"change24h":45},
      {"id":"bbb","name":"MineRefine","players":118,"maxPlayers":null,"change24h":null}
    ]}
    """

    static let rising = """
    {"updatedAt":1789000200,"window":"1h","ready":true,"readyAt":null,"comparedTo":1788996600,"servers":[
      {"id":"bbb","name":"MineRefine","players":118,"then":40,"gain":78,"pct":195.0},
      {"id":"ccc","name":"FreshSMP","players":12,"then":0,"gain":12,"pct":null}
    ]}
    """

    static let risingNotReady = """
    {"updatedAt":1789000200,"window":"24h","ready":false,"readyAt":1789086600,"comparedTo":null,"servers":[]}
    """

    static let stats = """
    {"updatedAt":1789000200,"totalPlayers":2352,"totalServers":972}
    """

    static let topSeries = """
    {"updatedAt":1789000200,"servers":[
      {"id":"aaa","name":"TechMines","players":239,"maxPlayers":300,"change24h":45,
       "points":[[1788999300,230],[1789000200,239]]},
      {"id":"bbb","name":"MineRefine","players":118,"maxPlayers":null,"change24h":null,"points":[]}
    ]}
    """

    static let server = """
    {"updatedAt":1789000200,
     "server":{"id":"aaa","name":"TechMines","ip":"techmines.minehut.gg","players":239,"maxPlayers":null,
               "motd":"<b>TECHMINES</b>","categories":["box","pvp"],"author":null,"firstSeen":1788000000},
     "range":"24h","points":[[1788999300,230],[1789000200,239]],"peak":{"players":239,"ts":1789000200}}
    """
}
