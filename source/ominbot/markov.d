module ominbot.markov;

import std.uni;
import std.conv;
import std.math;
import std.array;
import std.stdio;
import std.range;
import std.random;
import std.algorithm;
import std.container;

import ominbot.params;
import ominbot.structs;
import ominbot.word_lists;

struct MarkovItem {

    Word nextWord;

    /// Words that come before the item in the context.
    RedBlackTree!string before;

    /// Occurence count of an exact preceding phrase, including the next word.
    uint[string[]] occurences;

}

alias MarkovEntry = MarkovItem[];
alias MarkovModel = MarkovEntry[string];

// Note: empty word is treated as sentence end.

/// Returns: Occurence numbers for each discovered phrase.
Phrase[] feed(ref MarkovModel model, Word[] words) {

    if (words.length == 0) return [];

    Phrase[] result;
    result ~= model.require("", []).updateEntry([], words[0]);

    foreach (i, word; words) {

        if (i && i % 100_000 == 0) writefln!"Building model: %s words out of %s"(i, words.length);

        auto nextWord = i+1 < words.length
            ? words[i+1]
            : Word.init;

        // Get the current context
        auto context = words[0 .. i+1]
            .tail(ContextSize)
            .map!"a.word"
            .filter!"a.length"
            .array;

        // Update the entry model
        result ~= model.require(word.word, [])
            .updateEntry(context, nextWord);

    }

    return result;

}

string[] generate(ref MarkovModel model, int humor, int wordCount, string[] context = []) {

    auto list = getWordList();

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

        if (!uniform(0, 4)) stealWord();

        return entry.getBestItem(output, humor).nextWord.word;

    }

    string randomWord() {

        return humor >= 0
            ? list.positive[].choice
            : list.negative[].choice;

    }

    // Try to steal a word from the context for the start.
    stealWord();

    // Try getting the data
    while (pushedWords < wordCount) {

        // The more emotional, the higher should be the chance
        if (abs(humor) > uniform(0, HumorLimit * 3)) {

            // Pick a random word
            output ~= randomWord();

            pushedWords++;

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

            // Add a chance to skip a word
            if (uniform(0, 3) == 0) {

                auto newPart = getWord() in model;
                entry = newPart ? *newPart : *part;

            }

            continue;

        }

        // Found no words, try to use a random word
        if (auto part = randomWord() in model) {

            entry = *part;

        }

        // :(

    }

    return output.amplify(humor);

}

// Add
private string[] amplify(bool recursive = false)(string[] input, int humor) {

    string[] result;

    bool excl;
    int emotional = abs(humor);

    foreach (i, word; input) {

        // Capitalize first word, unless sad
        if (i == 0 && humor > -HumorLimit/3) word = word.asCapitalized.to!string;

        // Got an empty word
        if (word == "") {

            // Ignore if it's the first word
            if (result.length == 0) continue;

            // Ignore if the last word already ends with punctuation
            if (!result[$-1][$-1].isAlphaNum) continue;

            // Add a comma (or dot, if last) to the previous word
            result[$-1] ~= i+1 == input.length
                ? "."
                : ",";

            // Skip it, don't add it
            continue;

        }

        result ~= "";

        const scream = uniform(HumorLimit/3, HumorLimit * 3/2) <= emotional;
        const scramble = uniform(2, 10);

        // Add letter by letter
        foreach (letter; word) {

            // Found an exclamation mark
            if (letter == '!') excl = true;

            // Screaming!
            if (scream && uniform(0, 5) <= scramble) {

                result[$-1] ~= letter.toUpper;

            }

            else result[$-1] ~= letter;

        }

    }

    // AMPLIFY FURTHER!
    if (excl && recursive) return amplify!false(result, humor);

    return result;

}

private MarkovItem getBestItem(ref MarkovEntry entry, string[] context, int humor) {

    auto sorted = entry.schwartzSort!(
        (MarkovItem a) => log2(a.occurences.get(context, 0))
            * (HumorLimit + a.nextWord.sentiment * humor)
            * setIntersection(a.before[], context.sort.filter!"a.length").walkLength,
        "a > b"
    );

    if (context.length)
    return sorted
        .take(WorstFit)
        .array
        .randomShuffle
        .front;

    return sorted.randomShuffle.front;

}

/// Update the entry in the model.
/// Returns: The most common phrase, which is a substring of context, occuring within the model.
private Phrase updateEntry(ref MarkovEntry entry, string[] context, Word nextWord)
in (context.all!"a.length", "updateEntry context cannot have empty words")
do {

    // Full text chain, including the next word
    auto chain = context ~ nextWord.word;

    // Find an item with a matching context
    foreach (ref item; entry) {

        if (nextWord != item.nextWord) continue;

        item.before.insert(context);

        // Find the most frequent substring
        Phrase best;
        foreach (i; 0..chain.length) {

            const count = ++item.occurences.require(context[i..$], 0);

            // Found the new king
            // Note, we're taking a small number because the next word will always have >= occurences
            if (count*1/4 > best.occurences) best = Phrase(chain[i..$], count);

        }
        return best;

    }

    // Didn't find any, add one
    auto item = MarkovItem(nextWord, redBlackTree(context), [context: 1]);
    entry ~= item;

    return Phrase(chain, 1);

}
