module ominbot.params;

import std.datetime;

enum ContextSize = 3;
enum MinWords = 2;  // The bot will not always respect this field
enum MaxWords = 5;
enum WorstFit = 3;  // The bot will only consider top N matches for each word
enum HumorLimit = 25;
enum RandomEventFrequency = 5.minutes;

// Note: lower values give a higher chance.
enum InitialReplyRarity = 150;
enum ActiveReplyRarity = 20;
enum RestoreReplyRarityPerMinute = 30;

enum ImagePostingRarity = 120;
enum ImageEditOwnRarity = 5;  // Rarity of editing own image output
enum ImageMinForegroundItems = 0;
enum ImageMaxForegroundItems = 3;
enum ImageOutputPath = "resources/bot-output.png";

immutable channelList = [
    861611045537972275,  // private server
    742790712529125469,  // samerion #general
    772160498614665247,  // samerion #bots
    280298381807714304,  // #oman-pls-to-help
    325969983441993729,  // #bot-lemons
];
