import Foundation

nonisolated enum WordLexicon {
    static let fiveLetterAnswers = [
        "APPLE", "BRAIN", "BRAVE", "CHAIR", "CHARM", "CLOUD", "CRANE", "DELTA",
        "DREAM", "EARTH", "FIELD", "FLAME", "GRACE", "GRAPE", "HEART", "IVORY",
        "JOLLY", "LIGHT", "MUSIC", "PLANT", "PRIDE", "RIVER", "ROAST", "SHARE",
        "SLATE", "SMILE", "STONE", "TRACE", "TRAIN", "WATER", "WORLD", "QUIET",
        "PIANO", "BEACH", "BREAD", "ACORN", "ALERT", "ADORE", "LEARN", "TRAIL"
    ]

    /// Accepted-guess dictionary. Loaded from the bundled
    /// `five-letter-guesses.txt` resource (public-domain word list, see
    /// `Resources/Words/PROVENANCE.md`) and unioned with the curated
    /// answers + the built-in fallback so it is always a superset of both.
    /// If the resource is missing (e.g. an unexpected bundling failure)
    /// the built-in list keeps guessing functional.
    static let fiveLetterGuesses: Set<String> = {
        var words = builtinFiveLetterGuesses
        if let url = Bundle.main.url(forResource: "five-letter-guesses", withExtension: "txt"),
           let contents = try? String(contentsOf: url, encoding: .utf8) {
            for line in contents.split(whereSeparator: \.isNewline) {
                let word = normalize(String(line))
                if word.count == 5 { words.insert(word) }
            }
        }
        return words
    }()

    /// Curated built-in fallback — superseded by the bundled resource above
    /// when present, but retained so guessing never breaks if the resource
    /// fails to load.
    private static let builtinFiveLetterGuesses = Set([
        "ABOUT", "ABOVE", "ACORN", "ADORE", "ALERT", "APPLE", "BEACH", "BRAIN",
        "BRAVE", "BREAD", "CHAIR", "CHARM", "CLOUD", "CRANE", "DELTA", "DREAM",
        "EARTH", "FIELD", "FLAME", "GRACE", "GRAPE", "HEART", "IVORY", "JOLLY",
        "LEARN", "LIGHT", "MUSIC", "OTHER", "PIANO", "PLANT", "PRIDE", "QUIET",
        "RIVER", "ROAST", "SHARE", "SLATE", "SMILE", "STONE", "THERE", "TRACE",
        "TRAIN", "TRAIL", "WATER", "WHICH", "WORLD", "YEARN", "GREEN", "GREAT",
        "SOUND", "ROUND", "BRING", "THING", "PLACE", "SPACE", "HOUSE", "MOUSE",
        "ABIDE", "ADIEU", "AGENT", "ALONE", "ANGEL", "ANGER", "ARGUE", "ARISE",
        "ARROW", "AUDIO", "AWARE", "BADGE", "BASIC", "BEGIN", "BLACK", "BLAME",
        "BLAST", "BLEND", "BLIND", "BLOCK", "BLOOM", "BOARD", "BOOST", "BOUND",
        "BRAND", "BREAK", "BRICK", "BRIEF", "BROAD", "BROKE", "BROWN", "BRUSH",
        "BUILD", "BUNCH", "BURST", "CABLE", "CAMEL", "CANDY", "CATCH", "CAUSE",
        "CHASE", "CHEAP", "CHECK", "CHESS", "CHEST", "CHIEF", "CHILD", "CHILL",
        "CIVIL", "CLAIM", "CLASS", "CLEAN", "CLEAR", "CLICK", "CLIMB", "CLOCK",
        "CLOSE", "COAST", "COUNT", "COURT", "COVER", "CRACK", "CRAFT", "CRASH",
        "CRAZY", "CREAM", "CRISP", "CROSS", "CROWD", "CROWN", "CURVE", "DAILY",
        "DANCE", "DEATH", "DEPTH", "DOUBT", "DOZEN", "DRAFT", "DRANK", "DRESS",
        "DRIED", "DRINK", "DRIVE", "DROVE", "EAGER", "EAGLE", "EARLY", "EIGHT",
        "ELITE", "EMPTY", "ENJOY", "ENTER", "EQUAL", "ERROR", "EVENT", "EVERY",
        "EXACT", "EXIST", "EXTRA", "FAITH", "FALSE", "FANCY", "FAULT", "FAVOR",
        "FEAST", "FENCE", "FEVER", "FINAL", "FIRST", "FLASH", "FLEET", "FLOAT",
        "FLOOD", "FLOOR", "FLOUR", "FLUID", "FOCUS", "FORCE", "FORGE", "FORTH",
        "FRAME", "FRANK", "FRAUD", "FRESH", "FRONT", "FROST", "FROWN", "FRUIT",
        "FULLY", "FUNNY", "GHOST", "GIANT", "GLASS", "GLEAM", "GLOBE", "GLORY",
        "GLOVE", "GRAIN", "GRAND", "GRANT", "GRASP", "GRASS", "GRIEF", "GRIND",
        "GROUP", "GROWN", "GUARD", "GUESS", "GUEST", "GUIDE", "HABIT", "HANDY",
        "HAPPY", "HARSH", "HASTE", "HATCH", "HEAVY", "HENCE", "HOBBY", "HONEY",
        "HONOR", "HORSE", "HOTEL", "HUMAN", "HUMOR", "IDEAL", "IMAGE", "INDEX",
        "INNER", "INPUT", "ISSUE", "JOINT", "JUDGE", "JUICE", "KNIFE", "KNOCK",
        "KNOWN", "LABEL", "LABOR", "LARGE", "LASER", "LATER", "LAUGH", "LAYER",
        "LEAST", "LEAVE", "LEGAL", "LEMON", "LEVEL", "LEVER", "LOCAL", "LODGE",
        "LOGIC", "LOOSE", "LOVER", "LOWER", "LOYAL", "LUCKY", "LUNAR", "LUNCH",
        "MAGIC", "MAJOR", "MAKER", "MARCH", "MATCH", "MAYOR", "MEDAL", "MEDIA",
        "MERCY", "MERIT", "METAL", "METER", "MIGHT", "MINOR", "MODEL", "MONEY",
        "MONTH", "MORAL", "MOTOR", "MOUNT", "MOVIE", "NAMED", "NERVE", "NEVER",
        "NIGHT", "NOBLE", "NOISE", "NORTH", "NOTED", "NOVEL", "NURSE", "OCEAN",
        "OFFER", "OFTEN", "OLIVE", "ONION", "ORDER", "ORGAN", "OWNER", "PAINT",
        "PANEL", "PAPER", "PARTY", "PASTE", "PATCH", "PAUSE", "PEACE", "PEARL",
        "PHASE", "PHONE", "PHOTO", "PIECE", "PILOT", "PITCH", "PIXEL", "PLAIN",
        "PLATE", "PLUMP", "POINT", "POLAR", "PORCH", "POUND", "POWER", "PRESS",
        "PRICE", "PRINT", "PRIOR", "PRIZE", "PROOF", "PROUD", "PROVE", "PULSE",
        "PUPIL", "PURSE", "QUEEN", "QUICK", "QUITE", "QUOTE", "RADIO", "RAISE",
        "RALLY", "RANCH", "RANGE", "RAPID", "REACH", "REACT", "READY", "REALM",
        "REBEL", "REIGN", "RELAX", "REPLY", "RHYME", "RIDGE", "RIGHT", "RIVAL",
        "ROBOT", "ROCKY", "ROUGH", "ROUTE", "ROYAL", "RURAL", "SADLY", "SAINT",
        "SALAD", "SAUCE", "SCALE", "SCARE", "SCENE", "SCOPE", "SCORE", "SCOUT",
        "SCRAP", "SENSE", "SERVE", "SEVEN", "SHADE", "SHAKE", "SHALL", "SHAME",
        "SHAPE", "SHARP", "SHEEP", "SHEET", "SHELF", "SHELL", "SHIFT", "SHINE",
        "SHIRT", "SHOCK", "SHOOT", "SHORE", "SHORT", "SHOUT", "SHOWN", "SIGHT",
        "SILLY", "SINCE", "SIXTH", "SIXTY", "SKILL", "SLEEP", "SLICE", "SLIDE",
        "SMALL", "SMART", "SMOKE", "SNAKE", "SOLAR", "SOLID", "SOLVE", "SORRY",
        "SPARE", "SPARK", "SPEAK", "SPEED", "SPELL", "SPEND", "SPENT", "SPICE",
        "SPILL", "SPINE", "SPLIT", "SPOKE", "SPORT", "SPRAY", "SQUAD", "STACK",
        "STAFF", "STAGE", "STAIN", "STAIR", "STAKE", "STALL", "STAMP", "STAND",
        "STARE", "STEAL", "STEAM", "STEEL", "STEEP", "STEER", "STICK", "STIFF",
        "STILL", "STING", "STOCK", "STORE", "STORM", "STORY", "STOVE", "STRIP",
        "STUCK", "STUDY", "STUFF", "STYLE", "SUGAR", "SUITE", "SUNNY", "SUPER",
        "SWEAT", "SWEEP", "SWEET", "SWELL", "SWIFT", "SWING", "SWORD", "TABLE",
        "TASTE", "TEACH", "TEETH", "TENSE", "THANK", "THEFT", "THEME", "THICK",
        "THIEF", "THIGH", "THINK", "THIRD", "THORN", "THREE", "THROW", "THUMB",
        "TIGER", "TIGHT", "TITLE", "TOAST", "TODAY", "TOKEN", "TOOTH", "TOPIC",
        "TORCH", "TOTAL", "TOUCH", "TOUGH", "TOWEL", "TOWER", "TRACK", "TRADE",
        "TREAT", "TREND", "TRIAL", "TRIBE", "TRICK", "TRIED", "TRUCK", "TRULY",
        "TRUNK", "TRUST", "TRUTH", "TWICE", "TWIST", "ULTRA", "UNCLE", "UNDER",
        "UNION", "UNITY", "UNTIL", "UPPER", "UPSET", "URBAN", "USAGE", "USUAL",
        "VAGUE", "VALID", "VALUE", "VAULT", "VERSE", "VIDEO", "VIRUS", "VISIT",
        "VITAL", "VOCAL", "VOICE", "WAGON", "WASTE", "WATCH", "WHEAT", "WHEEL",
        "WHERE", "WHILE", "WHITE", "WHOLE", "WHOSE", "WIDEN", "WIDER", "WORRY",
        "WORTH", "WOUND", "WRECK", "WRIST", "WRITE", "WRONG", "YIELD", "YOUNG",
        "YOUTH", "ZEBRA"
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
        return normalized.count == 5 && fiveLetterGuesses.contains(normalized)
    }

    static func isValidGridWord(_ word: String) -> Bool {
        let normalized = normalize(word)
        return normalized.count >= 3 && wordGridWords.contains(normalized)
    }

}
