module ominbot.cli.main;

import std.stdio;
import std.datetime;

import core.thread;

import ominbot.launcher;


@safe:



void progress(string name)(ubyte percent) {

    writefln!"%sloading %s %s%%"(percent > 0 ? "\r" : "", name, percent);

}

void main() {

    OminbotLoader loader;

    loader.dictionaryProgress = (a) => a.progress!"dictionary";
    loader.modelProgress = (a) => a.progress!"model";

    while (true) {

        auto bot = loader.update();

        auto events = bot.poll();

        () @trusted {

            Thread.sleep(0.seconds);

        }();

    }

}
