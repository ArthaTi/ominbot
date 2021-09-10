module ominbot.core.structs;

struct MapEntry {

    /// Text within the entry.
    string text;

    /// If true, this entry represents a single noun.
    bool noun;

    /// Occurence count.
    ulong occurences;

    /// Sentiment of the entry.
    short sentiment;

    /// Check if the entry is empty or not.
    bool opCast(T : bool)() const {

        return text.length > 0;

    }

    /// Check if the two entries hold the same text.
    bool opEquals(const MapEntry other) const {

        return text == other.text;

    }

    /// Check if this entry holds given text.
    bool opEquals(const string other) const {

        return text == other;

    }

}

struct OminPosition {

    ptrdiff_t x, y;
    invariant(x >= 0 && y >= 0);

}
