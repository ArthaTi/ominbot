module ominbot.discord;

import dcord.core;
import vibe.core.core;
import vibe.inet.urltransfer;

import std.stdio;
import std.format;
import std.random;
import std.algorithm;

import ominbot.bot;
import ominbot.image;
import ominbot.params;
import ominbot.random_event;

class OminbotPlugin : Plugin {

    Ominbot* bot;
    bool runEvents;

    immutable channelList = [
        861611045537972275,  // private server
        742790712529125469,  // samerion #general
        772160498614665247,  // samerion #bots
        //280298381807714304,  // #oman-pls-to-help
        //325969983441993729,  // #bot-lemons
    ];

    this(ref Ominbot bot) {

        this.bot = &bot;

        // Every minute reduce bot post rarity
        setTimer(1.minutes, {

            bot.replyRarity = min(InitialReplyRarity, bot.replyRarity + 1);

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


        bool forceSend;

        // Enable events, if off.
        runEvents = true;

        // Feed the bot
        bot.feed(event.message.content, (ulong id) {

            // Pinged!
            if (id != me.id) return;

            forceSend = true;

        });

        // If there is a png attached
        foreach (attachment; event.message.attachments) {

            // Only fetch pngs
            if (!attachment.filename.endsWith(".png")) continue;

            // Make sure it's at least somewhat usable
            if (attachment.width < 300 || attachment.height < 300) continue;

            // And not too big
            if (attachment.width > 1500 || attachment.height > 1500) continue;

            // Download the image
            download(attachment.url, format!"resources/bot-%s.png"(attachment.id));

            writefln!"downloaded image %s id %s"(attachment.filename, attachment.id);

        }

        writefln!"MessageCreate(%+3s): %s"(bot.humor, event.message);

        // Trigger a reply
        if (forceSend || uniform(0, bot.replyRarity) == 0) {

            // Boost reply chance
            bot.replyRarity = BoostedReplyRarity;

            // Give a chance to post an image
            if (uniform(0, ImagePostingChance) == 0) {

                mutilateImage(*bot);

            }

            // Post text instead
            else {

                // Get a message
                const result = bot.statusUpdate(event.message.content);

                // Post a reply
                event.message.reply(result);

            }

        }

    }

}
