# dayOfWeek : io (year: int, month: int, day: int) -> int
#  Monday is zero
import times

func dayOfWeek1*(year: int32, month: int32, day: int32): int32 =
    if (month >= 1 and month <= 12):
        return int32(ord(getDayOfWeek(day, Month(month), year)))
    else:
        return 0