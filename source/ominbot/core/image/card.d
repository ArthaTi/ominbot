module ominbot.core.image.card;

import std.traits;
import dlib.image;

import ominbot.core.params;
import ominbot.core.emotions;

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

    /// Get a color for the current mood.
    static ColorPalette fromMood(const Emotions emotions) @trusted {

        import std.math;

        Emotions emotion = emotions;
        emotion.normalize();

        const angle = emotion.angle * 180 / PI;
        const saturation = 0.5 + emotion.intensity / 255.0 / 2;

        ColorPalette result = {
            primary: hsv(angle - 10, saturation, 0.8),
            secondary: hsv(angle + 10, saturation, 0.9),
        };

        return result;

    }

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

    void opAssign(const ColorPalette other) @trusted {

        import std.traits;

        foreach (field; FieldNameTuple!ColorPalette) {

            mixin("this." ~ field) = mixin("other." ~ field);

        }

    }

}

/// Represents an item card.
struct ItemCard {

    uint id;

    /// List of words making up the name.
    string[] name;
    string[3] tags;
    ItemType type;

    ColorPalette palette;

    SuperImage render() const {

        import std.string, std.typecons;

        // Create secondary palettes
        ColorPalette backgroundColors = palette;
        ColorPalette contentColors = {
            primary: palette.primary * Color4f(0.6, 0.6, 0.6),
            secondary: palette.primary * Color4f(0.8, 0.8, 0.8),
            background: palette.primary,
        };
        ColorPalette borderColors = pickBorderColors(contentColors);

        // Prepare the card image
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

    private ColorPalette pickBorderColors(ColorPalette contentColors) const {

        final switch (type) {

            case ItemType.regular:
                return contentColors;

            case ItemType.dark:

                return ColorPalette(
                    contentColors.primary * Color4f(0.6, 0.6, 0.6),
                    contentColors.primary * Color4f(0.4, 0.4, 0.4),
                    contentColors.primary * Color4f(0.2, 0.2, 0.2),
                );

        }

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

        palette: ColorPalette(
            color3(0x6f3f1b),
            color3(0x473a07),
        ),
    };

    card.render.savePNG("resources/bot-unittest-card1.png");

    card.type = ItemType.dark;

    card.render.savePNG("resources/bot-unittest-card2.png");

}
