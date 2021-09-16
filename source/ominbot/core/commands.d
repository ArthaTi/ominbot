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

    const command = argv[0];
    auto group = bot.groups.get(input.targetChannel, bot.map.root);

    try switch (command) {

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
