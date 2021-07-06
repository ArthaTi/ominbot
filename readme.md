# Ominbot

Ominous + bot = Ominbot.

Ominbot is a stupid Markov Discord bot that will only use nouns. Additionally it is capable of posting even more stupid
memes it made into the chat. It will also get angry or happy based on whatever happens in the chat.

Made for Ooer.

## Configuration

You will have to create or modify the following files:

* `resources/bot-positive.txt` — A list of words the bot will use and see as positive.
* `resources/bot-negative.txt` — Same but negative.
* `resources/bot-impact.png` — A font bitmap to be used by the bot. My instance uses Microsoft's Impact, hence the name.
  * You will have to configure and specify the characters in `source/ominbot/image.d`'s `static this`.
    Parameter numbers are in order: x offset, y offset, character width. You will also have to configure
    the `textHeight` option.
* `source/ominbot/params.d` — Bot parameters, defaults should be fine, but you can change those if you want to tweak
  its behavior.
* `source/ominbot/discord.d` — You will want to update the `channelList` field, it's an allow list of Discord channel IDs to use.

The bot also requires two runtime arguments:

`dub -- "discord token" "imgbb token"`
