module ominbot.discord;

import dcord.core;
import vibe.core.core;
import vibe.http.client;
import vibe.inet.urltransfer;

import std.stdio;
import std.format;
import std.random;
import std.string;
import std.algorithm;

import ominbot.bot;
import ominbot.image;
import ominbot.params;
import ominbot.random_event;

class OminbotPlugin : Plugin {

    Ominbot* bot;
    bool runEvents;
    string imgBBToken;

    this(ref Ominbot bot) {

        this.bot = &bot;

        // Every minute reduce bot post rarity
        setTimer(1.minutes, {

            bot.replyRarity = min(InitialReplyRarity, bot.replyRarity + RestoreReplyRarityPerMinute);

        }, true);

        // Trigger a random event once in 5 minutes
        setTimer(5.minutes, {

            if (!runEvents) return;

            auto content = bot.runRandomEvent();

            if (!content) return;

            // Send the resulting message and disable events
            runEvents = false;
            client.api.channelsMessagesCreate(
                channelList[].choice,
                content,
                null,
                false,
                null,
            );

        }, true);

    }

    @Listener!(MessageCreate, EmitterOrder.AFTER)
    void messageCreated(MessageCreate event) {

        // Ignore own messages
        if (event.message.author.id == me.id) return;

        // Make sure the channel is in the list
        if (!channelList.canFind(event.message.channel.id)) return;


        const forceImage = event.message.author.id == 366675056979476480
            && event.message.content.toLower == "omin, yeet me an image!";
        bool forceSend = forceImage;

        // Enable events, if off.
        runEvents = true;

        // Feed the bot
        int inputSentiment = bot.feed(event.message.content, (ulong id) {

            // Pinged!
            if (id != me.id) return;

            forceSend = true;

        });

        bot.humor += inputSentiment * (forceSend ? 2 : 1);

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

        writefln!"MessageCreate(%+3s): %s"(bot.humor, event.message);

        // Trigger a reply
        if (forceSend || uniform(0, bot.replyRarity) == 0) {

            const sendImage = forceImage || !uniform(0, ImagePostingRarity);

            // Boost reply chance
            if (bot.replyRarity == InitialReplyRarity) {

                bot.replyRarity = ActiveReplyRarity;

            }

            // Give a chance to post an image
            if (sendImage
                && imgBBToken
                && mutilateImage(*bot)) {

                writefln!"starting upload...";
                scope (failure) writefln!"upload failed.";

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

                        event.message.reply(res.readJson["data"]["url"].get!string);

                    }

                );

            }

            // Post text instead
            else {

                // Get a message
                const result = bot.statusUpdate(event.message.content).join(" ");

                // Post a reply
                event.message.reply(result);

            }

        }

    }

}
