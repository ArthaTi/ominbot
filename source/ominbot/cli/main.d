module ominbot.cli;

import std.stdio;
import core.runtime;

import ominbot.core.loader;


@safe:


static this() @system {

    version (linux) Runtime.loadLibrary("build/libominbot_core.so");

    else static assert("DO YOU HAVE DUMB YOUR OS BAD");

}


void progress(string name)(ubyte percent) {

    writefln!"%sloading %s %s%%"(percent > 0 ? "\r" : "", name, percent);

}

void main() {

    OminbotLoader loader;

    loader.dictionaryProgress = (a) => a.progress!"dictionary";
    loader.modelProgress = (a) => a.progress!"model";

    loader.load();

}
