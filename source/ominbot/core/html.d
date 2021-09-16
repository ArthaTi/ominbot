module ominbot.core.html;

import elemi;
import fs = std.file;

import ominbot.core.map;
import ominbot.core.params;
import ominbot.core.structs;


@safe:


struct Document {

    string title;

}

string render(Document document, Element data) {

    return Element.HTMLDoctype
        ~ elem!"html"(
            elem!"head"(
                Element.EncodingUTF8,
                Element.MobileViewport,
                elem!"title"(document.title),
                elem!"style"(
                    fs.readText("resources/bot.css")
                ),
            ),
            elem!"body"(
                elem!"header"(
                    elem!"span"("Ominbot"),
                ),
                data,
            ),
        );

}

string renderMap(MapGroup group) {

    import std.container;

    Document document = {

        title: "Relation map"

    };

    auto visited = redBlackTree!MapGroup;

    Element renderGroup(MapGroup group) {

        import std.format;

        // Mark as visited
        visited.insert(group);

        auto header = format!"%s (%s)"(group.id, group.entries.length);

        // List entries
        auto entriesE = elem!("div", q{ class="group" })(
            elem!"p"(header)
        );
        foreach (entry; group.entries) {

            entriesE.add!"p"(entry.text);

        }

        // List relations
        auto relationsE = elem!"ul";
        foreach (relation; group.related) {

            // Stop if visited enough groups
            if (visited.length >= maxLookupDistance) break;

            // Ignore if this relation had been visited
            if (relation in visited) continue;

            // Add this relation to ouput
            relationsE.add(renderGroup(relation));

        }

        return elem!"li"(entriesE, relationsE);

    }

    return document.render(
        elem!"main"(
            elem!"h1"("Relation map"),
            elem!"p"(),
            elem!("ul", q{ class="relation-map" })(renderGroup(group))
        ),
    );

}
