
#include "string.bi"

TYPE testPtr as function() as integer

extern pauseTime as double
extern errorpos as integer
dim pauseTime as double
dim errorpos as integer

Randomize

sub doTest(t as string, byval theTest as testPtr)
	static num as integer = 0
	
	num += 1
	
	print "Test #" & num & ": " & t & "... ";
	
	dim as double start, finish, diff
	dim as integer ret
	
	pauseTime = 0
	
	start = timer
	
	ret = theTest()
	
	finish = timer - pauseTime
	
	diff = finish - start
	
	do while diff < 0
		diff += 86400
	loop
	
	'diff *= 1000000
	
	if ret then
		print "FAIL (on line " & errorpos & ")"
		end num
	else
		print "Pass"
	end if
	
	if(diff < 1) then
		diff *= 1000
		if(diff < 10) then
			diff *= 1000
			print "Took " & int(diff) & !" \u03BCs "
		elseif diff < 100 then
			print "Took " & format(diff, "0.0") & " ms "
		else
			print "Took " & int(diff) & " ms "
		end if
	else
		print "Took " & format(diff, "0.00") & " s "
	end if
	
end sub

#define pass return 0
#define fail errorpos = __LINE__ : return 1

#macro startTest(t)
	Declare Function t##_TEST() as integer
	doTest(#t, @t##_TEST)
	function t##_TEST() as integer
#endmacro
#define endTest pass : end Function


function ask(q as string) as integer
	dim ret as string, r as integer
	
	dim as double s, f, d
	
	s = timer
	
	q = q & " (y/n)"
	
	again:
	print q
	ret = input(1)
	
	if lcase(ret) <> "y" and lcase(ret) <> "n" then goto again
	
	r = lcase(ret) = "y"
	
	f = timer
	
	d = s - f
	
	do while d < 0
		d += 86400
	loop
	
	pauseTime += d
	
	return r
end function
