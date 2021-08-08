module ominbot.discord;

import dcord.core;
import vibe.core.core;
import vibe.http.client;
import vibe.inet.urltransfer;

import std.stdio;
import std.range;
import std.format;
import std.random;
import std.string;
import std.algorithm;
import std.container;

import ominbot.bot;
import ominbot.image;
import ominbot.params;
import ominbot.structs;
import ominbot.commands;
import ominbot.random_event;

class OminbotPlugin : Plugin {

    Ominbot* bot;
    string imgBBToken;

    auto activeChannels = redBlackTree!long;

    this(ref Ominbot bot) {

        this.bot = &bot;

        // Every minute reduce bot post rarity
        setTimer(1.minutes, {

            bot.replyRarity = min(InitialReplyRarity, bot.replyRarity + RestoreReplyRarityPerMinute);

        }, true);

        // Trigger a random event once in 5 minutes
        setTimer(5.minutes, {

            auto content = bot.runRandomEvent();

            // If a message was generated and there is a channel available
            if (!content) return;
            if (activeChannels.empty) return;

            // Get some channel
            const channel = activeChannels.removeAny;

            // Make sure the channel is in the list
            if (!bot.channelList.canFind(channel)) return;

            // Send the resulting message
            client.api.channelsMessagesCreate(channel, content, null, false, null);

        }, true);

    }

    @Listener!(MessageCreate)
    void messageCreated(MessageCreate event) {

        // Ignore own messages
        if (event.message.author.id == me.id) return;

        // Try to run commands if it's the bot owner, force send if true
        const ranCommand = event.message.author.id == BotOwner
            && bot.runCommands(event.message.content, event.message.channel.id);

        bool forceSend = ranCommand;

        // Make sure the channel is in the list
        if (!bot.channelList.canFind(event.message.channel.id)) return;

        // Enable events for this channel
        activeChannels.insert(event.message.channel.id);

        // Feed the bot
        auto input = bot.feed(event.message.content, (ulong id) {

            // Pinged!
            if (id != me.id) return;

            forceSend = true;

        });

        // Update the sentiment
        bot.humor += input.sentiment * (forceSend ? 2 : 1);

        // Max occurency count of a phrase
        float maxOccurences;

        // Sort the phrases by priority
        auto bestPhrases = input.phrases
            .sort!((a, b) => a.occurences > b.occurences)
            .filter!(a => a.occurences > PhraseMinOccurences)
            .tee!(a => maxOccurences = max(a.occurences, maxOccurences))
            .array;

        // Remove relatively low quality phrases
        bestPhrases = bestPhrases
            .filter!(a => a.occurences / maxOccurences >= MinRelativeOccurences)

            // Remove empty words and phrases
            .map!(a => Phrase(a.words.filter!"a.length".array, a.occurences))
            .filter!"a.words.length"
            .array;

        // If there is a png attached
        foreach (attachment; event.message.attachments) {

            // Only fetch pngs
            if (!attachment.filename.endsWith(".png")) continue;

            // Make sure it's at least somewhat usable
            if (attachment.width < 300 || attachment.height < 300) continue;

            // And not too big
            if (attachment.width > 1500 || attachment.height > 1500) continue;

            // Download the image
            download(attachment.url, format!"resources/bot-img-%s.png"(attachment.id));

            writefln!"downloaded image %s id %s"(attachment.filename, attachment.id);

        }

        writefln!"MessageCreate(%+3s): %s"(bot.humor, bot.replyRarity);

        // Trigger a reply
        if (forceSend || uniform(0, bot.replyRarity) == 0) {

            const frequencyBoostValue = ImageMaxFrequencyBoost * bot.replyRarity / InitialReplyRarity;
            const frequencyBoost = forceSend ? 1 : clamp(frequencyBoostValue, 1, ImageMaxFrequencyBoost);
            const sendImage = bot.forceImage || !uniform(0, ImagePostingRarity / frequencyBoost);

            bot.forceImage = false;

            // Give a chance to boost word count
            if (!uniform(0, BoostRarity)) bot.longerSentences = true;

            // Disable after sending the message
            scope (exit) bot.longerSentences = false;

            // Increase reply chance
            if (bot.replyRarity == InitialReplyRarity) {

                bot.replyRarity = ActiveReplyRarity;

            }

            // Give a chance to post an image
            if (sendImage && imgBBToken) {

                import dcord.api.routes : Route;

                // Give a typing indicator
                auto route = Route(HTTPMethod.POST, "/channels/$CHANNEL/typing");
                client.api.requestJSON(route(event.message.channel.id));

                if (mutilateImage(*bot)) {

                    uploadImage(event.message.channel);
                    return;

                }

            }

            alias phraseDebug = a => format!"*%-(%s %)* %s"(a.words, a.occurences);

            // Highlight best input phrases
            debug const debugData = bestPhrases.length
                ? format!"> %-(%s, %)\n"(bestPhrases.map!phraseDebug)
                : "";

            else const debugData = "";

            /// Get the context
            auto context = bestPhrases
                .map!"a.words"
                .join
                .join(" ");

            // Get a message
            const result = debugData ~ bot.statusUpdate(context).join(" ");

            // Post a text reply
            event.message.reply(result);

        }

    }

    void uploadImage(Channel channel, Duration retryTimeout = 1.seconds) {

        writefln!"starting upload...";
        scope (failure) {

            writefln!"upload failed, retrying in %s"(retryTimeout);

            setTimer(retryTimeout, () => uploadImage(channel, retryTimeout + 2.seconds), false);

        }

        // Upload to ImgBB
        requestHTTP(format!"https://api.imgbb.com/1/upload?key=%s"(imgBBToken),

            (scope HTTPClientRequest req) {

                writefln!"building request";
                scope (failure) writefln!"build failed.";

                import std.base64;
                import std.file : read;

                req.method = HTTPMethod.POST;
                req.writeFormBody([
                    "image": cast(string) Base64.encode(cast(ubyte[]) ImageOutputPath.read),
                ]);

            },

            (scope HTTPClientResponse res) {

                writefln!"got a response %s"(res.statusCode);

                channel.sendMessage(res.readJson["data"]["url"].get!string);

            }

        );

    }

}
