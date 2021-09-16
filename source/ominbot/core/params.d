module ominbot.core.params;

/// Limit of phrases within a single relation group.
enum groupSizeLimit = 10;

/// Number phrases to keep within the original group on split.
enum groupSplitKeep = 6;

enum maxLookupDistance = 100;

/// Minimum and maximum number of words for a single sentence.
enum fetchWordsMin = 2, fetchWordsMax = 10;

/// Chance to fetch more than one word from a single group.
enum fetchGroupRepeat = 1/4;

/// Max words to fetch from a single group.
enum fetchGroupMax = 3;

/// URL address for the `public/` directory where Omin will place images and data dumps.
debug enum publicURL = "http://localhost";
else  enum publicURL = "https://omin.samerion.com";
