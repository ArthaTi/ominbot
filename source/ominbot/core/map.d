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

    /// Feed text into the model to let it learn.
    void feed(MapGroup group, string text) @trusted {

        import std.array, std.stdio;

        size_t progress;

        // Add stuff line by line
        foreach (line; splitLines(text)) {

            auto words = splitWords(line);

            progress += line.length + 1;

            // Provide loading info
            if (progress % 200_000 <= line.length) {

                writefln!"loading model... ~%skB/%skB, %s groups built"(progress/1000, text.length/1000, groups.length);

            }

            // Add each word into the model
            addPhrase(group, words.map!(a => MapEntry(a, false, 0, null)).array);

        }

    }

    /// Insert a new phrase into the model.
    void addPhrase(MapGroup group, MapEntry[] phrases) {

        MapEntry*[] insertedPhrases;

        // Insert each phrase
        foreach (phrase; phrases) {

            // Find the entry in the group
            auto entries = group.entries.find!"a == b"(phrase);

            // Not found, insert
            if (entries.length == 0) {

                group.entries ~= phrase;
                insertedPhrases ~= &group.entries[$-1];

            }

            // Found
            else insertedPhrases ~= &entries[0];

        }

        // Bump relation count
        foreach (phrase; insertedPhrases) {

            foreach (otherPhrase; insertedPhrases) {

                phrase.related.require(otherPhrase.text, 0) += 1;

            }

        }

        // This group is too big, perform a split
        if (group.entries.length >= groupSizeLimit) splitGroup(group);


    }

    /// Split the given group.
    void splitGroup(MapGroup group) {

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

            // Move the entry
            auto entry = group.entries[lowest];
            newGroup.entries ~= entry;
            group.entries = group.entries.remove(lowest);

            // Split the group starting from that entry
            crackSplit(group, newGroup, entry);

        }

        // Repeat if the group is still too big
        while (group.entries.length > groupSizeLimit);

    }

    private void crackSplit(MapGroup input, MapGroup output, MapEntry entry) {

        import std.array;

        // Check all relations of this node
        foreach (relation; entry.related.byKeyValue.array.sort!"a.value < b.value".map!"a.key") {

            const noun = dictionary.findWord(relation).noun;

            // TODO: don't reset relations; keep sentiment
            output.entries ~= MapEntry(relation, noun, 0, null);

            // Remove from the original range
            input.entries = input.entries.remove!(a => a.text == relation);

            // Stop once group size has been normalized
            if (input.entries.length - output.entries.length < groupSizeLimit) break;

        }

    }

    private auto splitLines(string text) {

        return text.splitter("\n");

    }

    private string[] splitWords(string text) @trusted {

        import std.uni, std.conv, std.array, std.string;

        // Strip on whitespace
        return text.splitWhen!((a, b) => a.isWhite)

            // Remove non alpha-numeric content from the words
            .map!(a => a
                .filter!isAlphaNum
                .array
                .to!string
                .toLower
            )

            // Remove empty items
            .filter!(a => a.length)

            // Remove long numbers
            .filter!(a => a.all!(a => !a.isNumber) || a.length <= 4)

            // Only take in nouns
            //.filter!(a => dictionary.findWord(a).noun)

            .array;

    }

}
