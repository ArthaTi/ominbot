module ominbot.params;

import std.datetime;

enum BotOwner = 366675056979476480;

enum ContextSize = 3;
enum MinWords = 2;  // The bot will not always respect this field
enum MaxWords = 5;
enum MaxBoostedWords = 30;
enum BoostRarity = 100;
enum WorstFit = 6;  // The bot will only consider top N matches for each word
enum HumorLimit = 50;
enum RandomEventFrequency = 120.minutes;

// Note: lower values give a higher chance.
enum InitialReplyRarity = 600;
enum ActiveReplyRarity = 200;
enum RestoreReplyRarityPerMinute = 50;

enum ImagePostingRarity = 100;
enum ImageMaxFrequencyBoost = 10;  // Send images up to N times more frequently on random responses (if close to initial
                                   // reply rarity)
enum ImageEditOwnRarity = 5;    // Rarity of editing own image output
enum ImageMinForegroundItems = 1;
enum ImageMaxForegroundItems = 3;
enum ImageOutputPath = "resources/bot-output.png";

enum ChannelList = [
    861611045537972275,  // private server
    742790712529125469,  // samerion #general
    772160498614665247,  // samerion #bots
    280298381807714304,  // #oman-pls-to-help
    325969983441993729,  // #bot-lemons
];
