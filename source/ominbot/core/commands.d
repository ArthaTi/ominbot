module ominbot.core.commands;

import std.string;
import std.algorithm;
import std.exception;

import ominbot.core.bot;


@safe:


bool runCommands(Ominbot bot, bool admin, string text) {

    // Check for prefix
    if (!text.findSkip("omin, ")) return false;

    const command = text.strip;

    try switch (command) {

        case "where are you":
        case "show your brain":
        case "thoughtmap":

            enforce!ArgException(admin, "not admin");
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
