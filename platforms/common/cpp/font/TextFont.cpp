#include "TextFont.h"

bool TextFont::operator== (const TextFont &tf2) const {
    return std::hash<TextFont>()(*this) == std::hash<TextFont>()(tf2);
}

std::size_t std::hash<TextFont>::operator()(const TextFont& tf) const {
    return ((hash<std::string>()(tf.family)
             ^ (hash<int>()(tf.weight) << 1)) >> 1)
             ^ (hash<int>()(tf.style) << 1);
}
