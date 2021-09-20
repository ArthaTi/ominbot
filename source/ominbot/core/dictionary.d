module ominbot.core.dictionary;

import core.atomic;

import std.stdio;
import std.string;
import std.random;
import std.file : exists;


@safe:


private shared immutable(Dictionary)* _dictionary;

shared static this() @system {

    Dictionary tmp;

    writefln!"loading dictionary...";

    tmp.build("resources/nouns.txt", 0, true);

    tmp.build("resources/positive.txt", +1, false);
    tmp.build("resources/negative.txt", -1, false);

    tmp.build("resources/bot-positive.txt", +1, true);
    tmp.build("resources/bot-negative.txt", -1, true);

    // Optimize the dictionary
    tmp.words.rehash();

    updateDictionary(cast(immutable) tmp);

}

struct Word {

    string word;
    byte sentiment;
    bool noun;
    invariant(sentiment == -1 || sentiment == 0 || sentiment == +1);

}

struct Dictionary {

    Word[string] words;

    string[] positive;
    string[] negative;

    /// Add a word list to the dictionary.
    /// Params:
    ///     file = Path to the word list file.
    ///     sentiment = Word sentiment (-1 for negative, 1 for positive, 0 for neutral)
    ///     insert = If true, assumes the word is a noun.
    void build(string file, byte sentiment, bool noun) @system
    in (sentiment == -1 || sentiment == 0 || sentiment == +1)
    do {

        // Issue a warning if the list doesn't exist
        if (!exists(file)) {

            stderr.writefln!"Warning: File %s doesn't exist, not loaded."(file);
            return;

        }

        auto listFile = File(file);

        foreach (line; listFile.byLine) {

            const text = cast(string) line.strip.dup;

            // Ignore comments
            if (text.length == 0 || text[0] == ';') continue;

            bool thisNoun = noun;

            // Insert the data into the array, unless we'd override a noun
            words.update(text,

                // Insert the word
                {
                    return Word(text, sentiment, noun);
                },

                // Update an existing entry
                (Word old) {

                    const newType = sentiment != 0
                        ? sentiment
                        : old.sentiment;

                    thisNoun = old.noun || noun;

                    return Word(text, newType, old.noun || noun);

                }

            );

            // Insert the word into typing arrays
            if (thisNoun) {

                if (sentiment > 0) positive ~= text;
                else if (sentiment < 0) negative ~= text;

            }

        }

    }

    /// Get the type of the given word.
    Word opBinaryRight(string op : "in")(string word) inout {

        return words.get(word, cast(inout) Word(word, 0, false));

    }

    alias findWord = opBinaryRight!"in";

    /// Get a random word matching the type.
    string randomWord(int sentiment) const
    in (sentiment != 0)
    do {

        if (sentiment > 0) return positive[].choice;
        if (sentiment < 0) return negative[].choice;
        else assert(false);

    }

    /// Split text into words.
    Word[] splitWords(string text) @trusted const {

        // TODO: parse sentence ends, required for markov omin

        import std.range;
        import std.typecons;
        import std.algorithm;
        import std.uni, std.conv, std.string;

        // Strip on whitespace
        return text.splitWhen!((a, b) => a.isWhite)

            // Remove non alpha-numeric content from the words
            .map!(a => tuple(
                // [0]: word
                a.filter!(b => b.isAlphaNum)
                    .to!string
                    .toLower,
                // [1]: marks
                a.filter!(b => ".!?‽".canFind(b))
                    .take(1)
                    .to!string
            ))

            // Remove empty items
            .filter!(a => a[0].length)

            // Remove long numbers
            .filter!(a => a[0].all!(b => !b.isNumber) || a[0].length <= 4)

            // Get the word
            .map!(a => tuple(findWord(a[0]), a[1]))

            // Only take in nouns
            .filter!(a => a[0].noun)

            // Add marks back in
            .map!(a => Word(a[0].word ~ a[1], a[0].sentiment, a[0].noun))

            .array;

    }

}

immutable(Dictionary)* getDictionary() {

    return _dictionary.atomicLoad;

}

void updateDictionary(immutable Dictionary newList) {

    _dictionary.atomicStore = cast(shared) new immutable Dictionary(newList.tupleof);

}

unittest {

    const list = getDictionary;

    void checkWord(string name, byte type, bool noun) {

        const foundWord = list.findWord(name);

        assert(foundWord == Word(name, type, noun));

    }

    checkWord("afraid",     -1, false);
    checkWord("aggression", -1, true);
    checkWord("adore",      +1, false);
    checkWord("advantage",  +1, true);
    checkWord("alpaca",      0, true);
    checkWord("-",           0, false);

}
