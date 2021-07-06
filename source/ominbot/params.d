module ominbot.params;

import std.datetime;

enum ContextSize = 3;
enum MinWords = 2;
enum MaxWords = 5;
enum Precision = 5;
enum HumorLimit = 25;
enum RandomEventFrequency = 5.minutes;

// Note: lower values give a higher chance.
enum InitialReplyRarity = 50;
enum BoostedReplyRarity = 10;

enum ImagePostingRarity = 100;
enum ImageEditOwnRarity = 5;  // Rarity of editing own image output
enum ImageMinForegroundItems = 0;
enum ImageMaxForegroundItems = 3;
enum ImageOutputPath = "resources/bot-output.png";
