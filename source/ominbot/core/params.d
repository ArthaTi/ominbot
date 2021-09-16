module ominbot.core.params;

/// Limit of phrases within a single relation group.
enum groupSizeLimit = 10;

/// Number phrases to keep within the original group on split.
enum groupSplitKeep = 6;

enum maxLookupDistance = 100;

/// Max word count for a single sentence
enum maxWords = 5;

/// URL address for the `public/` directory where Omin will place images and data dumps.
debug enum publicURL = "http://localhost";
else  enum publicURL = "https://omin.samerion.com";
