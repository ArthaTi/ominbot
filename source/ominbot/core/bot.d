module ominbot.core.bot;

import std.stdio;
import std.datetime;

import ominbot.launcher;

import ominbot.core.map;
import ominbot.core.params;
import ominbot.core.structs;
import ominbot.core.commands;


@safe:


static this() {

    // Load the bot in
    OminbotLoader.loadBot(new Ominbot);

}

final class Ominbot : Bot {

    SysTime lastEvent;
    RelationMap map;
    bool[ulong] admins;
    MapGroup[ulong] groups;
    Event[] eventQueue;

    this() {

        import std.file;

        map = new RelationMap;

        // Load the corpus
        //map.feed(map.root, readText("resources/bot-corpus.txt"));

    }

    override void pushEvent(Event event) {

        const admin = isAdmin(event.user);

        // Check for commands
        if (this.runCommands(event, admin)) return;

        // Get group for this channel
        auto group = groups.require(event.targetChannel, map.root);

        map.feed(group, event.messageText);

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

        return "";

        version (none) {

            const wordCount = uniform!"[]"(2, maxWords);

            string[] words;
            FetchOptions options;

            // Fill the word list
            while (words.length < wordCount) {

                options.minRadius = words.length;

                // Find new words
                if (auto word = map.fetch(options)) {

                    words ~= word.text;
                    options.encouraged   = word.following[0..5];
                    options.discouraged ~= word.text;

                }

                // No word found! Tragedy!
                else break;

            }

            // No words at all!
            if (words.length == 0) return "...";

            return words.join(" ");

        }

    }

    bool isAdmin(ulong id) {

        return admins.get(id, false);

    }

}
