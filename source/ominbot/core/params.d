module ominbot.core.params;

import core.time;

/// General Omin options
public {

    /// A value from 0 to 255 determining how greatly events should affect Omin's mood.
    enum ubyte moodChangeIntensity = 15;

    /// URL address for the `public/` directory where Omin will place images and data dumps.
    debug enum publicURL = "http://localhost";
    else  enum publicURL = "https://omin.samerion.com";

}

/// Options applying to the Markov chain model.
public {

    /// Number of words to hold in the context.
    enum contextSize = 3;

    /// The bot will only consider the top N model entries for the given leading word.
    enum worstFit = 3;

    /// Minimum and maximum words the Markov can put in a single sentence. Note, the bot might still put less words than
    /// minumum if it finds no appropriate words to follow.
    enum markovWordsMin = 2, markovWordsMax = 5;

    /// Chance to skip a word — instead of inserting it in the model, continue to the next word.
    enum markovSkipWord = 1/3;

}

/// Options applying to the relation map model.
public {

    /// Limit of phrases within a single relation group.
    enum groupSizeLimit = 10;

    /// Number phrases to keep within the original group on split.
    enum groupSplitKeep = 6;

    enum maxLookupDistance = 100;

    /// Minimum and maximum number of words for a single sentence. Note: The max might still be crossed by omin, given
    /// high enough `fetchGroupRepeat` and `fetchGroupMax` values
    enum fetchPhrasesMin = 2, fetchPhrasesMax = 5;

    /// Chance to fetch more than one word from a single group.
    enum fetchGroupRepeat = 1/4;

    /// Max words to fetch from a single group.
    enum fetchGroupMax = 3;

    /// Disable fetching from the given group for the given time after it has been used.
    enum fetchGroupDisableFor = 2.hours;

}

/// Options for how emotions should work in Omin.
public {

    /// How much can a single word affect Omin's emotion pleasure axis.
    enum inputWordPleasure = 5;
    static assert(inputWordPleasure <= 255);

    /// How much can a single message affect Omin's emotions at most, ranging from 0–255.
    enum inputEmotionLimit = 25;
    static assert(inputEmotionLimit <= 255);

    /// Multiply the effect of the input in case it was a requested trigger (eg. omin was pinged). This will also extend
    /// the emotion limit for those. For example, if the multipler is `2` and the limit is `5`, for trigger messages the
    /// limit will be `10` instead.
    // TODO: not implemented
    enum triggerEmotionMultipler = 2;
    static assert(inputEmotionLimit * triggerEmotionMultipler <= 300);

}
