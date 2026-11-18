#include "core/ByteCodeRunner.h"

#include <array>
#include <cstdlib>

static void check(bool ok, const char *message)
{
    if (!ok) {
        std::cerr << message << '\n';
        std::exit(1);
    }
}

template <typename F>
static void rejects(CodeMemory &code, F operation)
{
    const FlowPtr position = code.GetPosition();
    try {
        operation();
    } catch (const CodeMemory::DecodeError &) {
        check(code.GetPosition() == position, "Failed bounds check moved the cursor");
        return;
    }
    check(false, "Reader did not reject an invalid request");
}

int main(int argc, char **argv)
{
    char letters[] = "abcd";
    CodeMemory code(letters, 1, 3);
    check(code.CanRead(3) && !code.CanRead(4), "Byte range check");
    check(!code.CanRead(-1) && !code.CanRead(1, 0), "Invalid count or width");
    check(code.CanRead(1, 2) && !code.CanRead(2, 2), "Element range check");
    rejects(code, [&] { code.ReadInt32(); });
    rejects(code, [&] { code.SkipInt(); });
    rejects(code, [&] { code.GetBytes(-1); });
    rejects(code, [&] { code.GetBytes(4); });
    rejects(code, [&] { code.ReadString(-1); });
    rejects(code, [&] { code.ReadString(4); });
    rejects(code, [&] { code.ReadWideString(2); });
    check(code.RelativeTarget(MakeFlowPtr(3), -2) == 1, "Backward target within range");
    rejects(code, [&] { code.RelativeTarget(MakeFlowPtr(3), -3); });
    rejects(code, [&] { code.RelativeTarget(MakeFlowPtr(3), 2); });
    code.SetPosition(MakeFlowPtr(0));
    check(code.ReadString(3) == "bcd" && code.Eof(), "Exact fit at a nonzero start");
    check(code.ReadString(0).empty(), "Zero-length read at end");
    rejects(code, [&] { code.ReadByte(); });

    unicode_string text(255, 0x263a);
    code.SetBuffer(reinterpret_cast<char*>(&text[0]), 0, int(text.size() * 2));
    check(code.ReadWideString(255) == text && code.Eof(), "Maximum short UTF-16 string");
    std::vector<char> wide_instruction(2 + text.size() * 2);
    wide_instruction[0] = CWString;
    wide_instruction[1] = char(text.size());
    memcpy(wide_instruction.data() + 2, text.data(), text.size() * 2);
    code.SetBuffer(wide_instruction.data(), 0, int(wide_instruction.size()));
    FlowInstruction wide;
    check(code.ParseOpcode(&wide) && code.Eof() && wide.StrValue == encodeUtf8(text),
          "Unsigned UTF-16 instruction length");

    char type[] = {FTMutable, FTTypedArray, FTTypedRefTo, FTInt};
    char is_mutable = false;
    code.SetBuffer(type, 0, sizeof(type));
    auto markers = code.ReadFieldType(&is_mutable, NULL);
    check(code.Eof() && is_mutable && markers.size() == 3 && markers.back() == FTInt,
          "Nested mutable field type");

    std::array<char, CodeMemory::MaxFieldTypeDepth> deep_type;
    deep_type.fill(FTTypedArray);
    deep_type.back() = FTInt;
    code.SetBuffer(deep_type.data(), 0, deep_type.size());
    markers = code.ReadFieldType(&is_mutable, NULL);
    check(code.Eof() && !is_mutable && markers.size() == deep_type.size(), "Field type depth limit");

    for (OpCode opcode : {CSwitch, CSimpleSwitch}) {
        // One case and a default, both falling through to the next instruction.
        const int table[] = {1, 0, 0, 0};
        char bytes[1 + sizeof(table) + 1];
        bytes[0] = opcode;
        memcpy(bytes + 1, table, sizeof(table));
        bytes[sizeof(bytes) - 1] = CLast;
        code.SetBuffer(bytes, 0, sizeof(bytes));
        FlowInstruction sw;
        check(code.ParseOpcode(&sw) && sw.IntValue == 1 && sw.cases[0].id == 0
              && sw.cases[0].target == code.GetPosition() && code.ReadOpcode() == CLast && code.Eof(),
              "Switch table with one complete entry");
    }

    for (int i = 1; i < argc; ++i) {
        ByteCodeRunner runner{std::string(argv[i])};
        check(!runner.IsErrorReported(), "Compiler output did not pass bytecode validation");
        runner.RunMain();
        check(!runner.IsErrorReported(), "Compiler output did not run successfully");
    }
}
