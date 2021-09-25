module ominbot.core.markov;

import std.range;
import std.stdio;
import std.random;
import std.algorithm;
import std.container;

import ominbot.core.params;
import ominbot.core.structs;
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

/// Update the model.
/// Returns: the sentiment of the given text.
short feed(T, Model)(ref Model model, T text, shared Object mutex, Logger logger = Logger.init) @trusted
out (r; -255 <= r)
out (r; r <= 255)
do {

    import std.conv, std.traits;

    static assert (is(Model == MarkovModel) || is(Model == shared MarkovModel),
        "Model type must either be Model or shared Model");

    // Got a shared model
    static if (is(Model == shared MarkovModel)) {

        assert(mutex !is null, "Mutex cannot be null for a shared model");

    }

    auto dictionary = getDictionary();
    size_t progress;

    short sentiment;

    // Load as string
    static if (isSomeString!T) {

        const total = text.length;
        auto range = text.splitter("\n");

    }

    // Load as file
    else static if (is(T == File)) {

        const total = text.size;
        auto range = text.byLine;

    }

    else static assert(false, "type unsupported by markov.feed");


    /// Send progress update messages once per bytes read.
    enum progressPerBytes = 500_000;
    bool issueProgressMsg = total > progressPerBytes;

    // Add loading status for edges
    if (issueProgressMsg) logger.loading("model", 0);
    scope (exit) if (issueProgressMsg) logger.loading("model", 100);

    // Go line by line
    foreach (line; range) {

        progress += line.length + 1;

        // Provide loading info
        if (progress % progressPerBytes <= line.length) {

            logger.loading("model", 100 * progress / total);

        }

        // Parse words
        auto words = dictionary.splitWords(line.to!string);

        // No words given?
        if (words.empty) continue;

        // Add an empty word at start
        words = [Word.init] ~ words;

        foreach (i, word; words.enumerate) {

            auto nextWord = i+1 < words.length
                ? words[i+1]
                : Word.init;

            // Get the current context
            const context = words[0 .. i+1]
                .tail(contextSize)
                .map!"a.word"
                .filter!"a.length"
                .array;

            // Update the sentiment
            sentiment = clamp(sentiment + word.sentiment, -255, 255).to!short;

            void submit() {

                if (auto entry = word.word in model) {

                    updateEntry(*cast(MarkovEntry*) entry, context, nextWord);

                }

                else {

                    MarkovEntry newEntry;
                    newEntry.updateEntry(context, nextWord);
                    model[word.word] = cast(shared) newEntry;

                }

            }

            // Update the entry model (1. sync version)
            if (mutex) synchronized (mutex) submit();

            // 2. thread-local version
            else submit();

        }

    }

    return sentiment;

}

string[] generate(ref MarkovModel model, short humor, int wordCount, string[] context = []) {

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
        if (abs(humor) > uniform(50, 320)) {

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

                // Too many spaces!
                if (output.length > 3 * wordCount) break;

            }

        }

        // Count the word
        else pushedWords++;


        // Add to context
        if (auto part = lastWord in model) {

            entry = *part;

            // Add a chance to skip a word
            if (uniform01 < markovSkipWord) {

                auto newPart = getWord() in model;
                entry = newPart ? *newPart : *part;

            }

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

    return output;

}

private MarkovItem getBestItem(ref MarkovEntry entry, string[] context, short humor) {

    import std.math;

    auto sorted = entry.schwartzSort!(
        (MarkovItem a) => log2(a.occurences.get(context, 0))
            + 10 * a.nextWord.sentiment * humor / 255.0
            + 3 * setIntersection(a.before[], context.dup.sort.filter!"a.length").walkLength,
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
