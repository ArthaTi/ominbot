module ominbot.core.bot;

import std.stdio;
import std.datetime;

import ominbot.launcher;

import ominbot.core.map;
import ominbot.core.params;
import ominbot.core.commands;


@safe:


static this() {

    // Load the bot in
    OminbotLoader.loadBot(new Ominbot);

}

final class Ominbot : Bot {

    SysTime lastEvent;
    RelationMap!mapHeight map;
    bool[ulong] admins;
    Event[] eventQueue;

    this() {

        map = new RelationMap!mapHeight;

    }

    override void pushEvent(Event event) {

        const admin = isAdmin(event.user);

        // Check for commands
        if (this.runCommands(event, admin)) return;

        map.feed(event.messageText);

    }

    override void requestResponse() {



    }

    override Event[] poll() {

        const time = Clock.currTime;

        if (time > lastEvent + 5.seconds) {

            lastEvent = time;
            // TODO

        }

        // Move events from the queue to the result.
        auto events = eventQueue;
        eventQueue = null;

        return events;

    }

    override void setAdmin(ulong id) {

        admins[id] = true;

    }

    bool isAdmin(ulong id) {

        return admins.get(id, false);

    }

}
