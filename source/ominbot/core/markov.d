module ominbot.core.markov;

import std.range;
import std.stdio;
import std.random;
import std.algorithm;
import std.container;

import ominbot.core.params;
import ominbot.core.dictionary;


@safe:


struct MarkovItem {

    // old version
    //string[] context;
    //uint occurences;

    /// Word to place next if this entry was selected.
    Word nextWord;

    /// Words that come before the item in the context.
    RedBlackTree!(const string) before;

    /// Occurence count of an exact preceding phrase, including the next word.
    uint[string[]] occurences;

}

alias MarkovEntry = MarkovItem[];
alias MarkovModel = MarkovEntry[string];

void feed(ref MarkovModel model, string text) {

    auto dictionary = getDictionary();

    // TODO: load line by line
    auto words = dictionary.splitWords(text);

    if (words.empty) return;

    // Insert the first word at an empty segment
    model.require("", []).updateEntry([], words.front);

    // Rewrite to use partial
    foreach (i, word; words.enumerate) {

        if (i && i % 100_000 == 0) writefln!"Building model: %s words out of %s"(i, words.length);

        auto nextWord = i+1 < words.length
            ? words[i+1]
            : Word.init;

        // Get the current context
        const context = words[0 .. i+1]
            .tail(contextSize)
            .map!"a.word"
            .filter!"a.length"
            .array;

        // Update the entry model
        model.require(word.word, []).updateEntry(context, nextWord);

    }

}

string[] generate(ref MarkovModel model, int humor, int wordCount, string[] context = []) {

    import std.math;

    auto dictionary = getDictionary();

    string[] output;
    size_t pushedWords;  // Word count, excluding empty words

    // Initialize with sentence start context
    auto entry = model[""];

    // Try to steal a word from the context
    void stealWord() {

        // Check if there is a context to begin with
        if (!context.length) return;

        const index = uniform(0, context.length);

        import std.stdio : writefln;
        writefln!"stealing word %s from context %s"(context[index], context);

        // Fail chance is probably pretty big unless the prompt uses only nouns
        // Hence this is a rather safe operation and there's still a big chance to reuse the word
        entry = model.get(context[index], entry);
        context = context.remove(index);

    }

    string getWord() {

        return entry.getBestItem(output, humor).nextWord.word;

    }

    string randomWord() {

        return humor >= 0
            ? dictionary.positive[].choice
            : dictionary.negative[].choice;

    }

    // Try to steal a word from the context for the start.
    stealWord();

    // Try getting the data
    while (pushedWords < wordCount) {

        // The more emotional, the higher should be the chance
        if (abs(humor) > uniform(humorLimit, humorLimit * 5)) {

            // Pick a random word
            output ~= randomWord();

        }

        // Otherwise trigger markov
        else output ~= getWord();


        auto lastWord = output[$-1];

        // Added an empty word
        if (lastWord == "") {

            // Try to get the previous word instead
            if (output.length > 1) {

                lastWord = output[$-2];

            }

        }

        // Count the word
        else pushedWords++;


        // Add to context
        if (auto part = lastWord in model) {

            entry = *part;

            continue;

        }

        //
        break;

        version (none) {

            // Found no words, try to use a random word
            if (auto part = randomWord() in model) {

                entry = *part;

            }

        }

        // :(

    }

    //return output.amplify(humor);
    return output;

}

private MarkovItem getBestItem(ref MarkovEntry entry, string[] context, int humor) {

    import std.math;

    auto sorted = entry.schwartzSort!(
        (MarkovItem a) => log2(a.occurences.get(context, 0))
            + (humorLimit + a.nextWord.sentiment * humor) * 2 / humorLimit
            + 3 * setIntersection(a.before[], context.sort.filter!"a.length").walkLength,
        "a > b"
    );

    if (context.length)
    return sorted
        .take(worstFit)
        .array
        .randomShuffle
        .front;

    return sorted.randomShuffle.front;

}

/// Update the entry in the model.
// /// Returns: The most common phrase, which is a substring of context, occuring within the model.
private void updateEntry(ref MarkovEntry entry, const string[] context, Word nextWord)
in (context.all!"a.length", "updateEntry context cannot have empty words")
do {

    // Full text chain, including the next word
    auto chain = context ~ nextWord.word;

    // Find an item with a matching context
    foreach (ref item; entry) {

        if (nextWord != item.nextWord) continue;

        item.before.insert(context);

        return;

    }

    // Didn't find any, add one
    auto item = MarkovItem(nextWord, redBlackTree(context), [context: 1]);
    entry ~= item;

}
