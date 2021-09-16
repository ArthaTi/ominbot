module ominbot.core.structs;

import std.range;
import std.typecons;

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

    /// Up to ten words that frequently follow this word.
    string[10] following;

    /// Bump the given word in the list.
    void bumpFollow(string word) {

        import std.algorithm;

        // Ignore if the input is empty or same as the phrase
        if (word == "" || word == text) return;

        foreach (index, flw; following) {

            // Found an empty word
            if (flw == "") {

                // Insert this word
                following[index] = word;

                return;

            }

            // Ignore different words
            if (flw != word) continue;

            // Swap with the previous entry
            if (index) swap(following[index-1], following[index]);

            return;

        }

        // Didn't find any empty slots, insert as last
        following[$-1] = word;

    }

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

    ptrdiff_t opCmp(ref const MapEntry other) const {

        import std.algorithm;

        return cmp(text, other.text);

    }

}

class MapGroup {

    static ptrdiff_t nextID;

    ptrdiff_t id;

    /// Entries in this group. Should be sorted.
    MapEntry[] entries;

    /// Related groups
    MapGroup[] related;

    this() {

        id = nextID++;

    }

    void opOpAssign(string op : "~")(MapEntry[] newEntries) {

        import std.algorithm;

        // Insert the new entries
        entries.assumeSorted.completeSort(newEntries);
        entries ~= newEntries;

    }

    void opOpAssign(string op : "~")(MapEntry newEntry) {

        this ~= [newEntry];

    }

    MapEntry* opBinaryRight(string op : "in")(const MapEntry searchEntry) const {

        import std.algorithm;

        auto found = iota(entries.length)
            .assumeSorted!((a, b) => entries[a] < entries[b])
            .equalRanage(searchEntry);

        // Not found, return false
        if (!found.length) return null;

        // Get pointer to the entry
        return &found[0];

    }

    ptrdiff_t opCmp(const MapGroup group) const {

        return id - group.id;

    }

    /// Get all related groups except for the given one
    auto relatedExcept(const MapGroup group) {

        import std.algorithm;

        return related.filter!(a => a !is group);

    }

    /// Find the closest instance of one of the given phrases within the map.
    /// Params:
    ///     phrases = Phrases to search for.
    ///     limit   = Maximum distance from this group to search in. Defaults to maximum lookup distance.
    /// Returns: Target group and the encountered phrase, (`null`, `null`) if not found.
    Tuple!(MapGroup, MapEntry) findRelated(string[] phrases, size_t limit = maxLookupDistance) {

        import std.algorithm;

        // Perform the lookup
        MapEntry foundPhrase;
        auto result = chain([this], searchRelated)
            .find!((a) {

                auto entry = a.entries.findAmong(phrases);

                // Ignore if it's not the entry we're looking for
                if (entry.empty) return false;

                // If found, mark it
                foundPhrase = entry.front;
                return true;

            });

        // Not found, ignore
        if (result.empty) return typeof(return).init;

        // Get the result otherwise
        return typeof(return)(result.front, foundPhrase);

    }

    /// Find all connected groups, by distance.
    auto searchRelated() {

        return related.chain(searchRelatedImpl);

    }

    private auto searchRelatedImpl() {

        import std.algorithm;

        return chain(
            deepChildren,
            deepChildren.map!(a => SearchRelated(deepChildren, deepChildren)).joiner
        );

    }

    /// Get children at second depth level.
    private auto deepChildren() {

        import std.algorithm;

        return related
            .map!(a => a.relatedExcept(this))
            .joiner;

    }

    private struct SearchRelated {

        typeof(deepChildren()) list;
        typeof(deepChildren()) savedList;

        bool empty() {

            return list.empty && savedList.empty;

        }

        MapGroup front() @trusted {

            return list.front;

        }

        void popFront() @trusted {

            list.popFront;

            // List emptied, try to get a new list from the saved list
            if (list.empty && !savedList.empty) {

                list = savedList.front.deepChildren();
                savedList.popFront;

            }

        }

    }

}
