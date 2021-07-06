module ominbot.main;

import dcord.core;
import vibe.core.core;

import std.conv;
import std.stdio;
import std.datetime;
import std.file : readText;

import ominbot.bot;
import ominbot.params;
import ominbot.discord;
import ominbot.random_event;

void main(string[] args) {

    Ominbot bot;

    const time = Clock.currTime;

    writefln!"Loading corpus...";

    // Load the corpus
    bot.load(readText("resources/bot-corpus.txt"));

    writefln!"Corpus loaded in %s"(Clock.currTime - time);

    bot.launchDiscord(args[1], args[2]);

}

void launchDiscord(ref Ominbot bot, string discordToken, string imgBBToken) {

    BotConfig config;
    config.token = discordToken;
    config.cmdPrefix = "";

    auto plugin = new OminbotPlugin(bot);
    plugin.imgBBToken = imgBBToken;

    auto dscBot = new Bot(config, LogLevel.trace);
    dscBot.loadPlugin(plugin);
    dscBot.run();
    runEventLoop();

}

void launchCLI(ref Ominbot bot) {

    auto time = Clock.currTime;
    char[] input;

    while (true) {

        writef!"%+3d> "(bot.humor);

        if (!input.readln) break;

        auto inputString = input.to!string;

        // Feed data to the bot
        bot.feed(inputString);

        // Respond
        bot.statusUpdate(inputString).writeln();

        // If 5 or more minutes passed
        if (Clock.currTime > time + RandomEventFrequency) {

            // Run a random event
            auto result = bot.runRandomEvent;

            // Update the time
            time = Clock.currTime;

            // Output the result
            if (result.length) writeln(result);

        }

    }

}
