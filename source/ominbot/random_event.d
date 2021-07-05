module ominbot.random_event;

import std.random;

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
        return bot.statusUpdate();
    },

    (ref bot) {
        bot.replyRarity = BoostedReplyRarity;
        return "";
    },

];

string runRandomEvent(ref Ominbot bot) {

    return events[].choice()(bot);

}
