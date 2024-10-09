# 7 GUIs

See https://eugenkiss.github.io/7guis/

Summary lines of code:

|                | flow | react | java | red | svelte | foam | haskell | elm   | phix | scala |fabric|
|:---------------|:-----|:------|:-----|:----|:-------|:-----|:--------|:------|:-----|:------|------|
| 1: counter     | 11   | 13    | 46   | 3   | 6      | 6    | 9+      | 15++  | 17   | 33    | 6    |
| 2: temperature | 26   | 120   | 91   | 12  | 29     | 17   | 21+     | 93++  | 33   | 41    | 12   |
| 3: flight      | 84   | 120   | 158  | 46  | 71*    | 88   | 42+*    | 68++* | 67*  | 62    | 30   |
| 4: timer       | 35   | 105   | 97   | 21  | 53     | 83   | 30+     | 48++  | 57   | 56    | 21   |
| 5: crud        | 60   | 115   | 237  | 37  | 128    | 128  | 28+     | 117++ | 138  | 92    | 54   |
| 6: circles     | 137  | 442   | 276  | 121 | 130    | 140  | 66+     | N/A   | 216  | 148   |
| 7: cells       | 337  | 546   | 543  | N/A | N/A    | 309  | N/A     | N/A   | 444  | 249*  |


`*` incomplete: does not do coloring or error handling.

`+` there is a shared library of ~400 lines of helper functions, thus +66 lines per task.

`++` there is a shared library of 64 lines of helper functions, thus +12 lines per task.
