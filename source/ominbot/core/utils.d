module ominbot.core.utils;

import ominbot.core.emotions;

/// Make the text partially uppercase based on mood.
string[] amplify(bool recursive = true)(const string[] input, Emotions emotions) {

    import std.uni, std.conv;
    import std.range, std.random;

    const pleasure = emotions.pleasure;
    const activation = emotions.activation;

    /// Capitalize the words unless inactive or happy.
    const capitalize = activation > -60 * (1 + pleasure / 255);

    /// Give a chance to convert dots to ellipsis if inactive.
    const makeEllipsis = activation < -60;

    string[] result;

    bool sentenceStart = true;
    bool excl = false;

    eachWord: foreach (i, string word; input) {

        // Capitalize first word, unless inactive
        if (sentenceStart && capitalize) word = word.asCapitalized.to!string;

        result ~= "";

        // Ignore the rest if the word is empty
        if (word.length == 0) continue;

        sentenceStart = false;

        const scream = uniform(255/3, 255 * 3/2) <= activation;
        const scramble = uniform(2, 10);

        // Add letter by letter
        eachLetter: foreach (dchar letter; word) {

            // Found an exclamation mark
            if (letter == '!') excl = true;

            // Found a dot which could be changed into an ellipsis
            else if (makeEllipsis && letter == '.' && result[$-1].back != '.') {

                const convertChance = 0.75 / (2 + pleasure/255.0);

                // Give a chance to convert it to ellipsis
                if (uniform01 < convertChance) {

                    result[$-1] ~= "...";

                    continue eachWord;

                }

            }


            // Found any punctuation
            if (letter.isPunctuation) {

                // Start a new sentence
                // Note: commas shouldn't be added yet at this point
                sentenceStart = true;

            }


            // Screaming!
            if (scream && uniform(0, 5) <= scramble) {

                result[$-1] ~= letter.toUpper;

            }

            else result[$-1] ~= letter;

        }

    }

    // AMPLIFY FURTHER!
    if (excl && recursive) return amplify!false(result, emotions);

    return result;

}
