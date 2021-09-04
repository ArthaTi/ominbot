module ominbot.core.bot;

import std.stdio;
import std.datetime;

import ominbot.launcher;

import ominbot.core.map;
import ominbot.core.params;

static this() {

    // Load the bot in
    OminbotLoader.loadBot(new Ominbot);

}

final class Ominbot : Bot {

    SysTime lastEvent;
    RelationMap!mapHeight map;

    this() {

        map = new RelationMap!mapHeight;

    }

    override void pushEvent(Event event) {

        map.feed(event.messageText);

    }

    override void requestResponse() {



    }

    override Event[] poll() {

        const time = Clock.currTime;

        if (time > lastEvent + 5.seconds) {

            lastEvent = time;
            writefln!"updating...";

        }

        return [];

    }

}
