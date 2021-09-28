module ominbot.core.items;

import arsd.sqlite;

import ominbot.core.bot;
import ominbot.core.image.card;


@safe:


void prepareItems(Sqlite db) @trusted {

    // Perform this in a transaction
    db.query(`BEGIN TRANSACTION`);
    scope (success) db.query(`COMMIT TRANSACTION`);
    scope (failure) db.query(`ROLLBACK TRANSACTION`);

    // Create a registry of all items
    db.query(`

        CREATE TABLE IF NOT EXISTS items (
            id INTEGER PRIMARY KEY NOT NULL,
            name TEXT NOT NULL,

            -- There will always be exactly 1 to 3 tags. A bit silly, but anyway, it's just decorative anyway.
            tag1 TEXT NOT NULL,
            tag2 TEXT NOT NULL,
            tag3 TEXT NOT NULL,

            -- Type of the item
            type TEXT NOT NULL,

            -- Color scheme for the item
            primary_color INTEGER NOT NULL,
            secondary_color INTEGER NOT NULL
        )

    `);

    // Create a registry of all item owners
    db.query(`

        CREATE TABLE IF NOT EXISTS inventory (
            id INTEGER PRIMARY KEY NOT NULL,
            owner_id INTEGER,
            item_id INTEGER,
            count INTEGER,
            FOREIGN KEY(item_id) REFERENCES items(id)
        )

    `);

}

debug void createSamples(Sqlite db) @trusted {

    // Create an item card
    ItemCard card = {

        name: ["foo", "bar", "test", "item"],
        id: 0,

    };

    ItemCard invalidCard = {

        name: ["invalid", "item"],
        id: 0  // duplicate id

    };

    db.query(`DELETE FROM items WHERE id = 0`);

    auto result1 = db.createItem(card);
    auto result2 = db.createItem(invalidCard);

    assert(result1 == card);
    assert(result1 == result2);

}

// TODO: prevent creating an item if the prompt was repeated

/// Registers the item in the database, if no item with given ID already exists.
///
/// Returns: The registered item, or the item returned.
ItemCard createItem(Sqlite db, ItemCard card) @trusted {

    import std.conv, std.string;

    // Perform this in a transaction
    db.query(`BEGIN TRANSACTION`);
    scope (success) db.query(`COMMIT TRANSACTION`);
    scope (failure) db.query(`ROLLBACK TRANSACTION`);

    try db.query(
        `INSERT INTO items(id, name, type, tag1, tag2, tag3, primary_color, secondary_color)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
       card.id, card.name.join(" "), card.type, card.tags[0], card.tags[1], card.tags[2],
       card.backgroundColors.primary, card.backgroundColors.secondary
    );
    // TODO: add tags on insertion

    // Item already exists
    // TODO: update tag list
    catch (DatabaseException) {

        auto result = db.query(`SELECT * FROM items WHERE id=?`, card.id);

        assert(result.length == 1, "Invalid item row count after createItem SELECT query");

        auto row = result.front;

        ItemCard oldCard = {
            id: row["id"].to!uint,
            name: row["name"].split(" "),
            tags: [row["tag1"], row["tag2"], row["tag3"]],
            type: row["type"].to!ItemType,
        };

        return oldCard;

    }

   return card;

}

void giveItem(Sqlite db, ItemCard card, size_t owner, size_t count = 1) @trusted {

    assert(false, "unimplemented");

}

bool takeItem(Sqlite db, ItemCard card, size_t owner, size_t count = 1) @trusted {

    assert(false, "unimplemented");

}
