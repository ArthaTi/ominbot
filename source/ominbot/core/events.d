module ominbot.core.events;

import ominbot.core.bot;
import ominbot.core.params;


@safe:


void function(Ominbot bot)[] events = [

    // Calm down a bit
    (bot) {

        foreach (ref emotions; bot.emotions.byValue) {

            emotions.intensity -= randomEventValue;

        }

    },

];
