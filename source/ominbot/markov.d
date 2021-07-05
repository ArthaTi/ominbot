module ominbot.markov;

import std.uni;
import std.conv;
import std.math;
import std.array;
import std.stdio;
import std.range;
import std.random;
import std.algorithm;

import ominbot.params;
import ominbot.word_lists;

struct MarkovItem {

    string[] context;
    uint occurences;
    Word nextWord;

}

alias MarkovEntry = MarkovItem[];
alias MarkovModel = MarkovEntry[string];

// Note: empty word is treated as sentence end.

void feed(ref MarkovModel model, Word[] words) {

    if (words.length == 0) return;

    model.require("", []).updateEntry([], words[0]);

    foreach (i, word; words) {

        if (i && i % 100_000 == 0) writefln!"Building model: %s words out of %s"(i, words.length);

        auto nextWord = i+1 < words.length
            ? words[i+1]
            : Word.init;

        // Ignore empty words
        if (nextWord.word == "") continue;

        const context = words[0 .. i+1]
            .tail(ContextSize)
            .map!"a.word"
            .array;

        model.require(word.word, []).updateEntry(context, nextWord);

    }

}

string generate(ref MarkovModel model, int humor, string[] context = []) {

    auto list = getWordList();

    string[] output;

    auto entry = (context.length && uniform(0, 2))
        ? model.get(context.choice, model[""])
        : model[""];

    string getWord() {

        return entry.getBestItem(output, humor).nextWord.word;

    }

    string randomWord() {

        if     (humor >= 0) return list.positive[].choice;
        else if (humor < 0) return list.negative[].choice;
        else assert(false);

    }

    while (output.length < MinWords || output.length <= uniform(0, MaxWords)) {

        // The more emotional, the higher should be the chance
        if (abs(humor) > uniform(0, HumorLimit * 2)) {

            // Pick a random word
            output ~= randomWord();

        }

        // Otherwise trigger markov
        else output ~= getWord();

        // Make a random chance to add a word from the context to the model
        if (context.length && uniform(0, 4) == 0) {

            if (auto part = context.choice in model) {

                entry = *part;
                continue;

            }

        }

        // Add to context
        if (auto part = output[$-1] in model) {

            entry = *part;

            // Add a chance to skip a word
            if (uniform(0, 3) == 0) {

                auto newPart = getWord() in model;
                entry = newPart ? *newPart : *part;

            }

        }

        // Found no words, try to use a random word
        else if (auto part = randomWord() in model) {

            entry = *part;

        }

        else break;

    }

    return output.amplify(humor).join(" ");

}

// Add
private string[] amplify(bool recursive = false, T)(T input, int humor)
if (isInputRange!T) {

    string[] result;

    bool excl;
    int emotional = abs(humor);

    foreach (i, word; input) {

        // Capitalize first word, unless sad
        if (i == 0 && humor > -HumorLimit/3) word = word.asCapitalized.to!string;

        result ~= "";

        const scream = uniform(HumorLimit/3, HumorLimit * 3/2) <= emotional;
        const scramble = uniform(2, 10);

        // Add letter by letter
        foreach (letter; word) {

            // Found an exclamation mark
            if (letter == '!') excl = true;

            // Screaming!
            else if (scream && uniform(0, 5) <= scramble) {

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
        (MarkovItem a) => log2(a.occurences)
            * (HumorLimit  + a.nextWord.sentiment * humor)
            * (ContextSize - levenshteinDistance(a.context, context)),
        "a > b"
    );

    if (context.length)
    return sorted
        .take(Precision)
        .array
        .randomShuffle
        .front;

    return sorted.randomShuffle.front;

}

private void updateEntry(ref MarkovEntry entry, const string[] context, Word nextWord) {

    bool found;

    // Find an item with a matching context
    foreach (ref item; entry) {

        if (nextWord != item.nextWord && context != item.context) continue;

        found = true;
        //item.occurences += 1;
        break;

    }

    // Didn't find any, add one
    if (!found) {

        entry ~= MarkovItem(context.dup, 1, nextWord);

    }

}
