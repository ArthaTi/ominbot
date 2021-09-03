module ominbot.core.loader;


@safe:


struct OminbotLoader {

    void delegate(ubyte percent) dictionaryProgress;
    void delegate(ubyte percent) modelProgress;

    void load();

}
