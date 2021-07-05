module ominbot.bot;

import std.conv;
import std.array;
import std.ascii;
import std.range;
import std.string;
import std.algorithm;

import ominbot.markov;
import ominbot.params;
import ominbot.word_lists;

struct Ominbot {

    MarkovModel model;
    LimitInt!(-HumorLimit, HumorLimit) humor;

    /// Load data into the bot.
    void load(const string data) {

        model.feed(getNouns(data));

    }

    /// Load data into the bot and save it for future.
    void feed(const string data) {

        import std.file : append;

        // Feed the model
        load(data);

        // Add to corpus
        append("resources/bot-corpus.txt", data.strip ~ "\n");

    }

    /// Wake the bot up and request a response.
    string statusUpdate(string context = "") {

        auto words = context.length
            ?  getNouns!3(context)
                .map!"a.word"
                .array
            : [];

        return model.generate(humor, words);

    }

    private Word[] getNouns(int sentimentLimit = 0)(string data) {

        const list = getWordList();

        Word[] nouns;
        string key;

        LimitInt!(-sentimentLimit, sentimentLimit) inputSentiment;

        void pushWord() {

            string marks;

            key = key
                .tee!(a => marks ~= "?!‽".canFind(a) ? a.to!string : "")
                .filter!isAlphaNum
                .to!string
                .toLower;

            if (!key.length) return;

            auto word = list.findWord(key);

            // Update sentiment
            inputSentiment += word.sentiment;

            // Add marks
            word.word ~= marks;

            // Collect nouns
            if (word.noun) nouns ~= word;

            // Reset the key
            key = "";

        }

        void pushSentence() {

            pushWord();

            if (nouns.length && nouns[$-1] != Word.init) {

                nouns ~= Word.init;

            }

        }

        foreach (i, ch; data) {

            switch (ch) {

                // End of word
                case ' ':
                    pushWord();
                    break;

                // Question/exclamation mark, add to word and end sentence
                case '?', '!', '‽':
                    key ~= ch;

                // End of sentence
                case '\n':
                case '.', ',':

                    pushSentence();
                    break;

                default:
                    key ~= ch;

            }

        }

        pushSentence();

        humor += inputSentiment;

        return nouns;

    }

}

private struct LimitInt(int min, int max) {

    // Note: does not handle overflows

    int value;
    alias value this;

    void opAssign(int other) {

        value = clamp(other, min, max);

    }

    void opOpAssign(string op : "+")(int other) {

        this = value + other;

    }

    void opOpAssign(string op : "-")(int other) {

        this = value - other;

    }

    unittest {

        LimitInt!(-3, 3) myInt;
        myInt += 30;
        assert(myInt == 3);

    }

}
