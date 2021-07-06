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

enum ImagePostingRarity = 3;
enum ImageEditOwnRarity = 5;  // Rarity of editing own image output
enum ImageOutputPath = "resources/bot-output.png";
