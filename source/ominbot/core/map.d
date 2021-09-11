module ominbot.core.map;

import std.stdio;
import std.algorithm;

import ominbot.core.params;
import ominbot.core.structs;


@safe:


/// Relation map bot model.
///
/// Based on conversations Omin has with other, Omin navigates and builds a relation map. If a word is used along with
/// another, those two will be pulled closer to each other within the map.
final class RelationMap(size_t height) {

    /// Columns in the map. Note: lookup order is columns[x][y].
    MapEntry[height][] columns;

    /// Current position of Omin within the map.
    OminPosition position;

    this() {

        // The model should at first be big enough to contain the lookup range.
        columns.length = mapLookupRadius * 2 + 1;

        // Move to the middle of the map
        position = OminPosition(mapLookupRadius, height / 2);

        writefln!"starting at position %s"(position);

    }

    /// Feed text into the model to let it learn.
    void feed(string text) {

        const words = splitWords(text);

        // Add each word into the model
        foreach (word; words) {

            addPhrase(MapEntry(word, false, 1, 0));

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
    void addPhrase(MapEntry phrase) {

        import std.array;

        // Unoccupied slots found on the map
        auto freeSlots = appender!(OminPosition[]);

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
                return;

            }

        }

        // Not found...
        insertPhrase(phrase, freeSlots[]);

    }

    /// Fetch a single entry.
    /// Params:
    ///     boostDistance = Entries this far away from the position will have an increased chance to be picked.
    ///     threshold = Fails if the first match is beyond threshold — surrounding area is probably mostly empty, if so.
    ///     radius = Maximum radius of lookup.
    /// Returns:
    ///     Matched entry on success, `null` on failure.
    /// Note: Loopup area is square and boost range is based on a circle.
    MapEntry* fetch(size_t minRadius = 0, size_t maxRadius = mapLookupRadius, float threshold = 0.6) {

        import std.array, std.range;
        import std.conv, std.math, std.random, std.typecons;

        Tuple!(MapEntry*, double)[] items;

        // TODO: optimize by using a more advanced callback, possible but might be difficult
        foreach (x, y, entry; scan(maxRadius)) {

            // Ignore empty entries
            if (!*entry) continue;

            // Calculate value for this node
            auto distance = distance2(OminPosition(x, y))^^0.5;

            // Too close to center, ignore
            if (distance < minRadius) continue;

            items ~= tuple(entry, distance);

        }

        // No items to choose from...
        if (items.length == 0) return null;

        // Get a random matching item
        return items.sort!"a[1] < b[1]"
            .take(to!ulong(items.length * (1 - threshold)))
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

        writefln!"moving to position %s"(position);

    }

    /// Get distance between current position and the given one, up to second power.
    float distance2(OminPosition a) {

        return (a.x - position.x)^^2 + (a.y - position.y)^^2;

    }

    /// Insert a phrase into the map.
    private void insertPhrase(MapEntry phrase, OminPosition[] freeSlots, float threshold = 0.8) {

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

        // Get top item
        auto entryPos = selection.take(to!size_t(freeSlots.length * (1-threshold)))
            .array
            .choice;

        // Replace it with this phrase
        columns[entryPos.x][entryPos.y] = phrase;

        writefln!"inserted at (%s, %s)"(entryPos.x, entryPos.y);


    }

    private string[] splitWords(string text) @trusted {

        import std.uni, std.conv, std.array, std.string;

        // Strip on whitespace
        return text.splitWhen!((a, b) => a.isWhite)

            // Remove the whitespace from the result
            .map!(a => a.array.strip.to!string)

            // Remove empty items
            .filter!(a => a.length)
            .array;

    }

}
