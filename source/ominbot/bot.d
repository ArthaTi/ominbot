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
import ominbot.structs;
import ominbot.word_lists;

struct Ominbot {

    MarkovModel model;

    // Current params
    LimitInt!(-HumorLimit, HumorLimit) humor;
    int replyRarity = InitialReplyRarity;
    auto channelList = ChannelList.dup;
    bool forceImage;
    string nextImageURL;
    bool longerSentences;

    /// Load data into the bot.
    void load(const string data) {

        model.feed(getNouns(data));

    }

    /// Load data into the bot and save it for future.
    FeedingResult feed(string data, void delegate(ulong) pinged = null) {

        import std.file : append;

        FeedingResult result;

        // Feed the model
        result.phrases = model.feed(getNouns(data, /*out*/ result.sentiment, pinged));

        // Add to corpus
        append("resources/bot-corpus.txt", data.strip ~ "\n");

        return result;

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

            // Collect nouns
            if (word.noun) {

                // If there are marks
                if (marks.length) {

                    // Add them
                    word.word ~= marks;

                    // Add the word and add an empty word after
                    nouns ~= [word, Word.init];


                }

                else nouns ~= word;

            }

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
