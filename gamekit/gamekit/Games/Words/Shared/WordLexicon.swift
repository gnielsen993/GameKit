import Foundation

nonisolated enum WordLexicon {
    static let fiveLetterAnswers = [
        "APPLE", "BRAIN", "BRAVE", "CHAIR", "CHARM", "CLOUD", "CRANE", "DELTA",
        "DREAM", "EARTH", "FIELD", "FLAME", "GRACE", "GRAPE", "HEART", "IVORY",
        "JOLLY", "LIGHT", "MUSIC", "PLANT", "PRIDE", "RIVER", "ROAST", "SHARE",
        "SLATE", "SMILE", "STONE", "TRACE", "TRAIN", "WATER", "WORLD", "QUIET",
        "PIANO", "BEACH", "BREAD", "ACORN", "ALERT", "ADORE", "LEARN", "TRAIL"
    ]

    static let fiveLetterGuesses = Set([
        "ABOUT", "ABOVE", "ACORN", "ADORE", "ALERT", "APPLE", "BEACH", "BRAIN",
        "BRAVE", "BREAD", "CHAIR", "CHARM", "CLOUD", "CRANE", "DELTA", "DREAM",
        "EARTH", "FIELD", "FLAME", "GRACE", "GRAPE", "HEART", "IVORY", "JOLLY",
        "LEARN", "LIGHT", "MUSIC", "OTHER", "PIANO", "PLANT", "PRIDE", "QUIET",
        "RIVER", "ROAST", "SHARE", "SLATE", "SMILE", "STONE", "THERE", "TRACE",
        "TRAIN", "TRAIL", "WATER", "WHICH", "WORLD", "YEARN", "GREEN", "GREAT",
        "SOUND", "ROUND", "BRING", "THING", "PLACE", "SPACE", "HOUSE", "MOUSE"
    ] + fiveLetterAnswers)

    static let wordGridWords = Set([
        "ABLE", "ABOUT", "ACE", "ACED", "ACRE", "ACT", "ADD", "AID", "AIM",
        "AIR", "AND", "ANT", "ARC", "ARE", "ARM", "ART", "ASH", "ASK", "ATE",
        "BAD", "BAG", "BAR", "BARD", "BARE", "BAT", "BEAD", "BEAM", "BEAR",
        "BED", "BEE", "BEND", "BENT", "BET", "BIRD", "BITE", "BOAT", "BOATS",
        "BOLD", "BOOK", "BOOKS", "BOOT", "BORE", "BORN", "BRAID", "BRAIN",
        "BRAVE", "BREAD", "CARD", "CARDS", "CARE", "CART", "CAT", "CODE",
        "CODER", "COLD", "CONE", "CORE", "CORN", "DATE", "DEAR", "DEER",
        "DENT", "DICE", "DIME", "DINE", "DIRE", "DIRT", "DISH", "DIVE",
        "DONE", "DOOR", "DREAM", "EARN", "EAST", "EAT", "EEL", "EAR",
        "FAR", "FARE", "FARM", "FEAR", "FEED", "FEEL", "FIELD", "FIND",
        "FINDS", "FINE", "FIRE", "FIRM", "FISH", "FOAM", "FOOD", "FOOT",
        "FORD", "FORM", "GAME", "GAMES", "GEAR", "GOLD", "GOLDS", "GRID",
        "GRIDS", "HARD", "HARE", "HARM", "HEAR", "HEARD", "HEART", "HEAT",
        "HIDE", "HOME", "HOMES", "IDEA", "IRON", "LAND", "LANE", "LATE",
        "LEAD", "LEAF", "LEAN", "LEARN", "LEND", "LENT", "LIME", "LINE",
        "LINES", "LINK", "LION", "LOAD", "LOAN", "MADE", "MAKE", "MAKES",
        "MAN", "MANY", "MARM", "MART", "MEAL", "MEAN", "MEAT", "MEND",
        "MILE", "MILES", "MIME", "MIND", "MINE", "MINT", "MOON", "MOONS",
        "MORN", "MUSIC", "NEAR", "NEAT", "NEED", "NERD", "NEST", "NODE",
        "NOTE", "NOTES", "PAGE", "PAGES", "PAID", "PAIR", "PART", "PATH",
        "PATHS", "PINE", "PLAN", "PLANE", "PLANT", "PLAY", "PLAYS", "RACE",
        "RAGE", "RAIN", "RAINS", "RAT", "RATE", "READ", "RED", "REED",
        "RIDE", "RING", "RINGS", "RISE", "RIVER", "ROAD", "ROADS", "ROAM",
        "RODE", "SAND", "SANDS", "SEAL", "SEAM", "SEAT", "SEED", "SEEDS",
        "SEND", "SHARE", "SHARED", "SIDE", "SINE", "SING", "SIRE", "SITE",
        "SLATE", "SMILE", "SMILES", "SONG", "SONGS", "STAR", "START",
        "STONE", "TAKE", "TAKES", "TAME", "TAR", "TEAM", "TEAR", "TEND",
        "TENT", "TIDE", "TIME", "TIMES", "TIRE", "TOAD", "TOE", "TONE",
        "TRACE", "TRAIN", "TRAIL", "TRAILS", "TREE", "TREES", "TRIM",
        "WIND", "WINDS", "WINE", "WIRE", "WORD", "WORDS", "WORLD",
        "ACE", "ACED", "ARC", "ART", "BAR", "BARD", "BAT", "BRAID", "CAR",
        "CARD", "CARDS", "CART", "CLOUD", "CODE", "CODER", "DART", "DATA",
        "DRAG", "DREAM", "EAR", "EARN", "FAR", "FARM", "FIELD", "FIRE",
        "GAME", "GAMES", "GEAR", "GRID", "GRIDS", "HARD", "HEART", "IDEA",
        "IRON", "LAND", "LIGHT", "LINE", "LINES", "MILE", "MILES", "MIND",
        "MUSIC", "NODE", "NOTE", "NOTES", "PART", "PLANT", "RAT", "READ",
        "RIVER", "ROAD", "ROADS", "STAR", "START", "STONE", "TAR", "TEAM",
        "TEAR", "TRACE", "TRAIN", "WORD", "WORDS", "TRAIL", "TRAILS", "WATER",
        "WORLD", "LEARN", "LEARNS", "SHARE", "SHARED", "SMILE", "SMILES",
        "PLAY", "PLAYS", "RING", "RINGS", "SAND", "SANDS", "WIND", "WINDS",
        "TREE", "TREES", "MOON", "MOONS", "BOAT", "BOATS", "HOME", "HOMES",
        "PATH", "PATHS", "BOOK", "BOOKS", "PAGE", "PAGES", "SONG", "SONGS",
        "TIME", "TIMES", "RAIN", "RAINS", "SEED", "SEEDS", "FIND", "FINDS",
        "MAKE", "MAKES", "TAKE", "TAKES", "GOLD", "GOLDS", "BLUE", "BLUES"
    ])

    static let wordGridPrefixes: Set<String> = {
        var prefixes = Set<String>()
        for word in wordGridWords {
            let letters = Array(word)
            guard letters.count >= 3 else { continue }
            for length in 1...letters.count {
                prefixes.insert(String(letters.prefix(length)))
            }
        }
        return prefixes
    }()

    static let maxWordGridWordLength = wordGridWords.map(\.count).max() ?? 8

    static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .init(identifier: "en_US"))
            .uppercased()
            .filter { $0 >= "A" && $0 <= "Z" }
    }

    static func isAllowedFiveLetterGuess(_ word: String) -> Bool {
        let normalized = normalize(word)
        return normalized.count == 5
    }

    static func isValidGridWord(_ word: String) -> Bool {
        let normalized = normalize(word)
        return normalized.count >= 3 && wordGridWords.contains(normalized)
    }

}
