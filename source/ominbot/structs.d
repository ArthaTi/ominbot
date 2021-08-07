module ominbot.structs;

import std.algorithm;

import ominbot.markov;

alias MessageSentiment = LimitInt!(-3, 3);

struct FeedingResult {  // also called "shit"

    /// Sentiment of the given message.
    MessageSentiment sentiment;

    /// Frequently used phrases which appear in this message.
    Phrase[] phrases;

}

struct Phrase {

    /// Words in the phrase.
    string[] words;

    /// Number of occurences of the phrase.
    size_t occurences;

}

struct LimitInt(int min, int max) {

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
