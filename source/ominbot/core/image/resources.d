module ominbot.core.image.resources;

import std.format;

import dlib.image;

enum CardParts = ["background", "details", "tags", "border", "name", "id"];

immutable {

    SuperImage impactBitmap, pastelicBitmap;

    static foreach (part; CardParts) {

        mixin(part.format!"SuperImage %sBitmap;");

    }

}

shared static this() @system {

    import dlib.filesystem;

    setFileSystem(new LocalFileSystem);

    impactBitmap = cast(immutable) loadImage("resources/bot-impact.png");
    pastelicBitmap = cast(immutable) loadImage("resources/cards/pastelic.png");

    static foreach (part; CardParts) {

        mixin(part.format!"%sBitmap") = cast(immutable) loadImage(part.format!"resources/cards/%s.png");

    }

}
