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

    const command = input.messageText.strip;

    try switch (command) {

        case "where are you":
        case "show your brain":
        case "thoughtmap":
            enforce!ArgException(admin, "not admin");

            // Create the thoughtmap
            fs.mkdirRecurse("public/");
            //fs.write("public/thoughtmap.html", renderMap(bot.map));

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

    return true;

}

class ArgException : Exception {

    mixin basicExceptionCtors;

}
