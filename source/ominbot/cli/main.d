module ominbot.cli.main;

import std.stdio;
import std.string;
import std.algorithm;
import std.exception;

import core.thread;

import ominbot.launcher;


@safe:


public {

    enum CSI = "\x1B\x5B";
    ulong userID = 1, serverID = 1, channelID = 1;

}

void main() {

    OminbotLoader loader;
    string progressBuffer;

    void progress(string name, ubyte percent) {

        progressBuffer = percent == 255
            ? format!"%sloading %s%s...\n"(CSI ~ "36m", name, CSI ~ "m")
            : format!"%sloading %s%s: %s%%\n"(CSI ~ "36m", name, CSI ~ "m", percent);

    }

    while (true) {

        auto bot = loader.update();
        bot.setAdmin(1);
        bot.progressCallback(&progress);

        // Write the loading buffer
        write(progressBuffer);
        progressBuffer = "";

        // Process events
        foreach (event; bot.poll) {

            writefln!"%sto%s(%s) %sin%s(%s/%s)"(
                CSI ~ "96m", CSI ~ "m", event.user,
                CSI ~ "96m", CSI ~ "m", event.targetServer,
                event.targetChannel,
            );
            writeln(event.messageText);

        }

        // Read user messages
        if (!bot.readPrompt) break;

    }

}

/// Read the prompt. If returned false, the program should quit.
bool readPrompt(Bot bot) {

    try {

        // Request a from the user
        writef!"%somin%s# "(CSI ~ "32m", CSI ~ "m");
        const msg = (() @trusted => readln())();

        // Stop if given EOL
        if (msg is null) return false;

        const command = msg.startsWith("/");

        // A chat message
        if (!command) {

            // Ignore if the message is empty
            if (msg.length == 0) return false;

            // Construct the event
            const event = Event(userID, serverID, channelID, msg);

            // Send to omin
            bot.pushEvent(event, false);

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

    auto input = Event(userID, serverID, channelID, null);

    switch (argv[0]) {

        case "user":
        case "server":
        case "channel":
            switchContext(argv);
            break;

        case "f":
        case "force":

            import std.string;

            if (argv.length > 1) {

                input.messageText = argv[1..$].join(" ");

            }

            bot.pushEvent(input, true);
            break;

        default:
            bot.pushCommand(input, argv);
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
