# https://aransentin.github.io/cwasm/


Notes on working with C and WebAssembly   body{ margin: 0; font-family: 'Source Sans Pro', 'sans-serif'; background-color: #e2e2e2; } main{ overflow: auto; margin: 0 auto; padding: 0 80px 100px 80px; max-width: 800px; background-color: #f2f2f2; } @media (max-width: 960px){ body{ background-color: #f2f2f2; } main{ padding: 0 20px 100px 20px; } } pre{ padding: 10px; color: white; background-color: #333; white-space: pre-wrap; } li{ margin-bottom: 1em; } a{ text-decoration: none; color: #2962ad; }

Notes on working with C and WebAssembly
=======================================

If you would like to make extremely lean software for the web, C & WebAssembly is one option. Truthfully the only really practical way of doing that has been to use [Emscripten](https://github.com/kripken/emscripten), emulating a lot of what you expect from a normal C environment in Javascript at the cost of a fair bit of overhead.

If you have a "every byte is precious" attitude like me (and like to get your hands dirty!) you can certainly do it yourself, as well. The available information online is rather sparse, so this page mostly consists of things I've discovered toying around with just that.

I was able to make a [WebGL2 demo](#demo) in 6.2KiB (uncompressed, not counting textures) without too much effort, so expect to get results around that magnitude for tasks of similar complexity.

Building
--------

To generate WebAssembly binaries, you need LLVM, clang, and lld. Stable – 5.0, at the time of writing – won't cut it, so build it from source. Sadly LTO doesn't work, so we need to fiddle around with the IR.

First, let's turn each of our C source files into LLVM IR bitcode. This can be done like so:

clang -cc1 -Ofast -emit-llvm-bc -triple=wasm32-unknown-unknown-wasm -std=c11 -fvisibility hidden src/\*\\.c

*   **\-fvisibility hidden**  
    Prevents all the functions in the source from being exported except the ones we explicitly designate later on.
*   **\-Ofast**  
    Gotta go fast. This is like _\-O3_, except we assume that a whole bunch of specific floating-point behaviour (e.g. INFs) won't happen – a lot of it will trap the WebAssembler environment anyway, so there's not much point in taking it into account. Use _\-O3_ instead if you care about boring things like standards compliance and preventing undefined behaviour 😉.

Combine all the bitcode into one and optimize it again:

llvm-link -o wasm.bc src/\*\\.bc
opt -O3 wasm.bc -o wasm.bc

Next step is actually compiling it:

llc -O3 -filetype=obj wasm.bc -o wasm.o

Linking can now be done with lld.

wasm-ld --no-entry wasm.o -o binary.wasm --strip-all -allow-undefined-file wasm.syms --import-memory

*   **\--no-entry**  
    Don't bother with the lack of a _main_ function. We'll call our functions from Javascript when we need to, so having a global entry point doesn't really make sense.
*   **\--strip-all**  
    We only want to expose a select few entry points to our program; this strips away all the others. Given that we compiled the sources with _\-fvisibility hidden_, only functions marked with _\_\_attribute\_\_((visibility("default")))_ (typedef'ed to something not as nasty) will be exposed to our Javascript.
*   **\--allow-undefined-file wasm.syms**  
    We are going to want to call Javascript from our WebAssembly, as well – _wasm.syms_ contains a list of the names of those functions.
*   **\--import-memory**  
    We'll supply the memory ourselves from Javascript. We need to do so since the flag _\--inital-memory_ which we want to use is broken and doesn't seem to do anything.

Note that if you are running a version later than [this commit](https://github.com/llvm-mirror/lld/commit/bf5a2d882e292886dd9aa8d54042b6cf62792449), you'll need to add "--export-dynamic" as well to prevent wasm-lld stripping absolutely everything.

Running
-------

Our binary is now ready for use. Let's whip up some JS to do so:

let imports = {};
let memory = null;
let exports = null;

let request = await fetch( 'binary.wasm' );
let binary = await request.arrayBuffer();

imports\['memory'\] = new WebAssembly\['Memory'\]( {'initial':32} );
memory = new Uint8Array( imports\['memory'\]\['buffer'\] );
let program = await WebAssembly\['instantiate'\]( binary, { "env":imports } );

let instance = program\['instance'\];
exports = instance\['exports'\];

*   **imports**  
    This is a dictionary of functions we will be able to call from inside our WebAssmebly program.
*   **memory**  
    32 pages of wasm memory totalling 2MiB. I need that much to work on textures in the demo; loading a 512²-texel 4-component texture requires at least 1MiB, for example.
*   **exports**  
    A dictionary of C functions that we marked visible. They can now be called like any other JS function.
*   **\['instantiate'\]**  
    I call WebAssembly functions like that since the Closure Compiler hasn't gotten the wasm symbols into its whitelist yet; this prevents them from being minified.

Calling Javascript from C
-------------------------

All functions you want to be able to call from the WebAssembly module should be placed into _imports_, like so:

imports\['print\_num'\] = function( n ){
    console.log( "Your number is " + n  );
    return 123;
};

Secondly, create declaration for it in a C header somewhere. The only types you can use are _i32_, _f32_, and _f64_; I'll go over how to pass buffers and strings shortly.

typedef signed int i32;

\[...\]

i32 print\_num( i32 n );

Finally, add the name of the function to _wasm.syms_ so that the linker won't complain. You can then call the function to your hearts content.

Calling C from Javascript
-------------------------

Add _\_\_attribute\_\_((visibility("default")))_ to the function you want to call, so it won't get stripped out:

#define export \_\_attribute\_\_( ( visibility( "default" ) ) 

\[...\]

export i32 some\_func( i32 n )
{
    return n+1;
}

Then you can immediately go ahead and call it from _exports_. Easy!

exports\['some\_func'\]( 1 );

Passing memory and strings
--------------------------

This is a little trickier than just returning an integer. From C, you return a pointer to the memory, as well as the length:

void console\_log( i32 str, i32 len );

\[...\]

const char \* string = "Hello World!";
console\_log( string, strlen(string) );

With the help of the memory object, you can get the bytes in question from Javascript. The TextDecoder interface can then convert it to a string if so desired.

let utf8decoder = new TextDecoder( "utf-8" );

\[...\]

function console\_log( str, len ){
    let arr = memory.subarray( str, str+len );
    console.log( utf8decoder.decode( arr ) );
}

Passing data the other way requires you to allocate space in C, and then blit the data into the _memory_ object from Javascript.

Passing objects
---------------

You can't. To operate on e.g. WebGL objects, you'll need to store them JS-side and return an integer reference to it.

Here's an example how you might do it:

let gl\_id\_freelist = \[\];
let gl\_id\_map = \[ null \];

\[...\]

function webgl\_id\_new( obj ){
    if( gl\_id\_freelist.length == 0 )
    {
        gl\_id\_map.push( obj );
        return gl\_id\_map.length - 1;
    }
    else
    {
        let id = gl\_id\_freelist.shift();
        gl\_id\_map\[id\] = obj;
        return id;
    }
}

function webgl\_id\_remove( id ){
    delete gl\_id\_map\[id\];
    gl\_id\_freelist.push( id );
}

\[...\]

imports\["glCreateShader"\] = function( type ){
    let shader = gl.createShader( type );
    let shader\_id = webgl\_id\_new( shader );
    return shader\_id;
}

imports\["glDeleteShader"\] = function( shader\_id ){
    let shader = gl\_id\_map\[shader\_id\];
    gl.deleteShader( shader );
    webgl\_id\_remove( shader\_id );
}

The standard C library
----------------------

Naturally none of it is available, so we'll have to implement what we want ourselves. Since we can't use _malloc_ and friends, we'll either have to:

*   Write them ourselves, by e.g. reserving portions of a large buffer allocated statically.
*   Use VLAs instead, putting all working memory on the stack as we go. The things you can do with it is somewhat limited though (no memory resizing, no data persistence when calling a wasm function multiple times).

In the future there will probably be implementations of _malloc_ written as separate wasm modules that you could link into your own, but no such luck yet.

Builtins
--------

Fortunately clang has [a few builtin functions](https://github.com/llvm-mirror/clang/blob/master/include/clang/Basic/Builtins.def), mostly for string handling, bit twiddling, and trigonometry. To use them you can simply call _\_\_builtin\_cosf()_ or the like; you won't need a header or anything. There's no guarantee that LLVM won't just try to insert a call to the non-existant C library function anyway however, so it's probably not something you should rely on outside of simple demos and such.

Futher optimizations with Binaryen
----------------------------------

The [Binaryen](https://github.com/WebAssembly/binaryen) toolchain includes _wasm-opt_, a tool that reads WebAssembly, optimizes it, and then spits it out again. It shrinks my program by 10% or thereabouts, but your mileage may vary.

wasm-opt -Oz binary.wasm -o binary\_opt.wasm

If you have large buffers allocated statically, LLVM insits on including them verbatim in the binary. wasm-opt will strip it out, so significant gains might be had in that case.

Demo
----

You can find the demo I did [here](demo). The source is available on [Github](https://github.com/Aransentin/wasmdemo) as well.