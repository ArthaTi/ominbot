module ominbot.main;

import std.conv;
import std.stdio;
import std.datetime;
import std.file : readText;

import ominbot.bot;
import ominbot.params;
import ominbot.random_event;

void main() {

    Ominbot bot;

    auto time = Clock.currTime;

    writefln!"Loading corpus...";

    // Load the corpus
    bot.load(readText("resources/bot-corpus.txt"));

    writefln!"Corpus loaded in %s"(Clock.currTime - time);

    // Start from a random event
    bot.runRandomEvent().writeln;

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
