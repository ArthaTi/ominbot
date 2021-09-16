module ominbot.core.params;

import core.time;

/// Limit of phrases within a single relation group.
enum groupSizeLimit = 10;

/// Number phrases to keep within the original group on split.
enum groupSplitKeep = 6;

enum maxLookupDistance = 100;

/// Minimum and maximum number of words for a single sentence. Note: The max might still be crossed by omin, given high
/// enough `fetchGroupRepeat` and `fetchGroupMax` values
enum fetchPhrasesMin = 2, fetchPhrasesMax = 5;

/// Chance to fetch more than one word from a single group.
enum fetchGroupRepeat = 1/4;

/// Max words to fetch from a single group.
enum fetchGroupMax = 3;

/// Disable fetching from the given group for the given time after it has been used.
enum fetchGroupDisableFor = 2.hours;

/// URL address for the `public/` directory where Omin will place images and data dumps.
debug enum publicURL = "http://localhost";
else  enum publicURL = "https://omin.samerion.com";
