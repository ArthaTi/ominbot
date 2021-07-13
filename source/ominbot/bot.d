module ominbot.bot;

import std.conv;
import std.array;
import std.ascii;
import std.range;
import std.string;
import std.random;
import std.algorithm;

import ominbot.markov;
import ominbot.params;
import ominbot.word_lists;

struct Ominbot {

    alias MessageSentiment = LimitInt!(-3, 3);

    MarkovModel model;

    // Current params
    LimitInt!(-HumorLimit, HumorLimit) humor;
    int replyRarity = InitialReplyRarity;
    auto channelList = ChannelList.dup;
    bool forceImage;
    bool longerSentences;

    /// Load data into the bot.
    void load(const string data) {

        model.feed(getNouns(data));

    }

    /// Load data into the bot and save it for future.
    MessageSentiment feed(string data, void delegate(ulong) pinged = null) {

        import std.file : append;

        MessageSentiment inputSentiment;

        // Feed the model
        model.feed(getNouns(data, inputSentiment, pinged));

        // Add to corpus
        append("resources/bot-corpus.txt", data.strip ~ "\n");

        return inputSentiment;

    }

    /// Wake the bot up and request a response.
    string[] statusUpdate(string context = "") {

        auto words = context.length
            ?  getNouns(context)
                .map!"a.word"
                .array
            : [];

        const wordCount = longerSentences
            ? uniform!"[]"(MaxWords, MaxBoostedWords)
            : uniform!"[]"(MinWords, MaxWords);

        return model.generate(humor, wordCount, words);

    }

    private Word[] getNouns(string data, void delegate(ulong) pinged = null) {

        MessageSentiment ignore;
        return getNouns(data, ignore, pinged);

    }

    private Word[] getNouns(string data, out MessageSentiment inputSentiment, void delegate(ulong) pinged = null) {

        const list = getWordList();

        Word[] nouns;
        string key;

        void pushWord() {

            string marks;

            // Find pings
            if (auto id = isPing(key)) {

                // Trigger the signal if pinged
                if (pinged) pinged(id);

                // Do not put pings in the model
                return;

            }

            // Regular words
            else key = key
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

                    // Ping! Don't end yet
                    if (key == "<@!") break;

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

        return nouns;

    }

    private ulong isPing(string text) const {

        string inner = text
            .chompPrefix("<@")
            .chompPrefix("!")
            .chomp(">");

        // Check if all the characters were removed
        const removed = text.length - inner.length;

        if (removed != 3 && removed != 4) return 0;

        // Check if it holds a number
        try return inner.to!ulong;
        catch (ConvException) return 0;

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
