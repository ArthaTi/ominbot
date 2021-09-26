module ominbot.core.image.card;

import std.traits;
import dlib.image;

import ominbot.core.image.card;
import ominbot.core.image.utils;
import ominbot.core.image.fonts;
import ominbot.core.image.resources;

/// Used to transform the original color palette from the image.
struct ColorPalette {

    auto primary    = color3(0xb0b0b0);
    auto secondary  = color3(0xcecece);
    auto background = color3(0xffffff);
    auto line       = color3(0x000000);

    Color4f apply(Color4f color) const {

        const pattern = ColorPalette.init;

        // Match the colors against the pattern
        static foreach (name; FieldNameTuple!ColorPalette) {

            if (color == mixin("pattern." ~ name)) {

                return mixin(name);

            }

        }

        return color;

    }

}

/// Represents an item card.
struct ItemCard {

    /// List of words making up the name.
    string[] name;
    uint id;
    string[3] tags;

    ColorPalette borderColors;
    ColorPalette backgroundColors;
    ColorPalette contentColors;

    SuperImage render() {

        import std.string;

        auto output = combineImages(
            ImageData(backgroundBitmap, backgroundColors),
            ImageData(detailsBitmap,    contentColors),
            ImageData(tagsBitmap,       contentColors),
            ImageData(borderBitmap,     borderColors),
            ImageData(nameBitmap,       contentColors),
            ImageData(idBitmap,         contentColors),
        );

        // Add item data
        output.addText(fontPastelic, name, 9, 11, 102);
        output.addText(fontPastelic, [id.format!"#%s"], 81, 21, 28);

        // More details
        output.addText(fontPastelic, ["\U0001F62C\U0001F60E"], 12, 98, 96);

        return output;

    }

}

private struct ImageData {

    immutable SuperImage image;
    ColorPalette palette;

}

private SuperImage combineImages(ImageData[] input...)
in(input.length, "input data cannot be empty")
do {

    const lastData  = input[$-1];
    auto lastImage = cast() lastData.image;

    // "width" is not callable using an "immutable" object.
    // the only attribute dlib cares for is "@nogc". funny.
    auto output = (cast() lastImage).createSameFormat(lastImage.width, lastImage.height);

    foreach (y; 0..output.height)
    foreach (x; 0..output.width) {

        output[x, y] = lastData.palette.apply(lastImage[x, y]);

        // Combine the images
        foreach_reverse (data; input[0..$-1]) {

            // Already reached an opaque color, can finish here
            if (output[x, y].a == 1) continue;

            const pixelA = data.palette.apply((cast() data.image)[x, y]);

            output[x, y] = combinePixels(pixelA, output[x, y]);

        }

    }

    return output;

}

unittest {

    import std.string;

    ItemCard card = {
        name: "This is an item‽ No way.".split(" "),
        id: 9999,
        tags: ["huh", null, null],

        borderColors: ColorPalette(
            color3(0x414100),
            color3(0x373700),
            color3(0x505000),
        ),
        backgroundColors: ColorPalette(
            color3(0xffd765),
            color3(0xe9ff65),
        ),
        contentColors: ColorPalette(
            color3(0x847b36),
            color3(0x9b903f),
            color3(0xc0b24e),
        )
    };

    card.render.savePNG("resources/bot-unittest-card1.png");

}
