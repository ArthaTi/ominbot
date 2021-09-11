module ominbot.core.structs;

import ominbot.core.params;

struct MapEntry {

    /// Text within the entry.
    string text;

    /// If true, this entry represents a single noun.
    bool noun;

    /// Occurence count.
    ulong occurences;

    /// Sentiment of the entry.
    short sentiment;

    /// Words frequently following this entry
    string[10] following;

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

struct FetchOptions {

    /// Boost chance to use those words after.
    string[] encouraged;

    /// Reduce chance to use words in this this list after.
    string[] discouraged;

    /// Minimum (circle) radius of word search.
    size_t minRadius = 0;

    /// Maxiumum (square) radius of word search.
    size_t maxRadius = mapLookupRadius;

    /// Threshold for choosing most fitting words.
    float threshold = 0.8;


}

struct OminPosition {

    ptrdiff_t x, y;
    invariant(x >= 0 && y >= 0);

}
