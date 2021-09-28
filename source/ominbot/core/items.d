module ominbot.core.items;

import arsd.sqlite;

import ominbot.core.bot;
import ominbot.core.image.card;

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
            tag1 TEXT,
            tag2 TEXT,
            tag3 TEXT,

            -- Type of the item
            type INTEGER NOT NULL,

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

void createItem(ItemCard card) {

    assert(false, "unimplemented");

}

void giveItem(ItemCard card, size_t owner, size_t count = 1) {

    assert(false, "unimplemented");

}

bool takeItem(ItemCard card, size_t owner, size_t count = 1) {

    assert(false, "unimplemented");

}
