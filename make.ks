// Make script to consolodate modules in flightlib to single compiled library.
////////////////////////////////////////////////////////////////////////////////
// Modules are made to be run as individual programs, so they have to be adapted
// into functions, consolodated into a single source file, and then compiled.
// A few conventions are necessary to do this correctly. Any libraries necessary
// in a given program, and only libraries of functions, must have lib in their
// name, e. g. "utillib.ks" included as 'runoncepath("utillib")." These lines
// are removed from 

local libsrcfilepath is "0:/libsrc/flightlib.ks".
local libsrcfile is 0.
local currentmodule is 0.

// Change to lib directory
cd("0:/flightlib").

// Get file list
list files in fls.

// create list of libraries in source directory.
local liblist is list().
for f in fls {
	if f:name:contains("lib") {
		liblist:add(f:name).
	}
}

// create library source file

if not exists(libsrcfilepath) {
	create(libsrcfilepath).
}
// clear it if it already exists
set libsrcfile to open(libsrcfilepath).
libsrcfile:clear.

print "Compiling Flight Library".

for f in fls {
	// concatenate functionized file to library
	if f:extension = "ks" {
		local addOK is true.
		set currentmodule to open(f:name).
		local modulename is f:name:replace(".ks", "").
		
		// write to src file
		if not modulename:contains("lib") {
			
			libsrcfile:writeln("///////////////////////////////////////////////////////////////////////////").
			libsrcfile:writeln("// Function " + modulename + " included from " + f:name).
			libsrcfile:writeln("///////////////////////////////////////////////////////////////////////////").
			libsrcfile:writeln("").
			
			if not libsrcfile:writeln("function " + modulename + " {") {
				set addOK to false.
			}
			
			local moduleiterator is currentmodule:readall:iterator.
			
			until false {
				if not moduleiterator:next {break.}.
				local noruntext is char(9) + moduleiterator:value.
				if moduleiterator:value:tolower:contains("run") {
					for file in fls {
						local filename is file:name:replace(".ks", "").
						if noruntext:tolower:contains("run " + filename + ".") {
							set noruntext to noruntext:tolower:replace("run " + filename, filename + "()").
						} else {
							set noruntext to noruntext:tolower:replace("run " + filename, filename).
						}
						
					}
				}
				local moduletext is noruntext.
				if moduleiterator:value:tolower:contains("lib") {
					for lib in liblist {
						local utiltext is "runoncepath(" + char(34) + lib + char(34) + ").".
						set moduletext to moduletext:replace(utiltext, "").
					}
				}
				
				if not libsrcfile:writeln(moduletext) {
					set addOK to false.
				}
			}
			if not libsrcfile:writeln("}") {
				set addOK to false.
			}
		} else {
			libsrcfile:writeln("///////////////////////////////////////////////////////////////////////////").
			libsrcfile:writeln("// Library Functions for " + modulename + " included from " + f:name).
			libsrcfile:writeln("///////////////////////////////////////////////////////////////////////////").
			libsrcfile:writeln("").
			
			libsrcfile:writeln(currentmodule:readall:string).
			
			libsrcfile:writeln("///////////////////////////////////////////////////////////////////////////").
			libsrcfile:writeln("// End Library " + modulename).
			libsrcfile:writeln("///////////////////////////////////////////////////////////////////////////").
			
		}
		libsrcfile:writeln("").
	
		if addOK {
			print "Added " + modulename + " to library".
		} else {
			print "Failed to add " + modulename + " to library".
		}
	}
}

// compile library

print "Compiling binary".
compile libsrcfilepath to "0:/bin/flightlib.ksm".
print "Compilation complete".
cd("0:/").
wait 3.
