#include "TextFont.h"

bool TextFont::operator== (const TextFont &tf2) const {
    return STL_HASH<TextFont>()(*this) == STL_HASH<TextFont>()(tf2);
}

std::size_t STL_HASH<TextFont>::operator()(const TextFont& tf) const {
    return ((hash<std::string>()(tf.family)
             ^ (hash<int>()(tf.weight) << 1)) >> 1)
             ^ (hash<int>()(tf.style) << 1);
}

std::string TextFont::suffix() {
    return weightSuffix() + styleSuffix();
}


std::string TextFont::weightSuffix() {
    switch(this->weight) {
    case Thin: return "Thin";
    case UltraLight: return "UltraLight";
    case Light: return "Light";
    case Regular: return "";
    case Medium: return "Medium";
    case SemiBold: return "SemiBold";
    case Bold: return "Bold";
    case ExtraBold: return "ExtraBold";
    case Black: return "Black";
    }
}

std::string TextFont::styleSuffix() {
    switch(this->style) {
    case Normal: return "";
    case Italic: return "Italic";
    case Oblique: return "Oblique";
    }
}

std::string chop(std::string  text, size_t count) {
    return text.substr(0, text.size() - count);
}

bool endsWith(std::string const& text, std::string const& suffix) {
    if (text.length() < suffix.length()) return false;
    return (0 == text.compare(text.length() - suffix.length(), suffix.length(), suffix));
}

TextStyle TextFont::textStyleByName(std::string slope) {
    slope[0] = (char)toupper(slope[0]);
    if (!slope.compare("Italic")) {
        return TextStyle::Italic;
    } else if (!slope.compare("Oblique")) {
        return TextStyle::Oblique;
    } else {
        return TextStyle::Normal;
    }
}

TextFont TextFont::makeWithFamily(std::string family) {
    return makeWithParameters(family, TextWeight::Regular, "");
}

TextFont TextFont::makeWithParameters(std::string fontfamily, int weight, std::string slope){
    TextFont font = TextFont();
    font.weight = (TextWeight)weight;
    font.style = textStyleByName(slope);

    while (true) {
        size_t chopSize = 0;
        if (endsWith(fontfamily, "Thin")) {
            font.weight = TextWeight::Thin;
            chopSize = 4;
        } else if (endsWith(fontfamily, "UltraLight")) {
            font.weight = TextWeight::UltraLight;
            chopSize = 10;
        } else if (endsWith(fontfamily, "Light")) {
            font.weight = TextWeight::Light;
            chopSize = 5;
        } else if (endsWith(fontfamily, "Regular")) {
            font.weight = TextWeight::Regular;
            chopSize = 7;
        } else if (endsWith(fontfamily, "Normal")) {
            font.weight = TextWeight::Regular;
            chopSize = 6;
        } else if (endsWith(fontfamily, "Medium")) {
            font.weight = TextWeight::Medium;
            chopSize = 6;
        } else if (endsWith(fontfamily, "SemiBold")) {
            font.weight = TextWeight::SemiBold;
            chopSize = 8;
        } else if (endsWith(fontfamily, "Bold")) {
            font.weight = TextWeight::Bold;
            chopSize = 4;
        } else if (endsWith(fontfamily, "ExtraBold")) {
            font.weight = TextWeight::ExtraBold;
            chopSize = 9;
        } else if (endsWith(fontfamily, "Black")) {
            font.weight = TextWeight::Black;
            chopSize = 5;
        } else if (endsWith(fontfamily, "Italic")) {
            font.style = TextStyle::Italic;
            chopSize = 6;
        } else if (endsWith(fontfamily, "Oblique")) {
            font.style = TextStyle::Oblique;
            chopSize = 7;
        } else {
            break;
        }

        fontfamily = chop(fontfamily, chopSize);
    }

    font.family = fontfamily;

    return font;
}
