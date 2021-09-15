module ominbot.cli.main;

import std.stdio;
import std.string;
import std.algorithm;
import std.exception;

import core.thread;

import ominbot.launcher;


@safe:


public {

    ulong userID = 1, serverID = 1, channelID = 1;

}

void progress(string name)(ubyte percent) {

    writefln!"%sloading %s %s%%"(percent > 0 ? "\r" : "", name, percent);

}

void main() {

    OminbotLoader loader;

    loader.dictionaryProgress = (a) => a.progress!"dictionary";
    loader.modelProgress = (a) => a.progress!"model";

    while (true) {

        auto bot = loader.update();
        bot.setAdmin(1);

        // Process events
        foreach (event; bot.poll) {

            writefln!"to(%s) in(%s/%s)\n%s"(event.user, event.targetServer, event.targetChannel,
                event.messageText);

        }

        // Read user messages
        if (!bot.readPrompt) break;

    }

}

/// Read the prompt. If returned false, the program should quit.
bool readPrompt(Bot bot) {

    try {

        enum CSI = "\x1B\x5B";

        // Request a from the user
        writef!"%somin%s# "(CSI ~ "32m", CSI ~ "m");
        const msg = (() @trusted => readln())();

        // Stop if given EOL
        if (msg is null) return false;

        const command = msg.startsWith("/");

        // A chat message
        if (!command) {

            // Construct the event
            const event = Event(userID, serverID, channelID, msg);

            // Send to omin
            bot.pushEvent(event);

            return true;

        }

        // A command...
        const cmd = msg.strip[1..$];
        const arg = cmd.findSplit(" ");

        bot.runCommand(arg ? [arg[0], arg[2]] : [cmd]);

    }

    catch (Exception exc) () @trusted {

        writeln(exc);

    }();

    return true;

}

void runCommand(Bot bot, string[] argv) {

    switch (argv[0]) {

        case "user":
        case "server":
        case "channel":
            switchContext(argv);
            break;

        case "f":
        case "force":
            bot.requestResponse();
            break;

        default:
            bot.pushCommand(Event(userID, serverID, channelID, null), argv);
            break;

    }

}

void switchContext(string[] argv) {

    import std.conv;

    enforce(argv.length > 1, "missing argument");

    scope (success) writefln!"switched";

    const value = argv[1].to!ulong;

    final switch (argv[0]) {

        case "user":
            userID = value;
            break;

        case "server":
            serverID = value;
            break;

        case "channel":
            channelID = value;
            break;

    }

}
