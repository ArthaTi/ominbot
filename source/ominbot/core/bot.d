module ominbot.core.bot;

import std.stdio;
import std.random;
import std.datetime;

import ominbot.launcher;

import ominbot.core.map;
import ominbot.core.markov;
import ominbot.core.params;
import ominbot.core.structs;
import ominbot.core.commands;


@safe:

version = UseMarkov;


shared static this() {

    // Load the bot in
    OminbotLoader.loadBot(new Ominbot);

}

final class Ominbot : Bot {

    /// Bot data.
    public {

        SysTime lastEvent;
        bool[ulong] admins;
        MapGroup[ulong] groups;
        Event[] eventQueue;
        Logger logger;

    }

    // Models
    public {

        RelationMap map;
        shared MarkovModel markov;

    }

    this() {

        import std.file : readText;

        enum corpusPath = "resources/bot-corpus.txt";

        // Initialize fields
        this.map = new RelationMap;

        // Load the model
        version (UseMarkov) {

            import std.concurrency;

            logger.loading("markov model", 0);

            () @trusted {

                // Load the Markov model in the background
                spawn(function(shared Ominbot bot) {

                    bot.markov.feed(File(corpusPath), bot, cast() bot.logger);

                }, cast(shared) this);

            }();

        }

        // Old relationship map model
        else {

            logger.loading("relationship map model", 0);

            auto corpus = fs.readText();
            map.feed(map.root, corpusPath.readText);

        }

    }

    override void pushEvent(Event event) {

        const admin = isAdmin(event.user);

        // Check for commands
        if (this.runCommands(event, admin)) return;

        // Get group for this channel
        if (auto group = event.targetChannel in groups) {

            // Feed the model
            version (UseMarkov) {

                synchronized (this) () @trusted {

                    markov.feed(event.messageText, cast(shared) this);

                }();

            }

            // Feed data relative to that group
            else *group = map.feed(*group, event.messageText);

        }

        // Group not found, insert from root
        else groups[event.targetChannel] = map.feed(map.groups.choice, event.messageText);

    }

    /// Update the callback.
    override void progressCallback(typeof(Logger.progressCallback) cb) {

        logger.progressCallback = cb;

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

        version (UseMarkov) {

            import ominbot.core.dictionary;
            import std.uni, std.array, std.string, std.algorithm;

            auto dict = getDictionary;
            auto context = dict.splitWords(event.messageText)
                .map!"a.word".array;

            string[] addCommas(string[] arr) {

                foreach (i, ref word; arr[0 .. $-1]) {

                    // Ignore empty words
                    if (word.length == 0) continue;

                    // Ignore words with punctuation
                    if (word.back.isPunctuation) continue;

                    // If the next word is empty
                    if (arr[i+1].length == 0) {

                        // Append a comma
                        word ~= ",";

                    }

                }

                return arr;

            }

            auto markovResult = () @trusted {

                synchronized (this) {

                    auto nmarkov = cast(MarkovModel) markov;
                    return nmarkov.generate(0, uniform!"[]"(markovWordsMin, markovWordsMax), context);

                }

            }();

            return addCommas(markovResult)
                .filter!(a => a.length)
                .join(" ");

        }

        else {

            import std.datetime;
            import std.array, std.range, std.algorithm;

            // Get target word count
            const wordCount = uniform!"[]"(fetchPhrasesMin, fetchPhrasesMax);

            // Get the target group
            auto group = groups.get(event.targetChannel, map.groups.choice);

            MapEntry[] output;
            MapGroup lastGroup;

            // Fill the word list
            while (output.length < wordCount) {

                // Attempt matching frequently appearing phrases at first
                if (!findFollowingPhrases(output, group)) {

                    // Then search for relations
                    findRelatedPhrases(output, group);

                }

            }

            // Update the group
            groups[event.targetChannel] = group;

            return output.length ? output.map!"a.text".join(" ") : "...";

        }

    }

    /// Lookup phrases to match the last chosen word
    private bool findFollowingPhrases(ref MapEntry[] phrases, ref MapGroup group) {

        if (!phrases.length) return false;

        auto result = group.findRelated(phrases[$-1].following[0..5].dup.randomShuffle, true);

        // Found the group
        if (result[0]) {

            group = result[0];
            group.lastUsage = Clock.currTime;

            // Push the word
            phrases ~= result[1];

            return true;

        }

        return false;

    }

    /// Find possibly related phrases
    private bool findRelatedPhrases(ref MapEntry[] phrases, ref MapGroup group) {

        import std.uni;
        import std.array, std.range, std.algorithm;

        float distance = 0;

        // Get a random enabled group
        auto groups = group.searchRelated
            .tee!(a => distance += 1)
            .filter!(a => !a.disabled)
            .take(groupSizeLimit);

        // No phrases in here, stop!
        if (groups.empty) {

            empty:

            // Send a message to inform the user
            if (phrases.length == 0) phrases ~= MapEntry("zzz");
            // TODO enter sleep mode...
            // chance of this approaches zero as the model size grows... probably no need to worry about this

            return false;

        }

        // Try to get random neighbours until found
        auto previousGroup = group;
        group = groups.array.choice;
        group.lastUsage = Clock.currTime;

        // Group empty? oh no.
        if (group.entries.length == 0) goto empty;

        // Get a couple phrases from the group
        auto groupPhraseCount = 1;

        // Increment word count until
        while (true) {

            // Proceed only if random conditions is satisfied
            if (uniform01 > fetchGroupRepeat) break;

            // Don't add more phrases than allowed per group
            if (groupPhraseCount == fetchGroupMax) break;

            // Don't add more phrases than available within the group
            if (groupPhraseCount == group.entries.length) break;

            groupPhraseCount++;

        }

        // If the previous word has no punctuation
        if (phrases.length && !phrases[$-1].text.back.isPunctuation) {

            float commaChance = 1 - distance/maxLookupDistance;

            // Give a chance to add a comma to that word
            if (uniform01 < commaChance) phrases[$-1].text ~= ",";

        }

        phrases ~= group.entries.dup
            .partialShuffle(groupPhraseCount)
            .take(groupPhraseCount)
            .array;

        return true;

    }

    bool isAdmin(ulong id) {

        return admins.get(id, false);

    }

}
