module ominbot.core.structs;

import ominbot.core.params;


@safe:


struct MapEntry {

    /// Text of the phrase.
    string text;

    /// If true, this entry represents a single noun.
    bool noun;

    /// Sentiment of the phrase.
    short sentiment;

    /// Number of times another phrase had been used along with this one.
    int[string] related;

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

class MapGroup {

    /// Entries in this group.
    MapEntry[] entries;

    /// Related groups
    MapGroup[] related;

}
