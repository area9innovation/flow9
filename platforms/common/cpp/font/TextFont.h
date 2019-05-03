#ifndef TEXTFONT_H
#define TEXTFONT_H

#include <string>

enum TextStyle {
    Normal, Italic, Oblique
};

enum TextWeight {
    Thin = 100,
    UltraLight = 200,
    Light = 300,
    Regular = 400,
    Medium = 500,
    SemiBold = 600,
    Bold = 700,
    ExtraBold = 800,
    Black = 900
};

struct TextFont {
    std::string family;
    TextWeight weight;
    TextStyle style;

    TextFont() {}
    TextFont(std::string family, TextWeight weight, TextStyle style) : family(family), weight(weight), style(style) {}

    bool operator== (const TextFont &tf2) const;
};

namespace std {
    template<>
    struct hash<TextFont> {
        std::size_t operator()(const TextFont& tf) const;
    };
}

#endif
