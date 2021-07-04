module ominbot.main;

import std.conv;
import std.stdio;
import std.datetime;
import std.file : readText;

import ominbot.bot;

void main() {

    Ominbot bot;

    auto time = Clock.currTime;

    writefln!"Loading corpus...";

    // Load the corpus
    bot.load(readText("resources/bot-corpus.txt"));

    writefln!"Corpus loaded in %s"(Clock.currTime - time);

    char[] input;

    while (true) {

        writef!"%+3d> "(bot.humor);

        if (!input.readln) break;

        auto inputString = input.to!string;

        // Feed data to the bot
        bot.feed(inputString);

        // Respond
        bot.statusUpdate(inputString).writeln();

    }

}
