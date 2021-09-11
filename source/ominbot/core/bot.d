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

        import std.file;

        map = new RelationMap!mapHeight;

        // Load the corpus
        map.feed(readText("resources/bot-corpus.txt"));

    }

    override void pushEvent(Event event) {

        const admin = isAdmin(event.user);

        // Check for commands
        if (this.runCommands(event, admin)) return;

        map.feed(event.messageText);

    }

    override void requestResponse() {

        // TODO: choose a reasonable channel
        eventQueue ~= Event(0, 1, 1, makeMessage);

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

    string makeMessage() {

        import std.array, std.random;

        const wordCount = uniform!"[]"(2, maxWords);

        string[] words;

        while (words.length < wordCount) {

            if (auto word = map.fetch(words.length)) {

                words ~= word.text;

            }

            // No word found! Tragedy!
            else break;

        }

        // No words at all!
        if (words.length == 0) return "...";

        return words.join(" ");

    }

    bool isAdmin(ulong id) {

        return admins.get(id, false);

    }

}
