module ominbot.core.params;

import core.time;

/// General Omin options
public {

    /// URL address for the `public/` directory where Omin will place images and data dumps.
    debug enum publicURL = "http://localhost";
    else  enum publicURL = "https://omin.samerion.com";

}

/// Options applying to the Markov chain model.
public {

    /// Number of words to hold in the context.
    enum contextSize = 3;

    /// Humor values limit. If this value is set to, for example, 50, Omin's humor could range from -50 to 50.
    enum humorLimit = 50;

    /// The bot will only consider the top N model entries for the given leading word.
    enum worstFit = 3;

    /// Minimum and maximum words the Markov can put in a single sentence. Note, the bot might still put less words than
    /// minumum if it finds no appropriate words to follow.
    enum markovWordsMin = 2, markovWordsMax = 5;

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
