module ominbot.structs;

import std.algorithm;

alias MessageSentiment = LimitInt!(-3, 3);

struct FeedingResult {  // also called "shit"

    MessageSentiment sentiment;

    /// Frequently used phrases which appear in this message.
    Phrase[] phrases;

}

/// Marks a frequent phrase.
struct Phrase {

    /// Words in the phrase.
    string[] words;

    /// Weight of the phrase.
    size_t weight;

}

struct LimitInt(int min, int max) {

    enum minValue = min;
    enum maxValue = max;

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
