module ominbot.core.map;

import std.stdio;
import std.algorithm;

import ominbot.core.params;
import ominbot.core.structs;
import ominbot.core.dictionary;


@safe:


/// Relation map bot model.
///
/// Based on conversations Omin has with other, Omin navigates and builds a relation map.
final class RelationMap {

    /// Dictionary used by the map.
    immutable Dictionary dictionary;

    /// Groups within the map.
    MapGroup[] groups;

    this() {

        // Load the dictionary
        dictionary = *getDictionary;

        // Insert root group.
        groups ~= new MapGroup();

    }

    MapGroup root() {

        return groups[0];

    }

    MapEntry[] parseText(string text) {

        import std.array;

        return dictionary.splitWords(text)
            .map!(a => MapEntry(a.word, false, 0, null))
            .array;

    }

    /// Find the most relevant groups in close proximity. Output is sorted.
    MapGroup[] relevant(MapGroup group, MapEntry[] entries) @trusted
    out (r; r.length != 0, "`relevant` output cannot be empty")
    do {

        import std.array, std.range;

        // Sort the entries
        auto sortedEntries = entries.sort;

        return [group].chain(group.searchRelated)
            .take(maxLookupDistance)
            .array
            .schwartzSort!(a => a.entries.setIntersection(sortedEntries).walkLength, "a > b")
            .array;

    }

    /// Feed text into the model to let it learn.
    /// Returns: Group the model ended on after learning.
    MapGroup feed(MapGroup group, string text, Logger logger = Logger.init) @trusted {

        import std.random;

        size_t progress;

        // Add stuff line by line
        foreach (line; splitLines(text)) {

            progress += line.length + 1;

            // Provide loading info
            if (progress % 200_000 <= line.length) {

                logger.loading("model", progress / text.length);
                break; // TODO optimize and don't
                // or lazy-load

            }

            // Ignore empty lines
            if (line.length == 0) continue;

            auto lineText = parseText(line);

            // Pick a new group based on relevant groups
            group = relevant(group, lineText)[0];

            // Insert the phrase into the model
            group = addPhrase(group, lineText).choice;

        }

        return group;

    }

    /// Insert a new phrase into the model.
    /// Returns: List of affected groups.
    MapGroup[] addPhrase(MapGroup group, MapEntry[] phrases) {

        import std.range;

        auto groups = [group];

        void bumpRelation(ref MapEntry entry) {

            foreach (otherPhrase; phrases) {

                entry.related.require(otherPhrase.text, 0) += 1;

            }

        }

        MapEntry[] insertQueue;

        // Check which phrases exist and which do not
        foreach (i, phrase; phrases) {

            // Get the next phrase, if present
            auto nextPhrase = i+1 < phrases.length
                ? phrases[i+1].text
                : "";

            // Find the entry in the group
            auto entries = group.entries.assumeSorted.equalRange(phrase);

            // Not found
            if (entries.length == 0) {

                // Insert
                phrase.bumpFollow(nextPhrase);
                insertQueue ~= phrase;

            }

            // Found
            else {

                // Bump relation count
                entries[0].bumpFollow(nextPhrase);
                bumpRelation(entries[0]);

            }

        }

        // Bump relation count for queued entries
        foreach (ref phrase; insertQueue) bumpRelation(phrase);

        // Insert the entries into the group
        group ~= insertQueue;

        // This group is too big
        if (group.entries.length > groupSizeLimit) {

            // Perform a split
            groups ~= splitGroup(group);

            // Check which group relates the best

        }

        return groups;

    }

    /// Split the given group.
    /// Returns: The newly created group.
    MapGroup splitGroup(MapGroup group) {

        // Create a new group
        auto newGroup = new MapGroup;
        groups ~= newGroup;

        // Bind them together
        group.related ~= newGroup;
        newGroup.related ~= group;

        do {

            import std.typecons;

            // Get the entry with the lowest relation count
            auto lowest = group.entries
                .map!(a => a.related.byValue.sum)
                .minIndex;

            // Move the entry into the new group
            auto entry = group.entries[lowest];
            newGroup ~= entry;
            group.entries = group.entries.remove(lowest);

            // Split the group starting from that entry
            crackSplit(group, newGroup, entry);

        }

        // Repeat if the group is still too big
        while (group.entries.length > groupSizeLimit);


        // But wait, our new group might be too big
        if (newGroup.entries.length > groupSizeLimit) {

            splitGroup(newGroup);

        }

        return newGroup;

    }

    private void crackSplit(MapGroup input, MapGroup output, MapEntry entry)
    in (output.entries.isSorted, "Output must be sorted (at entry)")
    do {

        scope (exit) assert(output.entries.isSorted, "Output must be sorted");

        import std.array;

        // Check all relations of this node
        foreach (relation; entry.related.byKeyValue.array.sort!"a.value < b.value".map!"a.key") {

            // Stop once group size has been normalized
            if (input.entries.length - output.entries.length <= groupSizeLimit) break;

            const noun = dictionary.findWord(relation).noun;

            // TODO: don't reset relations; keep sentiment
            output ~= MapEntry(relation, noun, 0, null);

            // Remove from the original range
            input.entries = input.entries.remove!(a => a.text == relation);

        }

    }

    private auto splitLines(string text) {

        return text.splitter("\n");

    }

}
