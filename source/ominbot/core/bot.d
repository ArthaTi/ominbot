module ominbot.core.bot;

import std.array;
import std.stdio;
import std.random;
import std.datetime;

import ominbot.launcher;

import ominbot.core.map;
import ominbot.core.events;
import ominbot.core.markov;
import ominbot.core.params;
import ominbot.core.structs;
import ominbot.core.commands;
import ominbot.core.emotions;


@safe:

version = UseMarkov;


version (unittest) { }
else
shared static this() {

    // Load the bot in
    OminbotLoader.loadBot(new Ominbot);

}

final class Ominbot : Bot {

    enum corpusPath = "resources/bot-corpus.txt";

    /// Bot data.
    public {

        /// Time of the last random event.
        SysTime lastRandomEvent;

        /// Admins of the bot.
        bool[ulong] admins;

        /// Currently queued events to return when polling.
        Event[] eventQueue;

        /// Bot's current logger instance.
        Logger logger;

    }

    /// Bot status.
    public {

        /// Number of events received since last event, per *server*.
        size_t[ulong] inputQuantity;

        /// Current bot emotions per *server*.
        Emotions[ulong] emotions;

        /// Active relationship map groups per *channel*.
        MapGroup[ulong] groups;

    }

    // Models
    public {

        /// The relationship map model.
        RelationMap map;

        /// Markov model.
        shared MarkovModel markov;

    }

    this() {

        import std.file : readText;

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

    override void pushEvent(Event event, bool requestResponse) {

        import std.file : append;
        import std.string : stripRight;

        const admin = isAdmin(event.user);

        // Pre-process the event
        event.messageText = event.messageText.stripRight;

        // Count the activity.
        inputQuantity.require(event.targetServer, 0) += 1;


        // Check for commands
        if (this.runCommands(event, admin)) return;

        // Check for response requests
        else if (requestResponse) makeResponse(event, requestResponse);

        // Make random responses
        else if (uniform01 < responseChance) makeResponse(event, requestResponse);


        // Push the data to the corpus file
        append(corpusPath, event.messageText ~ "\n");

        // Feed the markov model
        version (UseMarkov) {

            () @trusted {

                import std.conv, std.algorithm;

                // Feed the model
                const sentiment = inputWordPleasure * markov.feed(event.messageText, cast(shared) this);

                // Limit the resulting sentiment
                const clamped = sentiment
                    .clamp(-inputEmotionLimit, inputEmotionLimit)
                    .to!short;

                // Update Omin's emotions
                emotions.require(event.targetServer).move(clamped, 0);

            }();

        }

        // Get group for this channel
        else if (auto group = event.targetChannel in groups) {

            // Feed data relative to that group
            *group = map.feed(*group, event.messageText);

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

    /// Prepare a response for the event.
    /// Params:
    ///     input = Request event.
    ///     random = If true, the response is random, not requested by the user.
    void makeResponse(Event input, bool requested) {

        const chance = requested
            ? triggerImageChance
            : randomImageChance;

        Event output = input;
        scope (success) eventQueue ~= output;

        // Give a chance to make an image
        if (uniform01 < chance) {

            output.messageText = makeImage(input);

        }

        // Send a response
        else output.messageText = makeMessage(input).join(" ");

    }

    override Event[] poll() {

        import std.conv, std.algorithm;

        const time = Clock.currTime;

        // Check for random events
        if (time > lastRandomEvent + randomEventFrequency) {

            lastRandomEvent = time;

            // Run a random event
            events.choice()(this);

            // Check input quantity
            foreach (server, ref activity; inputQuantity) {

                const emotionValue = inputEventInitialActivation + inputEventActivation * activity.to!ptrdiff_t;
                const emotionChange = min(emotionValue, inputEventEmotionLimit).to!short;

                // Update emotions
                emotions.require(server, Emotions.init)
                    .move(0, emotionChange);

                import std.stdio;
                debug writefln!"emotion update activity(%s) : emotion(%s) -> %s"(activity, emotionChange,
                    emotions[server]);

                // Reset the activity
                activity = 0;

            }

        }

        // Move events from the queue to the result.
        auto events = eventQueue;
        eventQueue = null;

        return events;

    }

    override void setAdmin(ulong id) {

        admins[id] = true;

    }

    string makeImage(Event event) {

        import dlib.image;
        import ominbot.core.image.meme;
        import std.path, std.file, std.string;

        auto topText = makeMessage(event);
        auto bottomText = makeMessage(event);

        // Perform the operation
        auto image = mutilateImage(topText, bottomText);

        // No image generated? Too bad...
        if (image is null) return null;

        // Get the path to save to
        const outputPath = "public/img";
        outputPath.mkdirRecurse;

        const outputName = format!"output-%s.png"(Clock.currTime.toUnixTime);
        const outputFile = outputPath.buildPath(outputName);

        () @trusted {

            image.savePNG(outputFile);

        }();

        return publicURL.buildPath("img", outputName);

    }

    string[] makeMessage(Event event) {

        version (UseMarkov) {

            import ominbot.core.dictionary;
            import std.uni, std.string, std.algorithm;

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

                import ominbot.core.utils;

                synchronized (this) {

                    const emotion = emotions.get(event.targetServer, Emotions.init);
                    auto nmarkov = cast(MarkovModel) markov;

                    // Generate some text
                    const text = nmarkov.generate(
                        emotion.pleasure,
                        uniform!"[]"(markovWordsMin, markovWordsMax),
                        context
                    );

                    // Amplify it
                    return text.amplify(emotion);

                }

            }();

            return addCommas(markovResult)
                .filter!(a => a.length)
                .array;

        }

        else {

            import std.datetime;
            import std.range, std.algorithm;

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
        import std.range, std.algorithm;

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
