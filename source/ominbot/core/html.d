module ominbot.core.html;

import elemi;
import fs = std.file;

import ominbot.core.map;
import ominbot.core.params;


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

//string renderMap(RelationMap!mapHeight map) {
//
//    Document document = {
//
//        title: "Relation map"
//
//    };
//
//    auto table = elem!"table";
//    auto row = elem!"tr";
//
//    size_t lastY = 0;
//
//    foreach (x, y, entry; map.scan) {
//
//        if (y != lastY) {
//
//            lastY = y;
//            table.add(row);
//            row = elem!"tr";
//
//        }
//
//        string[string] attributes;
//
//        if (x == map.position.x && y == map.position.y) {
//
//            attributes["class"] = "position";
//
//        }
//
//        row.add!"td"(attributes, entry.text);
//
//    }
//
//    table.add(row);
//
//    return document.render(
//        elem!"main"(
//            elem!"h1"("Relation map"),
//            elem!"p"(),
//            table,
//        ),
//    );
//
//}
