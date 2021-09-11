module ominbot.core.map;

import std.stdio;
import std.algorithm;

import ominbot.core.params;
import ominbot.core.structs;
import ominbot.core.dictionary;


@safe:


/// Relation map bot model.
///
/// Based on conversations Omin has with other, Omin navigates and builds a relation map. If a word is used along with
/// another, those two will be pulled closer to each other within the map.
final class RelationMap(size_t _height) {

    enum height = _height;

    /// Dictionary used by the map.
    immutable Dictionary dictionary;

    /// Columns in the map. Note: lookup order is columns[x][y].
    MapEntry[height][] columns;

    /// Current position of Omin within the map.
    OminPosition position;

    this() {

        // Load the dictionary
        dictionary = *getDictionary;

        // The model should at first be big enough to contain the lookup range.
        columns.length = mapLookupRadius * 2 + 1;

        // Move to the middle of the map
        position = OminPosition(mapLookupRadius, height / 2);

        writefln!"starting at position %s"(position);

    }

    /// Feed text into the model to let it learn.
    void feed(string text) @trusted {

        import std.stdio;

        size_t progress;

        MapEntry* lastWord;

        // Add each word into the model
        foreach (word; splitWords(text)) {

            progress += word.length + 1;

            if (progress % 200_000 <= word.length) {

                writefln!"loading model... ~%skB/%skB"(progress/1000, text.length/1000);

                debug break;

            }

            lastWord = addPhrase(MapEntry(word, false, 1, 0), lastWord);

        }

    }

    auto scan(ptrdiff_t radius = mapLookupRadius) {

        // Get the range
        const minX = max(position.x - radius, 0);
        const minY = max(position.y - radius, 0);
        const maxX = min(position.x + radius + 1, columns.length);
        const maxY = min(position.y + radius + 1, height);

        struct MapIterator {

            RelationMap!height map;

            int opApply(int delegate(size_t x, size_t y, MapEntry* entry) @safe dg) {

                foreach (y; minY..maxY) {

                    foreach (x; minX..maxX) {

                        auto entry = &map.columns[x][y];

                        if (auto ret = dg(x, y, entry)) return ret;

                    }

                }

                return 0;

            }

        }

        return MapIterator(this);

    }

    /// Lookup the phrase within the model. Increment its occurence count and move closer to the middle, or add it if
    /// it wasn't found.
    /// Returns: pointer to the inserted phrase
    MapEntry* addPhrase(MapEntry phrase, MapEntry* previous = null) {

        import std.array;

        // Unoccupied slots found on the map
        auto freeSlots = appender!(OminPosition[]);

        // Update the previous item
        if (previous) {

            // Search for this text in entries for that phrase
            const index = previous.following[].countUntil(phrase.text);

            // Found, perform a swap
            if (index > 0) {

                swap(previous.following[index-1], previous.following[index]);

            }

            // Nope, insert
            else {

                const emptyIndex = previous.following[].countUntil(null);

                previous.following[emptyIndex == -1 ? $-1 : emptyIndex] = phrase.text;

            }

        }

        // Search for the phrase within the range
        foreach (x, y, entry; scan(mapRearrangeRadius)) {

            // Save if the slot is free
            if (!*entry) {

                freeSlots.put(OminPosition(x, y));
                continue;

            }

            // Found a match?
            if (entry.text == phrase.text) {

                // Found a match, increment the entry
                entry.occurences++;

                // Pull the entry
                pullTogether(OminPosition(x, y));

                // End searching
                return entry;

            }

        }

        // Not found...
        return insertPhrase(phrase, freeSlots[]);

    }

    /// Fetch a single entry.
    /// Returns:
    ///     Matched entry on success, `null` on failure.
    MapEntry* fetch(FetchOptions options) {

        import std.array, std.range;
        import std.conv, std.math, std.random, std.typecons;

        Tuple!(MapEntry*, double)[] items;

        // TODO: optimize by using a more advanced callback, possible but might be difficult
        foreach (x, y, entry; scan(options.maxRadius)) {

            // Ignore empty entries
            if (!*entry) continue;

            // Calculate value for this node
            auto distance = distance2(OminPosition(x, y))^^0.5;

            // Too close to center, ignore
            if (distance < options.minRadius) continue;

            items ~= tuple(entry, distance);

        }

        // No items to choose from...
        if (items.length == 0) return null;

        double priority(MapEntry* entry) {

            return options.encouraged.canFind(entry.text) ? 2.0 : 0
                + options.discouraged.canFind(entry.text) ? 0.5 : 0;

        }

        // Get a random matching item
        return items.schwartzSort!(a => a[1] / priority(a[0]))
            .take(1 + to!ulong(items.length * (1 - options.threshold)))
            .array
            .choice[0];

    }

    /// Pull the entry at given position closer to the current position, and navigate to it.
    void pullTogether(OminPosition target) {

        const column = columns[target.x];
        const entry = columns[target.x][target.y];

        // Update within the column first
        // 0 1 2 [3] 4 5 | 6 7 8 9 10
        const newPosY = (target.y + position.y) / 2;

        // Backwards: the target appears earlier in the column
        if (target.y < newPosY) {

            // Remove the entry
            // TODO range violation?
            columns[target.x] = column[0 .. target.y] ~ column[target.y+1 .. newPosY]

                // Add it again at the target position
                ~ entry ~ column[newPosY .. $];

        }

        // Forwards
        else if (target.y > newPosY) {

            // Insert the entry
            columns[target.x] = column[0 .. newPosY] ~ entry

                // Remove the old target
                ~ column[newPosY .. target.y] ~ column[target.y+1 .. $];

        }


        import std.range;

        // Now move the entry within the row
        const newPosX = (target.x + position.x) / 2;
        const direction = newPosX > target.x ? 1 : -1;

        auto cols = iota(target.x, newPosX - 1);
        foreach (x; cols) {

            swap(columns[x], columns[x+1]);

        }

        // Move to the resulting position
        position = OminPosition(newPosX, newPosY);

    }

    /// Get distance between current position and the given one, up to second power.
    float distance2(OminPosition a) {

        return (a.x - position.x)^^2 + (a.y - position.y)^^2;

    }

    /// Insert a phrase into the map.
    private MapEntry* insertPhrase(MapEntry phrase, OminPosition[] freeSlots, float threshold = 0.8) {

        import std.math : abs, sgn;
        import std.conv, std.array, std.range, std.random;

        // No slots available
        if (freeSlots.length == 0) {

            // Insert a new column
            columns = columns[0 .. position.x] ~ (MapEntry[height]).init ~ columns[position.x .. $];

            // Register the slots
            // TODO: respect rearrange range?
            foreach (i, item; columns[position.x]) {

                freeSlots ~= OminPosition(position.x, i);

            }

            // TODO: store the word in a temporary list (words from which would be accessible at all time)
            // perform sleep if it grows too big, i.e. rebuild the model based on direct word relation data

        }

        // Sort by preference
        auto selection = freeSlots.schwartzSort!(

            // Prioritize close cells
            a => distance2(a)

                // Update Y preference based on humor
                + 2*abs(sgn(a.y - position.y) - phrase.sentiment)

        );

        const options = max(1, to!size_t(freeSlots.length * (1-threshold)));

        // Get top item
        auto entryPos = selection.take(options)
            .array
            .choice;

        // Replace it with this phrase
        auto target = &columns[entryPos.x][entryPos.y];
        *target = phrase;
        return target;


    }

    private auto splitWords(string text) @system {

        import std.uni, std.conv, std.array, std.string;

        // Strip on whitespace
        return text.splitWhen!((a, b) => a.isWhite)

            // Remove non alpha-numeric content from the words
            .map!(a => a.filter!isAlphaNum.array.to!string)

            // Remove empty items
            .filter!(a => a.length)

            // Remove long numbers
            .filter!(a => a.all!(a => !a.isNumber) || a.length <= 4)

            // Only take in nouns
            .filter!(a => dictionary.findWord(a).noun);

    }

}
