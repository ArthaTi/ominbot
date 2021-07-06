module ominbot.random_event;

import std.random;
import std.string;

import ominbot.bot;
import ominbot.params;

alias RandomEvent = string function(ref Ominbot);

immutable RandomEvent[] events = [

    (ref bot) {
        bot.humor += uniform!"[]"(-10, 10);
        return null;
    },

    (ref bot) {
        bot.humor += uniform!"[]"(-3, 3);
        return null;
    },

    (ref bot) {
        return bot.statusUpdate().join(" ");
    },

    (ref bot) {
        bot.replyRarity = BoostedReplyRarity;
        return null;
    },

];

string runRandomEvent(ref Ominbot bot) {

    return events[].choice()(bot);

}
