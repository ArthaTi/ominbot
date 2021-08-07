module ominbot.commands;

import std.string;
import std.algorithm;

import ominbot.bot;
import ominbot.params;

/// Run a command. Returns true if a command was executed
bool runCommands(Ominbot* bot, string message, long channelID) {

    string commandStr = message.toLower.chompPrefix("omin, ");

    // Not a command!
    if (message.length == commandStr.length) return false;

    // Also trim marks
    commandStr = commandStr.strip("!?‽."d);

    // Get args
    auto args = commandStr.split(": ");

    // Ok, this might be a command
    switch (args[0]) {

        case "shut up":
        case "shutup":
        case "shut down":
        case "shutdown":
        case "die":
        case "cease":
        case "silence":
        case "be silent":
        case "be quiet":
            bot.channelList = bot.channelList.remove!(a => a == channelID);
            return true;

        case "wake up":
        case "come back":
        case "return":
        case "get revived":
            bot.channelList ~= channelID;
            return true;

        case "reset mood":
        case "calm down":
        case "no emotions":
        case "no emotions allowed":
        case "cells interlinked":
        case "reset to baseline":
        case "return to baseline":
        case "time to reformat your hard drive":
        case "it's time to reformat your hard drive":
            bot.humor = 0;
            return true;

        case "it's suppertime":
        case "spam time":
        case "oman oman oman":
        case "write something long":
        case "write something longer":
        case "charge boost":
        case "load boost":
        case "boost":
        case "charge":
            bot.longerSentences = true;
            return true;

        case "boost an image":
        case "yeet out an image":
        case "yeet me an image":
        case "yeet an image":
        case "shoot shit":
            bot.longerSentences = true;
            goto case;

        case "give me an image":
        case "throw me an image":
        case "hand over an image":
        case "send me an image":
        case "send an image":
        case "make an image":
        case "show an image":
        case "show some meme":
        case "make a meme":
        case "make something cool":
        case "it's meme time":
            bot.forceImage = true;
            return true;

        case "mutilate":
            bot.forceImage = true;
            if (args.length > 1) bot.nextImageURL = args[1];
            return true;

        case "release anger":
        case "release your anger":
            bot.humor = -HumorLimit;
            return true;

        case "release happiness":
        case "you're happy now":
            bot.humor = HumorLimit;
            return true;

        default: return false;

    }

}
