local path = ... and (...):match("(.-)[^%.]+$") or ""

local stringReader = require(path .. "string_reader")

local errTest = require(path .. "test.lib.err_test")
local strict = require(path .. "test.lib.strict")

local _mt_reader = stringReader._mt_reader

print("\n * PUBLIC FUNCTIONS * \n")

do
	print("\nTest: " .. errTest.register(stringReader.new, "stringReader.new") ) -- (str)

	print("\n[+] instance creation.")
	errTest.expectPass(stringReader.new, "foobar")
	
	print("\n[+] passing nil causes the reader to start with an empty string. Discouraged but valid use.")
	errTest.expectPass(stringReader.new, nil)

	print("\n[-] arg #1 wrong type")
	errTest.expectFail(stringReader.new, true)
	
	print("\n[-] arg #2 wrong type")
	errTest.expectFail(stringReader.new, "foobar", true)
end

do
	print("\nTest: " .. errTest.register(stringReader.lineNum, "stringReader.lineNum") ) -- (str, pos)

	local str = "12345678\n9æbc\ndef"

	print("TEST STRING: |" .. str .. "|")

	print("\n[ad hoc] Expected behavior.")
	for pos = 1, #str do
		local line_n, column_n = stringReader.lineNum(str, pos)
		print("pos", pos, "char", string.sub(str, pos, pos), "line_n", line_n, "column_n", column_n)
	end

	print("\n[+] Index out of bounds (acceptable behavior)")
	errTest.expectPass(stringReader.lineNum, str, -1)
	errTest.expectPass(stringReader.lineNum, str, #str + 1)

	print("\n[-] Arg #1 bad type")
	errTest.expectFail(stringReader.lineNum, nil, 2)

	print("\n[-] Arg #2 bad type")
	errTest.expectFail(stringReader.lineNum, str, nil)
end

print("\n * READER METHODS * \n")

do
	print("\nTest: " .. errTest.register(_mt_reader.reset, "_mt_reader.reset") ) -- ()

	print("(No error paths to test. Try advancing and returning to pos 1. Raise error if unsuccessful.)")

	local str = "12345678"
	local r = stringReader.new(str)

	r:byteChar()
	r:byteChar()
	if r.pos == 1 then
		error("r:byteChar() advance past pos 1 failed.")
	end
	r:reset()
	if r.pos ~= 1 then
		error("r:reset() return to pos 1 failed.")
	end

	print("^ Test passed.")
end

do
	print("\nTest: " .. errTest.register(_mt_reader.isEOS, "_mt_reader.isEOS") ) -- ()

	local str = "1234"
	local r = stringReader.new(str)

	print("\n[+] expected behavior. Soft failures: given the string '" .. str .. "', check eos at pos 1 (F), pos #str (F), and pos #str + 1 (T).")
	r.pos = 1
	errTest.okErrExpectFail(_mt_reader.isEOS, r)
	r.pos = #r.str
	errTest.okErrExpectFail(_mt_reader.isEOS, r)
	r.pos = #r.str + 1
	errTest.okErrExpectPass(_mt_reader.isEOS, r)

	print("\n[-] invalid reader state: r.pos must be a number >= 1")
	r.pos = -1
	errTest.expectFail(_mt_reader.isEOS, r, 1)
	r.pos = "wrong_type"
	errTest.expectFail(_mt_reader.isEOS, r, 1)
end


do
	print("\nTest: " .. errTest.register(_mt_reader.lineNum, "_mt_reader.lineNum") ) -- ()

	local str = "12345678\n9abc\ndef"

	print("TEST STRING: |" .. str .. "|")

	local r = stringReader.new(str)
	print("\n[+] Expected behavior.")
	while r.pos < #str do
		local _, val = errTest.expectPass(_mt_reader.lineNum, r)
		print("r.pos", r.pos, "char", string.sub(r.str, r.pos, r.pos), "val", val)
		r:byteChar()
	end

	-- This uses the same core function as stringReader.lineNum, so just check the reader state assertions.
	print("\n[-] Corrupt reader state")
	r = stringReader.new(str)
	r.pos = -1
	errTest.expectFail(_mt_reader.lineNum, r)
	r = stringReader.new(str)
	r.pos = "wrong_type"
	errTest.expectFail(_mt_reader.lineNum, r)
end


-- From this point, I'm going to assume that invalid reader state assertions are working. The only way they might not
-- is if _assertState() is forgotten at the start of applicable public functions / methods.

do
	print("\nTest: " .. errTest.register(_mt_reader.errorHalt, "_mt_reader.errorHalt") ) -- (err_str, err_level)

	local r
	r = stringReader.new("foobar")

	print("[-] Expected behavior: raising an error with a line number when there is a fatal parsing issue.")
	print("r.pos", r.pos)
	errTest.expectFail(_mt_reader.errorHalt, r, "Test error raised intentionally.")
	
	print("^ Should be Line 1 Character 1")
	
	-- NOTE: make new reader objects after every intentional failure to ensure the internal state is good.
	r = stringReader.new("foobar")
	r:byteChar()
	print("r.pos", r.pos)
	errTest.expectFail(_mt_reader.errorHalt, r, "Another test error.")
	
	print("^ Should be Line 1 Character 2")
	
	r = stringReader.new("foobar")
	r:byteChars(2)
	print("r.pos", r.pos)
	errTest.expectFail(_mt_reader.errorHalt, r, "Once more.")
	
	print("^ Should be Line 1 Character 3")

	r = stringReader.new("foobar")
	r:byteChars(3)
	print("r.pos", r.pos)
	errTest.expectFail(_mt_reader.errorHalt, r, "Once more.")

	print("^ Should be Line 1 Character 4")

	-- Char # on line
	--                                         |        
	--               0000000 0000000 0000000001111111111
	--               1234567 1234567 1234567890123456789
	local big_str = "foobar\nbazbam\noooooooooooooooooah"
	--               0000000 0011111 1111122222222223333
	--               1234567 8901234 5678901234567890123
	--                                         |        
	-- Pos # in string as a whole

	r = stringReader.new(big_str)
	r:byteChars(24)
	print("r.pos", r.pos)
	errTest.expectFail(_mt_reader.errorHalt, r, "One more test error.")
	
	print("^ Should be Line 3 Character 11")

	print("\n[+] Handle arg #1 bad type 'gracefully'")
	r = stringReader.new(big_str)
	errTest.expectFail(_mt_reader.errorHalt, r, nil)
	errTest.expectFail(_mt_reader.errorHalt, r, function() end)

	print("\n[-] Arg #2 bad type will be caught by error()")
	errTest.expectFail(_mt_reader.errorHalt, r, "Bad error", function() end)

	print("\n[+] Handle corrupt reader state 'gracefully'")
	r = stringReader.new(big_str)
	r.pos = -1
	errTest.expectFail(_mt_reader.errorHalt, r, "Corrupt reader pos")

	r = stringReader.new(big_str)
	r.str = false
	errTest.expectFail(_mt_reader.errorHalt, r, "Corrupt reader string")
	
	
	print("\n[-] Try out the option to hide character numbers")
	r = stringReader.new("foobar", {hide_char_num = true})
	r:byteChars(2)
	print("r.pos", r.pos)
	errTest.expectFail(_mt_reader.errorHalt, r, "Should not display the character number.")
end


do
	if not _mt_reader._status then
		print("\n\nWARNING: '_status()' is commented out in the default repository. You need to uncomment it for converage here.\n\n")

	else
		print("\nTest: " .. errTest.register(_mt_reader._status, "_mt_reader._status") ) -- ()

		local r

		print("\n[ad hoc] Expected behavior (it fails because it always returns nil)")
		r = stringReader.new("foobar")

		r:_status()

		print("\n[ad hoc] Try displaying capture table contents")
		r:cap("(foo)(bar)")
		r:_status(true)
	end

	print("\n\n")
end


do
	print("\nTest: " .. errTest.register(_mt_reader.peek, "_mt_reader.peek") ) -- (n, n2)
	local r
	
	print("\n[+] expected behavior. peek() almost always returns something, even an empty string, because it's just a wrapper for string.sub().")
	r = stringReader.new("foobar")
	local _, res
	_, res = errTest.expectPass(_mt_reader.peek, r); print(res)
	_, res = errTest.expectPass(_mt_reader.peek, r, 1); print(res)
	_, res = errTest.expectPass(_mt_reader.peek, r, 2); print(res)
	_, res = errTest.expectPass(_mt_reader.peek, r, 0, 2); print(res)
	_, res = errTest.expectPass(_mt_reader.peek, r, -100, 100); print(res)
	_, res = errTest.expectPass(_mt_reader.peek, r, -100, -100); print(res)

	print("\n[-] arg #1 bad type.")
	r = stringReader.new("foobar")
	_, res = errTest.expectFail(_mt_reader.peek, r, false)

	print("\n[-] arg #2 bad type.")
	r = stringReader.new("foobar")
	_, res = errTest.expectFail(_mt_reader.peek, r, nil, false)
end


do
	print("\nTest: " .. errTest.register(_mt_reader.byteChar, "_mt_reader.byteChar") ) -- ()
	local r

	print("\n[+] expected behavior")
	r = stringReader.new("foobar")
	local _, res
	res = errTest.okErrExpectPass(_mt_reader.byteChar, r); print(res, "(should print 'f')")
	res = errTest.okErrExpectPass(_mt_reader.byteChar, r); print(res, "(should print 'o')")
	res = errTest.okErrExpectPass(_mt_reader.byteChar, r); print(res, "(should print 'o')")
	res = errTest.okErrExpectPass(_mt_reader.byteChar, r); print(res, "(should print 'b')")
	res = errTest.okErrExpectPass(_mt_reader.byteChar, r); print(res, "(should print 'a')")
	res = errTest.okErrExpectPass(_mt_reader.byteChar, r); print(res, "(should print 'r')")

	print("\n[-] Expected 'failure' -- returns nil when eos")
	res = errTest.okErrExpectFail(_mt_reader.byteChar, r); print(res) -- nil

	print("\n[-] char() guards against passing an arg #1, to help catch 'char|chars' typos")
	_, res = errTest.expectFail(_mt_reader.byteChar, r, 14); print(res)
end


do
	print("\nTest: " .. errTest.register(_mt_reader.byteChars, "_mt_reader.byteChars") ) -- (n)
	local r

	print("\n[+] Expected behavior.")
	r = stringReader.new("foobar")
	local chars, res
	chars, res = errTest.okErrExpectPass(_mt_reader.byteChars, r, 3); print(chars, res, "(should print 'foo')")
	chars, res = errTest.okErrExpectPass(_mt_reader.byteChars, r, 3); print(chars, res, "(should print 'bar')")

	print("\n[+] Expected 'failure' -- returns nil when eos")
	chars, res = errTest.okErrExpectFail(_mt_reader.byteChars, r, 3); print(chars, res) -- nil
	
	print("\n[-] arg #1 bad type")
	chars, res = errTest.expectFail(_mt_reader.byteChars, r, nil);
	
	print("\n[-] arg #1 must be at least 1")
	chars, res = errTest.expectFail(_mt_reader.byteChars, r, 0);
end


do
	print("\nTest: " .. errTest.register(_mt_reader.u8Char, "_mt_reader.u8Char") )
	local r
	r = stringReader.new("fæbar")
	
	print("\n[-] arg #1 bad type (needs to be nil)")
	errTest.expectFail(_mt_reader.u8Char, r, 55);
	
	print("\n[ad hoc] Expected behavior.")
	local char, res
	char = _mt_reader.u8Char(r); print(char, "(should print 'f')")
	char = _mt_reader.u8Char(r); print(char, "(should print 'æ')")
	char = _mt_reader.u8Char(r); print(char, "(should print 'b')")
	char = _mt_reader.u8Char(r); print(char, "(should print 'a')")
	char = _mt_reader.u8Char(r); print(char, "(should print 'r')")
	char = _mt_reader.u8Char(r); print(char, "(should print nil)")
end

do
	print("\nTest: " .. errTest.register(_mt_reader.u8Chars, "_mt_reader.u8Chars") )
	local r
	r = stringReader.new("faæebar!????")

	print("\n[-] arg #1 bad type")
	errTest.expectFail(_mt_reader.u8Chars, r, nil);

	print("\n[ad hoc] Expected behavior.")
	local char, bytes_read
	char, bytes_read = _mt_reader.u8Chars(r, 3); print(char, bytes_read) -- faæ
	char, bytes_read = _mt_reader.u8Chars(r, 3); print(char, bytes_read) -- eba
	char, bytes_read = _mt_reader.u8Chars(r, 3); print(char, bytes_read) -- r!?
	char, bytes_read = _mt_reader.u8Chars(r, 3); print(char, bytes_read) -- nil
end


do
	print("Ad hoc test self:ws(), self:wsNext()")
	local r
	r = stringReader.new("fa æe bar!? ???")

	print("\n[ad hoc] Expected behavior.")
	local char, bytes_read
	print(r.pos) -- 1
	_mt_reader.ws(r); print(r.pos) -- 1
	_mt_reader.ws(r); print(r.pos) -- 1
	_mt_reader.byteChars(r, 2); print(r.pos) -- 3
	_mt_reader.ws(r); print(r.pos) -- 4

	r:reset()
	_mt_reader.byteChars(r, 2); print(r.pos) -- 3
	_mt_reader.wsNext(r); print(r.pos) -- 3
end


do
	print("\nTest: " .. errTest.register(_mt_reader.wsReq, "_mt_reader.wsReq") )
	local r
	r = stringReader.new("fa æe bar!? ???")

	print("\n[+] expected behavior")
	_mt_reader.byteChars(r, 2); print(r.pos) -- 3
	errTest.expectPass(_mt_reader.wsReq, r); print(r.pos) -- 4
	
	_mt_reader.reset(r)

	print("\n[-] missing expected whitespace")
	errTest.expectFail(_mt_reader.wsReq, r)
	
	print("\n[-] custom message for missing expected whitespace")
	errTest.expectFail(_mt_reader.wsReq, r, "Oops.")
end

do
	print("\nTest: " .. errTest.register(_mt_reader.goEOS, "_mt_reader.goEOS") )
	local r
	r = stringReader.new("fa æe bar!? ???")

	print("\n[+] expected behavior")
	_mt_reader.goEOS(r); print(r.pos) -- 16+1

end

do
	print("\nTest: " .. errTest.register(_mt_reader.warn, "_mt_reader.warn") )
	local r
	r = stringReader.new("fa æe bar!? ???")

	print("\n[+] Expected behavior.")
	errTest.expectPass(_mt_reader.warn, r, "Warning")
	
	print("\n[-] arg #1 bad type")
	errTest.expectFail(_mt_reader.warn, r, nil)
end

do
	print("\nTest: " .. errTest.register(_mt_reader.lit, "_mt_reader.lit") )
	local r
	r = stringReader.new("fa æe bar!? ???")
	local ok, res
	print("\n[+] expected behavior.")
	ok, res = errTest.expectPass(_mt_reader.lit, r, "fa æ")
	print(ok, res, r.pos)
	
	print("\n[-] arg #1 bad type")
	errTest.expectFail(_mt_reader.lit, r, nil)
end

do
	print("\nTest: " .. errTest.register(_mt_reader.litReq, "_mt_reader.litReq") )
	local r
	r = stringReader.new("fa æe bar!? ???")
	local ok, res
	print("\n[+] expected behavior.")
	ok, res = errTest.expectPass(_mt_reader.litReq, r, "fa æ")
	print(ok, res, r.pos)
	
	print("\n[-] arg #1 bad type")
	errTest.expectFail(_mt_reader.litReq, r, nil)
	
	print("\n[-] arg #1 no match")
	r:reset()
	errTest.expectFail(_mt_reader.litReq, r, "nothing here", "Very important search function failed!")
end

do
	print("\nTest: " .. errTest.register(_mt_reader.fetch, "_mt_reader.fetch") )
	local r
	r = stringReader.new("fa æe bar!? ???")
	local ok, res
	print("\n[+] expected behavior.")
	ok, res = errTest.expectPass(_mt_reader.fetch, r, "fa æ")
	print(ok, res, r.pos)
	
	print("\n[+] test literal mode")
	r = stringReader.new(".....^.(%?).$.....")
	ok, res = errTest.expectPass(_mt_reader.fetch, r, "^.(%?).$", true)
	print(ok, res, r.pos)
	
	print("\n[-] arg #1 bad type")
	errTest.expectFail(_mt_reader.fetch, r, nil)
end

do
	print("\nTest: " .. errTest.register(_mt_reader.fetchReq, "_mt_reader.fetchReq") )
	local r
	r = stringReader.new("fa æe bar!? ???")
	local ok, res
	print("\n[+] expected behavior.")
	ok, res = errTest.expectPass(_mt_reader.fetchReq, r, "fa æ")
	print(ok, res, r.pos)
	
	print("\n[-] arg #1 bad type")
	errTest.expectFail(_mt_reader.fetchReq, r, nil)

	print("\n[-] arg #1 no match")
	r:reset()
	-- (mind the literal bool between the search pattern and the error string)
	errTest.expectFail(_mt_reader.fetchReq, r, "nothing here", false, "Very important search function failed!")
	
end

do
	print("\nTest: " .. errTest.register(_mt_reader.cap, "_mt_reader.cap") )
	local r
	r = stringReader.new("fa æe bar!? ???")
	local ok, res
	print("\n[+] expected behavior.")
	ok, res = errTest.expectPass(_mt_reader.cap, r, "(f).-(æ).-(bar)")
	print(ok, res, r.pos)
	for i = 1, #r.c do
		print("", i, r.c[i])
	end
	
	print("\n[-] arg #1 bad type")
	errTest.expectFail(_mt_reader.cap, r, nil)
end

do
	print("\nTest: " .. errTest.register(_mt_reader.capReq, "_mt_reader.capReq") )
	local r
	r = stringReader.new("fa æe bar!? ???")
	local ok, res
	print("\n[+] expected behavior.")
	ok, res = errTest.expectPass(_mt_reader.capReq, r, "(f).-(æ).-(bar)")
	print(ok, res, r.pos)
	for i = 1, #r.c do
		print("", i, r.c[i])
	end
	
	print("\n[-] arg #1 bad type")
	errTest.expectFail(_mt_reader.capReq, r, nil)
	
	print("\n[-] Search failure")
	errTest.expectFail(_mt_reader.capReq, r, "87654", "string search failed!")
end

do
	print("\nTest: " .. errTest.register(_mt_reader.ws, "_mt_reader.ws") )
	local r
	r = stringReader.new("fa               æe                   bar!? ???")
	local ok, res
	print("\n[ad hoc] expected behavior.")
	r:u8Char()
	r:u8Char()
	local r_pos_old = r.pos
	print("starting r.pos", r.pos)
	r:ws()
	print("ending r.pos", r.pos)
	if r_pos_old == r.pos then
		error("Ad Hoc ws() test failed")
	end
	print("^ pos should have moved from 3 to 18.")
end

do
	print("\nTest: " .. errTest.register(_mt_reader.wsNext, "_mt_reader.wsNext") )
	local r
	r = stringReader.new("fa               æe                   bar!? ???")
	local ok, res
	print("\n[ad hoc] expected behavior.")
	local r_pos_old = r.pos
	print("starting r.pos", r.pos)
	r:wsNext()
	print("ending r.pos", r.pos)
	if r_pos_old == r.pos then
		error("Ad Hoc wsNext() test failed")
	end
	print("^ pos should have moved from 1 to 3.")
end

do
	print("\nTest: " .. errTest.register(_mt_reader.newStr, "_mt_reader.newStr") )
	local r
	r = stringReader.new("fa               æe                   bar!? ???")
	
	print("\n[+] expected behavior")
	r:u8Char()
	r:u8Char()
	local old_pos = r.pos
	errTest.expectPass(_mt_reader.newStr, r, "new_string")
	print("old_pos", old_pos, "r.pos", r.pos)
	if old_pos == r.pos then
		error("position should have changed when assigning a new string, but didn't")
	end

	print("\n[+] arg #1 bad type")
	errTest.expectFail(_mt_reader.newStr, r, true)
end


do
	print("\nTest: " .. errTest.register(_mt_reader.clearCaptures, "_mt_reader.clearCaptures") )
	local r
	r = stringReader.new("fa               æe                   bar!? ???")
	
	print("\n[ad hoc] expected behavior")
	r:cap("(fa).-(æ).-(e).-(bar).-(!%?)")
	print("#r.c", #r.c)
	for i = 1, #r.c do
		print("", i, r.c[i])
	end
	r:clearCaptures()
	if next(r.c) then
		error("There are still capture results in r.c after calling clearCaptures()")
	end
	print("^ Test passed (confirmed capture table is empty after calling clearCaptures())")
end
