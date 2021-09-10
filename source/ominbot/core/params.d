module ominbot.core.params;

enum mapHeight = 200;

/// Radius of the (square) region to rearrange words within.
enum mapRearrangeRadius = 25;

/// Radius of the (square) region to lookup and use word within.
enum mapLookupRadius = 25;

/// URL address for the `public/` directory where Omin will place images and data dumps.
debug enum publicURL = "http://localhost";
else  enum publicURL = "https://omin.samerion.com";
