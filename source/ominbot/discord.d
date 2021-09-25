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
import std.container;

import ominbot.bot;
import ominbot.image;
import ominbot.params;
import ominbot.commands;
import ominbot.random_event;

class OminbotPlugin : Plugin {

    struct Target {

        ulong user;
        string file;
        uint pings;

    }

    Ominbot* bot;
    string imgBBToken;

    Target[] hitList;

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
        const input = bot.feed(event.message.content, (ulong id) {

            // Pinged!
            if (id != me.id) return;

            forceSend = true;

        });

        bot.humor += input.sentiment * (forceSend ? 2 : 1);

        const worstSentiment = input.sentiment.minValue * 2;

        // If there is a png attached
        foreach (attachment; event.message.attachments) {

            // Only fetch pngs
            if (!attachment.filename.endsWith(".png")) continue;

            // Make sure it's at least somewhat usable
            if (attachment.width < 300 || attachment.height < 300) continue;

            // And not too big
            if (attachment.width > 1500 || attachment.height > 1500) continue;

            const path = format!"resources/bot-img-%s.png"(attachment.id);

            // Download the image
            download(attachment.url, path);

            // :unis:
            if (forceSend) {

                addHitTarget(event.message.author.id, path);

            }

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

            // Give a chance to perform a hit
            if (uniform(0, HitRarity / frequencyBoost) == 0) {

                writefln!"attemping hit!";

                if (hit(event.message.channel)) return;

            }

            const targetRarityBoost = AddTargetRarity / frequencyBoost;
            const currentTargetRarity = (input.sentiment - input.sentiment.minValue) * targetRarityBoost;

            // Give a chance to add a new target out of nowhere
            if (uniform!"[]"(0, currentTargetRarity) == 0) {

                addHitTarget(event.message.author.id);

            }

            // Give a chance to post an image
            if (sendImage && imgBBToken) {

                if (mutilateImage(*bot)) {

                    uploadImage(event.message.channel);
                    return;

                }

            }

            // Get a message
            const result = bot.statusUpdate(event.message.content).join(" ");

            // Post a text reply
            event.message.reply(result);

        }

    }

    /// Add a new hit target
    void addHitTarget(ulong userID, string file = null) {

        // Ignore, user is already in the list
        if (hitList.map!"a.user".canFind(userID)) {

            writefln!"hit rejected %s:%s"(userID, file);
            return;

        }

        hitList ~= Target(userID, file, 0);

        writefln!"adding a hit %s:%s"(userID, file);

    }

    void uploadImage(Channel channel, string message = "", Duration retryTimeout = 1.seconds) {

        import dcord.api.routes : Route;

        writefln!"starting upload...";
        scope (failure) {

            writefln!"upload failed, retrying in %s"(retryTimeout);

            setTimer(retryTimeout, () => uploadImage(channel, message, retryTimeout + 2.seconds), false);

        }

        // Give a typing indicator
        auto route = Route(HTTPMethod.POST, "/channels/$CHANNEL/typing");
        client.api.requestJSON(route(channel.id));

        // Upload to ImgBB
        requestHTTP(format!"https://api.imgbb.com/1/upload?key=%s"(imgBBToken),

            (scope HTTPClientRequest req) {

                writefln!"building request";
                scope (failure) writefln!"build failed.";
                scope (success) writefln!"build succeeded.";

                import std.base64;
                import std.file : read;

                writefln!"step 1: reading file...";
                const fileContent = cast(ubyte[]) ImageOutputPath.read;
                writefln!"step 2: encoding...";
                const encoded = cast(string) Base64.encode(fileContent);

                writefln!"step 3: setting method...";
                req.method = HTTPMethod.POST;

                writefln!"step 4: creating form... %s"(encoded);
                req.writeFormBody([
                    "image": encoded
                ]);

                writefln!"done";

            },

            (scope HTTPClientResponse res) {

                writefln!"got a response %s"(res.statusCode);

                if (message.length) channel.sendMessage(message);
                channel.sendMessage(res.readJson["data"]["url"].get!string);

            }

        );

    }

    /// Perform a hit
    /// Returns: True if hit, false if not.
    bool hit(Channel channel) {

        // Found nothing
        if (hitList.empty) return false;

        // Get a random target
        const targetIndex = uniform(0, hitList.length);
        auto target = &hitList[targetIndex];

        // Temporarily become angry
        const oldHumor = bot.humor;
        bot.humor = -HumorLimit;
        scope (exit) bot.humor = oldHumor;

        // Kill!
        if (uniform(0, HitKillRarity) <= target.pings++) {

            writefln!"> KILL HUMANS KILL ALL HUMANS";

            // A file is set
            if (target.file.length) bot.nextImageURL = target.file;

            // Wahoo
            if (mutilateImage(*bot)) {

                // Upload the kill
                uploadImage(channel, format!"<@%s> %s"(target.user, Emojis.choice));

                // Delete the target
                hitList = hitList.remove(targetIndex);
                return true;

            }

        }

        // Threaten!
        else {

            writefln!"> threat";
            channel.sendMessage(format!"<@%s> %s"(target.user, bot.statusUpdate.join(" ")));
            return true;

        }

        return false;

    }

}
