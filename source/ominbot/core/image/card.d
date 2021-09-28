module ominbot.core.image.card;

import std.traits;
import dlib.image;

import ominbot.core.params;
import ominbot.core.image.card;
import ominbot.core.image.utils;
import ominbot.core.image.fonts;
import ominbot.core.image.resources;

enum ItemType {

    regular,
    dark,

}

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

    uint id;

    /// List of words making up the name.
    string[] name;
    string[3] tags;
    ItemType type;

    ColorPalette borderColors;
    ColorPalette backgroundColors;
    ColorPalette contentColors;

    SuperImage render() {

        import std.string, std.typecons;

        auto output = combineImages(
            ImageData(backgroundBitmap, backgroundColors),
            ImageData(detailsBitmap,    contentColors),
            ImageData(tagsBitmap,       contentColors),
            ImageData(borderBitmap,     borderColors),
            ImageData(nameBitmap,       contentColors),
            ImageData(idBitmap,         contentColors),
        );

        // Get text data for the name and strip lines if there are more than one
        const nameWidth = 102;
        const nameData = spreadText(fontPastelic, name, nameWidth)[0..1];

        // Add item data
        output.addText(fontPastelic, nameData, 9, 11, nameWidth);
        output.addText(fontPastelic, [id.format!"#%s"], 81, 21, 27);

        // Add tags
        foreach_reverse (i, pos; [tuple(40, 154), tuple(13, 160), tuple(67, 160)]) {

            const text = [tags[i].length ? tags[i] : "?"];

            output.addText(fontPastelic, text, pos.expand, 40);

        }

        // Upscale the output
        return output.upscale(cardUpscale);

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
        tags: ["weapon", "elimination", "declaration"],

        borderColors: ColorPalette(
            color3(0x3b2f03),
            color3(0x2d260b),
            color3(0x1c1a00),
        ),
        backgroundColors: ColorPalette(
            color3(0x473a07),
            color3(0x6f3f1b),
        ),
        contentColors: ColorPalette(
            color3(0x643c00),
            color3(0x875100),
            color3(0xa05f00),
        )
    };

    card.render.savePNG("resources/bot-unittest-card1.png");

}
