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
        map.feed(map.root, readText("resources/bot-corpus.txt"));

    }

    override void pushEvent(Event event) {

        const admin = isAdmin(event.user);

        // Check for commands
        if (this.runCommands(event, admin)) return;

        // Get group for this channel
        if (auto group = event.targetChannel in groups) {

            // Feed data relative to that group
            *group = map.feed(*group, event.messageText);

        }

        // Group not found, insert from root
        else groups[event.targetChannel] = map.feed(map.root, event.messageText);

    }

    override void pushCommand(Event event, string[] argv) {

        const admin = isAdmin(event.user);

        this.runCommands(event, argv, admin);

    }

    override void requestResponse(Event event) {

        // Send a response
        event.messageText = makeMessage(event);
        eventQueue ~= event;

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

    string makeMessage(Event event) {

        import std.array, std.range, std.random, std.algorithm;

        // Get target word count
        const wordCount = uniform!"[]"(fetchWordsMin, fetchWordsMax);

        // Get the target group
        auto group = groups.get(event.targetChannel, map.root);

        string[] words;
        MapGroup lastGroup;

        // Fill the word list
        while (words.length < wordCount) {

            auto relations = group.relatedExcept(lastGroup).array;
            const changeGroup = relations.length != 0;

            // Find another group
            if (changeGroup) {

                auto thisGroup = group;
                group = relations.choice;
                lastGroup = thisGroup;

            }

            const addWords = group.entries.length != 0;

            // Ignore empty groups
            if (addWords) {

                // Get a couple words from the group
                auto groupWordCount = 1;

                // Increment word count until
                while (true) {

                    // Proceed only if random conditions is satisfied
                    if (uniform01 > fetchGroupRepeat) break;

                    // Prevent adding more words than necessary
                    if (words.length + groupWordCount > wordCount) break;

                    // Don't add more words than allowed per group
                    if (groupWordCount == fetchGroupMax) break;

                    // Don't add more words than available within the group
                    if (groupWordCount == group.entries.length) break;

                    groupWordCount++;

                }

                words ~= group.entries.dup
                    .partialShuffle(groupWordCount)
                    .take(groupWordCount)
                    .map!(a => a.text)
                    .array;

            }

            // Couldn't change the group
            if (!changeGroup) {

                // There are no words to choose from, restore last group
                if (!addWords && lastGroup) group = lastGroup;

                break;

            }

        }

        // Update the group
        groups[event.targetChannel] = group;

        return words.length ? words.join(" ") : "...";

    }

    bool isAdmin(ulong id) {

        return admins.get(id, false);

    }

}
