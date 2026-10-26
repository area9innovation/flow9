#include "TextFont.h"

#include <cstring>

bool TextFont::operator== (const TextFont &tf2) const {
    return family == tf2.family && weight == tf2.weight && style == tf2.style;
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
    default: return "";
    }
}

std::string TextFont::styleSuffix() {
    switch(this->style) {
    case Normal: return "";
    case Italic: return "Italic";
    case Oblique: return "Oblique";
    default: return "";
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
    if (!slope.empty())
        slope[0] = (char)toupper((unsigned char)slope[0]);
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

struct FamilySuffix {
    const char *text;
    bool isStyle;
    TextWeight weight;
    TextStyle style;
};

static const FamilySuffix familySuffixes[] = {
    { "Thin", false, TextWeight::Thin, TextStyle::Normal },
    { "ExtraLight", false, TextWeight::UltraLight, TextStyle::Normal },
    { "UltraLight", false, TextWeight::UltraLight, TextStyle::Normal },
    { "SemiLight", false, TextWeight::Light, TextStyle::Normal },
    { "Light", false, TextWeight::Light, TextStyle::Normal },
    { "Regular", false, TextWeight::Regular, TextStyle::Normal },
    { "Normal", false, TextWeight::Regular, TextStyle::Normal },
    { "Medium", false, TextWeight::Medium, TextStyle::Normal },
    { "SemiBold", false, TextWeight::SemiBold, TextStyle::Normal },
    { "DemiBold", false, TextWeight::SemiBold, TextStyle::Normal },
    { "Bold", false, TextWeight::Bold, TextStyle::Normal },
    { "ExtraBold", false, TextWeight::ExtraBold, TextStyle::Normal },
    { "UltraBold", false, TextWeight::ExtraBold, TextStyle::Normal },
    { "Black", false, TextWeight::Black, TextStyle::Normal },
    { "ExtraBlack", false, TextWeight::Black, TextStyle::Normal },
    { "Italic", true, TextWeight::Regular, TextStyle::Italic },
    { "Oblique", true, TextWeight::Regular, TextStyle::Oblique },
};

// The longest match wins, so "ExtraBold" is never read as "Bold".
static const FamilySuffix *longestFamilySuffix(const std::string &family) {
    const FamilySuffix *best = nullptr;
    for (const FamilySuffix &suffix : familySuffixes) {
        if (endsWith(family, suffix.text) && (!best || strlen(suffix.text) > strlen(best->text)))
            best = &suffix;
    }
    return best;
}

TextFont TextFont::makeWithParameters(std::string fontfamily, int weight, std::string slope){
    TextFont font = TextFont();
    font.weight = (TextWeight)weight;
    font.style = textStyleByName(slope);

    while (const FamilySuffix *suffix = longestFamilySuffix(fontfamily)) {
        if (suffix->isStyle)
            font.style = suffix->style;
        else
            font.weight = suffix->weight;
        fontfamily = chop(fontfamily, strlen(suffix->text));
    }

    font.family = fontfamily;

    return font;
}
