module ominbot.core.bot;

import std.stdio;
import std.datetime;

import ominbot.launcher;

static this() {

    // Load the bot in
    OminbotLoader.loadBot(new Ominbot);

}

final class Ominbot : Bot {

    SysTime lastEvent;

    void get(string messageText, string author, string channel) {

    }

    Event[] poll() {

        const time = Clock.currTime;

        if (time > lastEvent + 5.seconds) {

            lastEvent = time;
            writefln!"updating...";

        }

        return [];

    }

}
