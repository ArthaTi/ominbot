module ominbot.word_lists;

import core.atomic;

import std.stdio;
import std.string;
import std.random;
import std.file : exists;

private shared immutable(WordList)* _wordList;

shared static this() {

    WordList tmp;

    writefln!"Loading dictionary...";

    tmp.build("resources/nouns.txt", 0, true);

    tmp.build("resources/positive.txt", +1, false);
    tmp.build("resources/negative.txt", -1, false);

    tmp.build("resources/bot-positive.txt", +1, true);
    tmp.build("resources/bot-negative.txt", -1, true);

    // Save changes
    tmp.words.rehash();

    updateWordList(cast(immutable) tmp);

}

struct Word {

    string word;
    byte sentiment;
    bool noun;
    invariant(sentiment == -1 || sentiment == 0 || sentiment == +1);

}

struct WordList {

    Word[string] words;

    string[] positive;
    string[] negative;

    /// Add a word list to the list.
    /// Params:
    ///     file = Path to the word list file.
    ///     sentiment = Word sentiment (-1 for negative, 1 for positive, 0 for neutral)
    ///     insert = If true, assumes the word is a noun.
    void build(string file, byte sentiment, bool noun)
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

                    return Word(text, newType, old.noun || noun);

                }

            );
            if (noun || text !in words) words[text] = Word(text, sentiment, noun);


            // Insert the word into typing arrays
            if (sentiment > 0) positive ~= text;
            else if (sentiment < 0) negative ~= text;

        }

    }

    /// Get the type of the given word.
    inout(Word) opBinary(string op : "in")(string word) inout {

        return words.get(word, cast(inout) Word(word, 0, false));

    }

    alias findWord = opBinary!"in";

    /// Get a random word matching the type.
    string randomWord(int sentiment) const
    in (sentiment != 0)
    do {

        if (sentiment > 0) return positive[].choice;
        if (sentiment < 0) return negative[].choice;
        else assert(false);

    }

}

immutable(WordList)* getWordList() {

    return _wordList.atomicLoad;

}

void updateWordList(immutable WordList newList) {

    _wordList.atomicStore = cast(shared) new immutable WordList(newList.tupleof);

}

unittest {

    const list = getWordList;

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
