module ominbot.launcher;

import std.file;
import std.stdio;
import std.datetime;

import core.runtime;


@safe:


version (linux) enum libraryPath = "build/libominbot_core.so";
else static assert("DO YOU HAVE DUMB? YOUR OS BAD.");

struct Event {

    /// ID of user targeted by this message, if sent by the bot, or ID of the user who sent this message, if directed
    /// back at the bot. `0` if no user is targeted.
    ulong user;

    /// ID of the server this message should be sent to.
    ulong targetServer;

    /// ID of the channel this message should be sent to.
    ulong targetChannel;

    /// Message Omin wants to send.
    string messageText;

}

interface Bot {

    /// Notify the bot of an event within the channel.
    void pushEvent(Event event);

    /// Request the bot to execute a command.
    void pushCommand(Event event, string[] argv);

    /// Request an instance response from the bot.
    void requestResponse(Event event);

    /// Poll the bot for new events.
    Event[] poll();

    /// Make the target user admin.
    void setAdmin(ulong id);

}

struct OminbotLoader {

    private shared static {

        /// Mutex to prevent collision between instances.
        Object mutex;

        /// The global instance of the bot.
        Bot instance;


    }

    private {

        /// Loaded library reference.
        void* library;

        /// Time the library was last modified at.
        SysTime lastModified;

    }

    shared static this() {

        mutex = new shared Object;

    }

    void delegate(ubyte percent) dictionaryProgress;
    void delegate(ubyte percent) modelProgress;

    /// Load a new bot to replace the old one.
    static void loadBot(Bot bot) @trusted {

        synchronized (mutex) {

            instance = cast(shared) bot;

        }

    }

    /// Update the Ominbot instance, if the library file was replaced, or if it wasn't loaded before.
    Bot update() @trusted {

        synchronized (mutex) {

            const libExists = libraryPath.exists;
            const nowModified = libExists
                ? libraryPath.timeLastModified
                : SysTime.init;

            // Ominbot is already loaded
            if (library) {

                // Ignore if the library doesn't exist
                if (!libExists) return cast() instance;

                // Ignore if it hasn't been updated
                if (nowModified <= lastModified) return cast() instance;

                // Unload the library
                Runtime.unloadLibrary(library);

                writefln!"Reloading Ominbot...";

            }

            else writefln!"Loading Ominbot...";

            assert(libExists, "Failed to load, ominbot:core has not been found");

            // Load the library now
            library = Runtime.loadLibrary(libraryPath);
            lastModified = nowModified;

        }

        return cast() instance;

    }

}
