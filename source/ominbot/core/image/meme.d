/// This module is responsible for meme generation.
module ominbot.core.image.meme;

import std.conv;
import std.file;
import std.path;
import std.array;
import std.format;
import std.random;
import std.string;
import std.typecons;
import std.algorithm;
import std.stdio : writefln;

import dlib.math;
import dlib.image;

import ominbot.core.params;
import ominbot.core.image.utils;
import ominbot.core.image.fonts;


@safe:


SuperImage mutilateImage(string[] top, string[] bottom, string baseImage = null) @trusted {

    writefln!"Beginning mutilation...";

    // Load the main image
    SuperImage image;

    try {

        auto tryImage = baseImage ? loadPNG(baseImage) : randomImage();
        image = tryImage;

    } catch (ImageLoadException exc) {

        top = bottom = ["fool", "fool", "fool"];
        image = randomImage();

    }

    if (!image) return null;

    // Add a few images to mutilate
    foreach (num; 0 .. uniform(imageMinForegroundItems, imageMaxForegroundItems)) {

        // Load the images
        auto sample = randomImage();
        if (!sample) break;

        // Prepare transforms
        const scale = cast(float) image.width / sample.width / 2;
        const transX = uniform01 - 0.5;
        const transY = uniform01 - 0.5;
        const matrix = mat3([
            1, transY, 0,
            transX, 1, 0,
            transX/2, transY/2, 1
        ]);

        // Break it
        auto brokenImage = sample.affineTransformImage(matrix);

        // Get the region
        auto brokenRegion = brokenImage
            .region(0, 0, sample.width, sample.height);

        const posX = cast(uint) uniform(0, max(1, image.width - sample.width * scale));
        const posY = cast(uint) uniform(0, max(1, image.height - sample.height * scale));

        // Add the image
        image.addImage(
            brokenRegion,
            posX, posY,
            scale,
        );

        writefln!"adding at %s,%s scale %s"(posX, posY, scale);

    }

    // Add text
    image.addText(fontImpact, top, 0, 0, image.width);
    image.addText(fontImpact, bottom, 0, image.height - fontImpact.textHeight, image.width);

    // Save
    return image;

}

unittest {

    mutilateImage(["abcdef?!"], ["1234567890"]);

}

/// Get a random image
private SuperImage randomImage() @trusted {

    while (true) {

        auto path = randomImagePath();
        scope (success) writefln!"using png %s"(path);

        // Might have not gotten an image, fail instantly
        if (path is null) return null;

        // Try to load the image
        try return loadPNG(path);

        // Oops, failed, remove the image to prevent further problems like this
        // Also retry
        catch (ImageLoadException exc) {

            writefln!"invalid png %s! trying another..."(path);
            remove(path);

        }

    }

}

/// Find a random image path
private string randomImagePath() @trusted {

    // TODO: edit own images
    //const editOwn = ImageOutputPath.exists && uniform(0, ImageEditOwnRarity) == 0;

    auto images = "resources".dirEntries("bot-img-*.png", SpanMode.shallow);
    if (images.empty) return null;

    //return editOwn
    //    ? ImageOutputPath
    //    : images.array.choice;
    return images.array.choice;

}
