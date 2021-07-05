module ominbot.image;

import std.file;
import std.path;
import std.array;
import std.format;
import std.random;
import std.datetime;
import std.stdio : writefln;

import dlib.image;

import ominbot.bot;

struct Character {

    uint x, y, width, height;

}

immutable impactChars = [

    "A": Character(   0, 0, 43, 61),
    "B": Character(  44, 0, 39, 61),
    "C": Character(  87, 0, 41, 61),
    "D": Character( 132, 0, 40, 61),
    "E": Character( 176, 0, 33, 61),
    "F": Character( 212, 0, 32, 61),
    "G": Character( 246, 0, 41, 61),
    "H": Character( 291, 0, 40, 61),
    "I": Character( 335, 0, 23, 61),
    "J": Character( 361, 0, 28, 61),
    "K": Character( 394, 0, 41, 61),
    "L": Character( 437, 0, 31, 61),
    "M": Character( 471, 0, 50, 61),
    "N": Character( 525, 0, 39, 61),
    "O": Character( 568, 0, 41, 61),
    "P": Character( 613, 0, 38, 61),
    "Q": Character( 653, 0, 41, 61),
    "R": Character( 698, 0, 39, 61),
    "S": Character( 739, 0, 41, 61),
    "T": Character( 780, 0, 39, 61),
    "U": Character( 821, 0, 41, 61),
    "V": Character( 863, 0, 44, 61),
    "W": Character( 905, 0, 61, 61),
    "X": Character( 965, 0, 41, 61),
    "Y": Character(1005, 0, 41, 61),
    "Z": Character(1045, 0, 34, 61),

];

string mutilateImage(ref Ominbot bot) {

    const imagePath = "resources".dirEntries("bot-*.png", SpanMode.shallow)
        .array
        .choice;

    writefln!"Proceeding to mutilate image %s..."(imagePath);

    auto image = loadImage(imagePath);

    image.drawText(bot.statusUpdate, 0, 0, color3(0xffffff));

    const outputPath = format!"resources/bot-output-%s.png"(Clock.currTime.stdTime);

    writefln!"Saving";
    image.savePNG(outputPath);

    writefln!"Mutilated an image and saved to %s"(outputPath);

    return outputPath;

}
