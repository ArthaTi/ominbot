module ominbot.core.commands;

import fs = std.file;

import std.path;
import std.string;
import std.algorithm;
import std.exception;

import ominbot.launcher;

import ominbot.core.bot;
import ominbot.core.html;
import ominbot.core.params;
import ominbot.core.structs;
import ominbot.core.emotions;
import ominbot.core.database.items;


@safe:


bool runCommands(Ominbot bot, Event input, bool admin) {

    // Check for prefix
    if (!input.messageText.skipOver("omin, ")) return false;

    auto argv = [input.messageText.strip];

    runCommands(bot, input, argv, admin);

    return true;

}

void runCommands(Ominbot bot, Event input, string[] argv, bool admin) {

    import std.conv;

    enum defaultEmotionMod = 50;

    const command = argv[0];
    auto group = bot.groups.get(input.targetChannel, bot.map.root);

    try switch (command) {

        case "how are you":
        case "feelings":
        case "emotions":

            // Just output the current emotional value
            auto newEvent = input;
            newEvent.messageText = bot.emotions.get(input.targetServer, Emotions.init).toString;
            bot.eventQueue ~= newEvent;

            break;

        case "cheerup":
        case "x+":
        case "x":
            enforce!ArgException(admin, "not admin");

            const value = argv.length > 1
                ? argv[1].to!int
                : defaultEmotionMod;

            bot.emotions.require(input.targetServer).move(value.to!short, 0);

            goto case "emotions";

        case "sadden":
        case "x-":
            enforce!ArgException(admin, "not admin");

            const value = argv.length > 1
                ? -argv[1].to!int
                : -defaultEmotionMod;

            bot.emotions.require(input.targetServer).move(value.to!short, 0);

            goto case "emotions";

        case "activate":
        case "y+":
        case "y":
            enforce!ArgException(admin, "not admin");

            const value = argv.length > 1
                ? argv[1].to!int
                : defaultEmotionMod;

            bot.emotions.require(input.targetServer).move(0, value.to!short);

            goto case "emotions";

        case "calmdown":
        case "calm down":
        case "y-":
            enforce!ArgException(admin, "not admin");

            const value = argv.length > 1
                ? -argv[1].to!int
                : -defaultEmotionMod;

            bot.emotions.require(input.targetServer).move(0, value.to!short);

            goto case "emotions";

        case "return to baseline":
        case "reset emotions":
        case "baseline":
            enforce!ArgException(admin, "not admin");

            bot.emotions[input.targetServer] = Emotions();

            goto case "emotions";

        case "where are you":
        case "show your brain":
        case "thoughtmap":
            enforce!ArgException(admin, "not admin");

            // Change group if given second argument
            if (argv.length > 1) group = bot.map.groups[argv[1].to!size_t];

            // Create the thoughtmap
            fs.mkdirRecurse("public/");
            fs.write("public/thoughtmap.html", renderMap(group));

            // Send a response
            auto newEvent = input;
            newEvent.messageText = format!"thoughtmap updated. %s/%s"(publicURL, "thoughtmap.html");
            bot.eventQueue ~= newEvent;

            // Write response
            break;

        case "teleport":
        case "respawn":
        case "reset":

            import std.random;

            // Move to a random location
            bot.groups[input.targetChannel] = bot.map.groups.choice;

            break;

        case "make image":
        case "make an image":
        case "make me an image":
        case "yeet an image":
        case "show an image":
        case "show me an image":
        case "hand over an image":
        case "image":

        case "make meme":
        case "make a meme":
        case "make me a meme":
        case "yeet a meme":
        case "show a meme":
        case "show me a meme":
        case "hand over a meme":
        case "meme time":
        case "meme":

        case "show a funnie":

            enforce!ArgException(admin, "not admin");

            // Send a response
            auto newEvent = input;
            newEvent.messageText = null;
            newEvent.imageURL = bot.makeImage(input);
            bot.eventQueue ~= newEvent;

            break;

        case "random event":
        case "do something":
        case "event":

            enforce!ArgException(admin, "not admin");

            import std.datetime;

            // Start a random event by resetting last event time
            bot.lastRandomEvent = SysTime.fromUnixTime(0);

            break;

        case "make item":
        case "create item":
        case "lookup item":
        case "inspect item":
        case "item":

            enforce!ArgException(admin, "not admin");
            enforce!ArgException(argv.length > 1, "argument required: item number");

            try {

                // Get some text for the item name
                // Note: first word of the message will be replaced
                auto text = [""] ~ bot.makeMessage(input);

                // Construct the item
                const itemNumber = argv[1].to!uint;
                const item = bot.makeItem(input, itemNumber, text);

                // Send a response message
                auto output = input;
                output.messageText = text.join(" ");
                output.imageURL = publicURL.buildPath(itemNumber.format!"cards/card-%s.png");
                bot.eventQueue ~= output;

            }
            catch (ConvException) {

                throw new ArgException("argument must be an unsigned integer");

            }

            break;

        case "remake item":
        case "regenerate texture":
        case "remake":
        case "regen":
            enforce!ArgException(admin, "not admin");
            enforce!ArgException(argv.length > 1, "argument required: item number");

            const card = bot.db.getItem(argv[1].to!uint);

            auto output = input;
            output.imageURL = bot.makeCardImage(card);
            bot.eventQueue ~= output;

            break;

        case "recolor item":
        case "recolor":
            enforce!ArgException(admin, "not admin");
            enforce!ArgException(argv.length > 1, "argument required: item number");

            import ominbot.core.image.card;

            const mood = bot.emotions.get(input.targetServer, Emotions.init);

            auto card = bot.db.getItem(argv[1].to!uint);
            card.palette = ColorPalette.fromMood(mood);
            // TODO update the item

            auto output = input;
            output.imageURL = bot.makeCardImage(card);
            bot.eventQueue ~= output;

            break;

        case "my items":
        case "what items do i have":
        case "what do i have":
        case "show me my stuff":
        case "show my stuff":
        case "list my items":
        case "items":
        case "what do i have in my inventory":
        case "inventory":

            import std.algorithm;

            try {

                const pageNumber = argv.length > 1
                    ? argv[1].to!int
                    : 1;

                const items = bot.db.listItems(input.user, pageNumber);

                auto output = input;
                output.messageText = format!"Your items:\n%sPage %s (try \"Omin, items 2\")"(
                    items.map!(a => format!"— %sx %s. %s\n"(a[1], a[0].id, a[0].name.join(" "))).join(),
                    pageNumber
                );
                bot.eventQueue ~= output;

            }

            catch (ConvException) {

                throw new ArgException("first argument must be a number");

            }

            break;

        // Give an item to someone else
        case "send item":
        case "trade":
        case "pay":
        case "send":
        case "give":

            enforce!ArgException(argv.length > 1, "argument required: item to give, target user");

            size_t targetUser;
            uint targetItem;
            bool userSpecified, itemSpecified;

            foreach (arg; argv[1..$]) {

                try {

                    bool userArg = arg.skipOver("@");

                    if (userArg) {
                        targetUser = arg.to!size_t;
                        userSpecified = true;
                    }

                    else {
                        targetItem = arg.to!uint;
                        itemSpecified = true;
                    }

                }

                catch (ConvException) {

                    throw new ArgException(arg.format!"argument \"%s\" was expected to be number");

                }

            }

            {

                import ominbot.core.image.card;

                enforce!ArgException(itemSpecified, "no item chosen to send");
                enforce!ArgException(userSpecified, "no target user specified");

                // Make a dummy item
                const item = ItemCard(targetItem);

                enforce!ArgException(
                    bot.db.takeItem(item, input.user),
                    "you don't have enough of this item",
                );
                bot.db.giveItem(item, targetUser);

            }

            break;

        default:
            throw new ArgException("unknown command");

    }

    catch (ArgException exc) {

        import std.stdio;
        writeln(exc.msg);

    }

}

class ArgException : Exception {

    mixin basicExceptionCtors;

}
