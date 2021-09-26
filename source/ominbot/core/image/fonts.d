/// This module contains font data and font rendering functions.
module ominbot.core.image.fonts;

import dlib.image;

import std.uni;
import std.algorithm;

import ominbot.core.image.utils;


@safe:


struct BitmapCharacter {

    uint x, y, width;

}

struct WordData {

    uint width;
    BitmapCharacter[] characters;

}

struct Font {

    int textHeight;
    int spaceWidth;
    BitmapCharacter[dchar] fontChars;
    SuperImage fontBitmap;

    /// Calculate the width of the word.
    WordData wordData(string word) const {

        WordData result;

        foreach (letter; word.toUpper) {

            auto item = letter in fontChars;
            if (item is null) continue;

            result.width += item.width;
            result.characters ~= *item;

        }

        return result;

    }

}

immutable {

    Font fontImpact;
    Font fontPastelic;

}

shared static this() @system {

    import dlib.filesystem;

    alias BC = BitmapCharacter;

    setFileSystem(new LocalFileSystem);

    fontImpact = cast(immutable) Font(
        61,
        20,
        [
            'A': BC(   0, 0, 43),
            'B': BC(  44, 0, 39),
            'C': BC(  87, 0, 41),
            'D': BC( 132, 0, 40),
            'E': BC( 176, 0, 33),
            'F': BC( 212, 0, 32),
            'G': BC( 246, 0, 41),
            'H': BC( 291, 0, 40),
            'I': BC( 335, 0, 23),
            'J': BC( 361, 0, 28),
            'K': BC( 394, 0, 41),
            'L': BC( 437, 0, 31),
            'M': BC( 471, 0, 50),
            'N': BC( 525, 0, 39),
            'O': BC( 568, 0, 41),
            'P': BC( 613, 0, 38),
            'Q': BC( 653, 0, 41),
            'R': BC( 698, 0, 39),
            'S': BC( 739, 0, 41),
            'T': BC( 780, 0, 39),
            'U': BC( 821, 0, 41),
            'V': BC( 863, 0, 44),
            'W': BC( 905, 0, 61),
            'X': BC( 965, 0, 41),
            'Y': BC(1005, 0, 41),
            'Z': BC(1045, 0, 34),

            '0': BC(   2, 144, 40),
            '1': BC(  43, 144, 32),
            '2': BC(  79, 144, 39),
            '3': BC( 120, 144, 40),
            '4': BC( 161, 144, 42),
            '5': BC( 204, 144, 40),
            '6': BC( 247, 144, 41),
            '7': BC( 288, 144, 34),
            '8': BC( 325, 144, 38),
            '9': BC( 367, 144, 41),
            '-': BC( 453, 144, 27),
            '!': BC( 482, 144, 25),
            '?': BC( 510, 144, 39),
        ],
        loadImage("resources/bot-impact.png")
    );

    fontPastelic = cast(immutable) Font(
        7,
        3,
        [
            'A': BC(  0, 0, 5),
            'B': BC(  5, 0, 5),
            'C': BC( 10, 0, 5),
            'D': BC( 15, 0, 5),
            'E': BC( 20, 0, 5),
            'F': BC( 25, 0, 5),
            'G': BC( 30, 0, 5),
            'H': BC( 35, 0, 5),
            'I': BC( 40, 0, 3),
            'J': BC( 43, 0, 5),
            'K': BC( 48, 0, 5),
            'L': BC( 53, 0, 5),
            'M': BC( 58, 0, 7),
            'N': BC( 65, 0, 4),
            'O': BC( 69, 0, 5),
            'P': BC( 74, 0, 5),
            'Q': BC( 79, 0, 5),
            'S': BC( 84, 0, 5),
            'T': BC( 89, 0, 5),
            'U': BC( 94, 0, 5),
            'V': BC( 99, 0, 5),
            'W': BC(104, 0, 7),
            'X': BC(111, 0, 5),
            'Y': BC(116, 0, 5),
            'Z': BC(121, 0, 5),

            '.': BC( 0, 7, 3),
            '!': BC( 3, 7, 3),
            '?': BC( 6, 7, 5),
            '‽': BC(11, 7, 5),
            '-': BC(16, 7, 5),
            '—': BC(21, 7, 7),
            '\U0001F62C': BC(29, 7, 8),  // unis
            '\U0001F60E': BC(37, 7, 9),  // botto

            '0': BC(46, 7, 5),
            '1': BC(51, 7, 5),
            '2': BC(56, 7, 5),
            '3': BC(61, 7, 5),
            '4': BC(66, 7, 5),
            '5': BC(71, 7, 5),
            '6': BC(76, 7, 5),
            '7': BC(81, 7, 5),
            '8': BC(86, 7, 5),
            '9': BC(91, 7, 5),
        ],
        loadImage("resources/cards/pastelic.png")
    );


}

/// Add text to given image in place.
void addText(SuperImage a, immutable Font font, string[] words, uint offsetX, uint offsetY, uint width) @trusted {

    byte direction = 1;

    foreach (line; spreadText(font, words, a.width)) {

        scope (exit) {

            offsetY += font.textHeight * direction;

            // Out of image bounds
            if (direction > 0 && offsetY >= a.height) {

                offsetY -= font.textHeight*2;
                direction = -1;

            }

        }

        const lineWidth = line
            .map!(a => a.width + font.spaceWidth)
            .fold!"a + b"
            - font.spaceWidth;

        // Make sure the text is centered
        auto position = (cast(int) a.width - lineWidth) / 2;

        // Generate the line
        foreach (word; line) {

            scope (exit) position += font.spaceWidth;

            foreach (letter; word.characters) () @trusted {

                a.addImage(
                    region(cast() font.fontBitmap, letter.x, letter.y, letter.width, font.textHeight),
                    position, offsetY,
                );

                position += letter.width;

            }();

        }

    }

}

private const(WordData)[][] spreadText(immutable Font font, string[] words, uint imageWidth) {

    const(WordData)[][] lines = [[]];

    uint lineWidth;

    // Calculate
    foreach (word; words) {

        import std.traits;

        const data = font.wordData(word);
        const wordWidth = data.width + font.spaceWidth;

        // Can fit on this line, or the line is empty
        if (!lines[$-1].length || lineWidth + data.width <= imageWidth) {

            lineWidth += wordWidth;
            lines[$-1] ~= data;

        }

        // Nope
        else {

            lineWidth = wordWidth;
            lines ~= [data];

        }

    }

    return lines;

}
