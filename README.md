# stringReader

Wrappers for Lua string functions.


## Behavior

StringReader provides a *reader* object which can march through a string in linear order. This object combines search methods with an internal position index. Generally, when a search is successful, the position advances past the match region, and when unsuccessful, it stays put (or throws an error.)


### Terms

* u8Char: Unicode code point
* u8Unit: UTF-8 code unit (1-4 encoded bytes, representing a code point)
* eos: "end of string". (Byte index is greater than #str)


### Error Messages

The built-in errors do not emit any direct contents of the string. They can display argument numbers, types, line positions, and UTF-8 octet details. (Alternatively, the reader can be configured to just display "parsing failed" with a debug traceback.) If you need additional information while debugging, you can add print() calls in the codepaths where the error occurs. You can also get some information about the reader state by using the `self:_status()` method (needs to be uncommented -- see bottom of source file.)


### strict.lua

This module should cooperate with **strict.lua**, a common Lua troubleshooting library / snippet that throws errors when non-declared globals are accessed.


### Supported Lua Versions

Tested on LuaJIT 2.1.0 beta 3, Lua 5.4, and the LÖVE 11.4 Appimage (ebe628e).


## Public Functions

`stringReader.new([str], [opts])`: Creates a reader object.
`str`: The string to attach to the reader. *Default: empty string.*
`options`: A table of options to pass in.
`options.terse_errors`: If true, all error messages display "Parsing failed." only. *Default: false*
`options.hide_line_num`: If true, line numbers are not included in error messages. This is overridden by `terse_errors`. *Default: false*
`options.hide_char_num`: If true, per-line character numbers are not included in error messages. This is overridden by `hide_line_num`. *Default: false*


Reader variables of interest:

`self.str`: A reference to the current string.
`self.pos`: Current position in the string, in bytes. The position may exceed the size of the string, but a value less than 1 is invalid.
`self.c[1..9]`: A table that holds the results of string captures, in the range of 1 to 9. (NOTE: Most method calls reset all capture registers to nil as a first step.)


`stringReader.lineNum(str, pos)`: Returns the line number and character number at byte-position `pos` in string `str`, or `"(End of String)"` if the reader position exceeds the string size, or `"(Out of bounds)"` if `pos` is less than 1.



## Reader Methods

Some methods have a `*Req()` variant which raises a Lua error if the search is not successful. For these variants, you can pass an optional `err_reason` string which will in turn be passed onto the error handler in the event of a failure.


### Main Interface

`self:peek([n], [n2])`: Extract a substring from `self.pos + n` to `self.pos + n2` without advancing the reader position. `n` defaults to 0, and n2 defaults to `n`. Called without any arguments, this will return the byte at `self.pos` (or an empty string if the position is end-of-string.)

* Advances position: No


`self:u8char()`: Return the UTF-8 code unit at `self.pos`. If position is end-of-string, return nil. If there is an issue decoding the code unit (self.pos is on a continuation byte, unsupported byte), raise a Lua error.

* Advances position: Yes, if successful


`self:u8Chars(n)`: Return `n` UTF-8 code units starting at `self.pos`. If either the starting or final position is eos, return nil. If there is a problem decoding the UTF-8 bytes, raise a Lua error.

* Advances position: Yes, if successful


`self:byteChar()`: Return a one-byte substring in `self.str` at `self.pos`. If position is end-of-string, return nil.

* Advances position: Yes, if successful

**WARNING**: This may place `self.pos` on a UTF-8 continuation byte.


`self:byteChars(n)`: Return substring from `self.pos` to `self.pos + n` or `#self.str`, whichever is shorter. If position is end-of-string, return nil. `n` must be at least 1.

* Advances position: Yes, if successful

**WARNING**: This may place `self.pos` on a UTF-8 continuation byte.


`self:fetch(ptn, [literal])`, `self:fetchReq(ptn, [literal], [err_reason])`: Search for a pattern starting at `self.pos`. If `literal` is true, all pattern magic symbols are disabled. Returns the match if successful, nil otherwise.

* Advances position: Yes, if successful


`self:cap(ptn)`, `self:capReq(ptn, [err_reason])`: Search for a pattern with captures starting at `self.pos`, using `ptn` as the string pattern. Returns true if the match was successful, nil if not. Stores up to 9 string captures (the max supported by Lua) from the search in `self.c[1..9]`. (The captures are stored in a table so that you can access them even if `self:cap()` is part of an if/elseif/else block.)

* Advances position: Yes, if successful


`self:lit(chunk)`, `self:litReq(chunk, [err_reason])`: Check if the string literal (not a pattern) `chunk` appears at `self.pos` - `self.pos + #chunk-1`. Returns the string chunk on success, or nil if there wasn't an exact match. The search is anchored to `self.pos`.

* Advances position: Yes, if successful


`self:ws()`, `self:wsReq([err_reason])`: March over "optional" whitespace, from `self.pos` to the first-encountered non-whitespace character. If no such character is found, set `self.pos` to end-of-string. If `self.pos` was already on a non-whitespace char, then do nothing.

* Advances position: Yes, if successful

NOTE: `self:wsReq()` raises a Lua error if `self.pos` wasn't on a whitespace char at call time.


`self:wsNext()`: Assumes `self.pos` is currently on a non-whitespace char, and that you wish to step forward to the next whitespace char. If `self.pos` is currently on whitespace, stays put.

* Advances position: Yes, if successful


`self:reset()`: Resets `self.pos` to the first byte in the string.

* Advances position: Resets to 1


`self:isEOS()`: Returns true if `self.pos` is greater than the string size, in bytes. Returns false otherwise.

* Advances position: No


`self:goEOS()`: Moves `self.pos` beyond the last byte in the string.

* Advances position: Always sets `self.pos` to `#self.str + 1`


### Utility Methods

`self:errorHalt(err_str, [err_level])`: Raises a Lua error, optionally concatenating the reader's current line number and character position (if they can be determined) to `err_str`. `err_level` defaults to 2. Use this when there is a problem with parsing. For unrelated errors (bad arguments, etc.), use the standard `error()`.

* Advances position: N/A


`self:warn(warn_str)`: Similar to `errorHalt()`, but prints to the terminal instead of raising an error.

* Advances position: N/A


`self:lineNum()`: Returns the line number at the reader's current byte-index, and the byte-index of the start of the line, or false if it's end-of-string.

* Advances position: No


`self:_status([show_captures])`: Intended for debugging. Prints the current line number, the current char at `self.pos` (or `"(eos)"` if the reader is at end-of-string), the current position, and the string size in bytes. If `show_captures` is true, also prints the contents of the capture table (`self.c[1..9]`).

*NOTE: This function is commented out by default. See bottom of source file to uncomment.*

* Advances position: No.


`self:newStr(new_str)`: Changes the reader's string to `new_str` and resets position to start.

* Advances position: Always sets `self.pos` to 1


`self:clearCaptures()`: Manually clears the reader's capture table (`self.c[1..9]`). (Most reader methods do this as a first step.)

* Advances position: No.


## License (MIT)

Copyright (c) 2022 RBTS

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
