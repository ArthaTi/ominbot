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

        import std.range, std.algorithm;

        // Insert the new entries
        entries.assumeSorted.completeSort(newEntries);
        entries ~= newEntries;

    }

    void opOpAssign(string op : "~")(MapEntry newEntry) {

        this ~= [newEntry];

    }

    MapEntry* opBinaryRight(string op : "in")(const MapEntry searchEntry) const {

        import std.range, std.algorithm;

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

        return related.filter!(a => a != group);

    }

    /// Find all connected groups, by distance.
    auto searchRelated() {

        import std.range;

        return related.chain(searchRelatedImpl);

    }

    import std.range;

    private auto searchRelatedImpl() @trusted {

        import std.range, std.algorithm;

        return chain(
            deepChildren,
            deepChildren.map!(a => SearchRelated(deepChildren, deepChildren)).joiner
        );

    }

    /// Get children at second depth level.
    private auto deepChildren() @trusted {

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
