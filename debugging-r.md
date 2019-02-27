Debugging C/C++ code that interfaces with R
===========================================

## Overview

When R code isn't fast enough, one solution is to write C or C++ code that you can call from R. The problem is that when writing C/C++, it's all too easy introducing subtle memory bugs. These languages require much more care in managing memory than do garbage-collected languages (like R itself), where you rarely have to think about managing memory.

In this document, I'll describe some common problems and their symptoms, and then I'll show how to use several tools to find the source of the problems.


### Overview of kinds of problems

C and C++ require a lot of manual memory management. This is one reason that these languages can be so fast, but it's also the cause of many subtle bugs. When you write buggy R code, it's almost always the case that, even though the behavior is wrong, it is predictable and repeatable. This makes debugging R code relatively straightforward. When you have memory-related bugs in C, the behavior can change each time you run it; sometimes it might crash, sometimes it might work fine, and sometimes it might appear to work, but then cause strange behavior later. These kinds of bugs are much harder to track down.

If you write C or C++ code, here are some problems that you're likely to encounter:

* Memory leaks
* Double-freeing memory
* Dereferencing NULL pointers
* Accessing memory that has been freed
* Buffer overruns
* Other undefined behavior

These problems typical problems that can happen with any C or C++ code. I'll assume that anyone reading this document is familiar with these kinds of problems so I won't go into much depth explaining them. I will talk about how to use specialized tools to diagnose them, though.

There are also problems that are specific to C or C++ code that interfaces with R. The issues I have encountered involve the memory management code for R objects -- objects like lists, vectors, and environments, which can be created in C and are represented with `SEXP`s. I'll call these *R-level memory bugs*. When these objects are created with R's C interface, R has a number of functions that are used to track when the objects are still being used and when they are no longer being used, and therefore can be garbage collected. Here's a sampling of the issues that I have encountered:

* `SEXP` objects that aren't wrapped in `PROTECT()`
* `SEXP` objects that aren't preserved with `R_PreserveObject()` and released with `R_ReleaseObject()`.

If you have a bug, it may be deterministic, by which I mean it happens every time you run the same code, or it may be non-deterministic, where it happens only some of the time. If your problem is deterministic, congratulations! It will be (relatively) easy to debug. If it's non-deterministic, then you're in for a more challenging project. When I was trying to track down a bug in httpuv, I had errors that occured only once every several thousand or tens of thousands of requests. It took me a couple weeks to track down all the bugs. One more thing: if the problem is non-deterministic, then there's a good chance that it has to do with R's memory management, as the garbage collector and memory allocation is not fully deterministic.

When I refer to "R functions" in this document, I mean functions from R's C API. When I discuss functions that are called from R (the kind you can run from the R console), I'll be sure to make it clear.

There's an additional class of problems that can occur if you write multithreaded code. Since only a tiny minority of R code makes use of multiple threads, I'll save this topic for later.


### Overview of tools

Some of the tools in this section are available in a typical R installation. Others require installing software and/or compiling a special build of R. You can do this manually, or you can use this [Docker image](https://hub.docker.com/r/wch1/r-debug/) which includes all of the tools and builds of R mentioned below.

One of the simplest tools for debugging C/C++ code is to add `printf` or `cout` statements in the code. If that isn't sufficient to get to the bottom of your problem, there are many other tools that can help.

**Debuggers:** Either `gdb` or `lldb`, depending on what compiler was used to build your copy of R. Generally, on Linux, you'll use `gdb`, and on a Mac, you'll use `lldb`. A debugger will let you stop your code when an error occurs, or wherever you set a breakpoint, and you'll be able to inspect and modify the value of variables.

In addition to debuggers, there are tools specifically for detecting memory problems.

**Valgrind** is a program which runs other programs in a special monitoring environment. It includes a number of different [tools](http://valgrind.org/info/tools.html) which you can use; the default is *memcheck*, which, as its name suggests, detects memory problems. Valgrind works with ordinary builds of R, but R can also be compiled with extra instrumentation which, when used with Valgrind, can detect even more memory bugs. See [this section](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Using-valgrind) in R-exts for more information.

**Address and undefined behavior sanitizers:** R can be compiled with support for [AddressSanitizer](http://clang.llvm.org/docs/AddressSanitizer.html), [LeakSanitizer](http://clang.llvm.org/docs/LeakSanitizer.html), and [UndefinedBehaviorSanitizer](http://clang.llvm.org/docs/UndefinedBehaviorSanitizer.html). When R built with these sanitizers, it will run slower and take more memory, but they will help detect various kinds of errors at run time. See [this section](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Using-Address-Sanitizer) in R-exts for more information.

The above tools can help find general C/C++ errors. These tools below can help find R-level memory bugs:

**`gctorture()`**: A mode called "GC torture" can be enabled in an R session. This causes R to do a garbage collection every time memory is allocated. It also causes R to run very slowly. 

**R with strict barrier:** R can be configured and compiled with [`--enable-strict-barrier`](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Using-gctorture), which changes the behavior of the memory allocator to help catch more memory problems.


### Using the tools and special builds of R

Most of these tools are best used with R in a terminal, not in RStudio or other GUI.

The easiest way to get these tools and R builds is to use this [wch1/r-debug docker image](https://hub.docker.com/r/wch1/r-debug). The other option is to install the tools needed and/or compile R with the necessary settings.

The r-debug docker image contains the following:

* `gdb`
* `valgrind`
* `R`: The current release version of R.
* `RD`: The current development version of R (R-devel). This version is compiled without optimizations (`-O0`), so a debugger can be used to inspect the code as written, instead of an optimized version of the code which may be significantly different.
* `RDvalgrind`: R-devel compiled with valgrind level 2 instrumentation. This should be started with `RDvalgrind -d valgrind`.
* `RDsan`: R-devel compiled with gcc, Address Sanitizer and Undefined Behavior Sanitizer.
* `RDcsan`: R-devel compiled with clang, Address Sanitizer and Undefined Behavior Sanitizer.
* `RDstrictbarrier`: R-devel compiled with `--enable-strict-barrier`. This can be used with `gctorture(TRUE)`, or `gctorture2(1, inhibit_release=TRUE)`.
* `RDthreadcheck`: R-devel compiled with `-DTHREADCHECK`, which causes it to detect if memory management functions are called from the wrong thread.

Each of the builds of R has its own libpath, so that a package installed with one build will not be accidentally used by another. Each one comes with devtools and Rcpp installed.

To use any of the special builds of R, instead of running `R`, run `RD`, `RDsan`, and so on.


#### Debuggers: gdb and lldb

There are two debuggers that you might use with R: `gdb` and `lldb`. Which one you use depends on the compiler used to build R. If it was built with `gcc`, then you should use `gdb`. If it was built with `clang`, you should use `lldb`. Generally, on Linux systems, you'll use `gdb`, and on macOS, you'll use `lldb`.

To run R with one of these debuggers, run this from a terminal:

```
R -d gdb
```

or

```
R -d lldb
```

It'll print out some information, then give a debugger prompt, where you can set up breakpoints or run other debugger-related commands. To start R, type `run` and hit enter.

```
R -d gdb
....

(gdb) run
Starting program: /usr/local/RD/lib/R/bin/exec/R 
....

> 
```

At this point you can run your R code as normal. If a segfault occurs, it will drop you into the debugger and you can inspect the state of the program. Another useful technique is to set a breakpoint in your code so that when execution hits that line, it drops into the debugger.

There are many excellent resources explaining how to use `lldb` and `gdb`, so I won't go into detail here. For example, see Kevin Ushey's [blog post](http://kevinushey.github.io/blog/2015/04/13/debugging-with-lldb/) on the topic. This [lldb-gdb](https://lldb.llvm.org/lldb-gdb.html) cheat sheet is also an excellent quick reference for both debuggers. R-Exts has information about [inspecting R objects](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Inspecting-R-objects) with a debugger.

http://r-pkgs.had.co.nz/src.html


> **Tip:** If you are using the r-debug Docker image, use `RD` for easier debugging, instead of `R`. It is compiled without optimizations, so the actual code will more closely mirror the code written than if optimizations were enabled.


#### Valgrind

Valgrind detects many kinds of memory errors, although your code will run significantly more slowly. If you have Valgrind installed, it's easy to run R with it:

```
R -d valgrind
```

Then, run your code as usual. Valgrind may print messages about memory errors as you run your code. When you exit, it will also provide a report about leaked memory. Once again, Kevin Ushey has a great [blog post](http://kevinushey.github.io/blog/2015/04/05/debugging-with-valgrind/) on this topic.

> **NOTE:** As of this writing (2017-12-08), running R 3.4.2 with Valgrind on macOS 10.13.1 results in an immediate crash. Sorry.

Valgrind comes with several "tools", the default of which is `memcheck`. The command above is equivalent to running:

```
R -d "valgrind --tool=memcheck"
```

Normally, Valgrind prints a summary of memory leaks. If you want information about each memory leak, run:

```
R -d "valgrind --leak-check=full"
```

R can be built with more Valgrind instrumentation, which helps Valgrind detect even more memory problems, at the cost of more speed. The r-debug Docker image provides such a build of R, named `RDvalgrind`. To use it, run:

```
RDvalgrind -d valgrind
```

This can be used with `gctorture()` for even more effectiveness in finding bugs.

For more about using R with Valgrind, see [R-exts](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Using-valgrind).


#### Address and Undefined Behavior Sanitizers

R can be compiled with AddressSanitizer and LeakSanitizer, which are tools for detecting memory problems, similar to Valgrind. It can also be compiled with UndefinedBehaviorSanitizer, which detects some other forms of undefined behavior in C/C++. The difference is that support is compiled in, and there is not a separate program. R-Exts has information about [compiling R](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Using-Address-Sanitizer) with these sanitizers, but for simplicity, I'll show how to use the build that's provided on the r-debug Docker image.

All you need to do is start the custom-build version of R. With the r-debug Docker image:

```
Rsan
```

When memory errors occur, it will print out information about them.



#### `gctorture()`

R can be set to "GC torture" mode, which triggers a garbage collection on every memory allocation. It also causes R to run very slowly. 

`gctorture()` helps to find R-level memory bugs -- that is, ones involving the memory allocation of R objects. The tools listed above are used to find lower-level memory bugs, although they may also help find bugs at R level.

To use it, simply run `gctorture(TRUE)` in R; to turn it off, run `gctorture(FALSE)`. 

```
gctorture(TRUE)
my_code()
gctorture(FALSE)
```

**Tip:** Because `gctorture()` slows down R so much, it's often a good idea to turn it on just before the section that you think is suspect, and then turn it off afterward.

R-Exts has more information [here](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Using-gctorture).


#### R with strict barrier

R can be configured and compiled with [`--enable-strict-barrier`](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Using-gctorture), which changes the behavior of the memory allocator to help catch more memory problems. This runs more slowly than a regular build of R.

The Docker image includes a build of R with strict barrier. To use it, run:

```
RDstrictbarrier
```

When you're in R, enable `gctorture()` as above, and it will be even more thorough about finding memory bugs.

With the strict-barrier build of R, there is another garbage collector setting that can help find problems. Instead of running `gctorture(TRUE)`, run:

```
gctorture2(1, inhibit_release = TRUE)
```

Normally, R won't detect when incorrectly GC'd memory is reallocated, but with `inhibit_release=TRUE`, it will never reallocate memory, making some kinds of errors easier to detect.



## A compendium of memory management bugs



### Memory leaks

Memory leaks don't have any obvious symptoms. All that happens is that the process keeps increasing its memory usage over time. This could be benign if you just leak a little memory, but can be a problem if your code continually leaks memory and runs for a long time.

Here's a minimal example of memory leak:

```
Rcpp::cppFunction("
  void leak() {
    malloc(1000 * sizeof(int));
  }
")
leak()
```

If you run it in a normal R session, there will be no obvious problems when you run this code, even though the code is leaking memory.

Tools to find memory leaks:

* Valgrind

With **Valgrind**, when you quit your R session, you'll see a report like this:

```
> q()
Save workspace image? [y/n/c]: n
==123== 
==123== HEAP SUMMARY:
==123==     in use at exit: 58,202,246 bytes in 12,067 blocks
==123==   total heap usage: 33,735 allocs, 21,668 frees, 97,866,854 bytes allocated
==123== 
==123== LEAK SUMMARY:
==123==    definitely lost: 4,000 bytes in 1 blocks
==123==    indirectly lost: 0 bytes in 0 blocks
==123==      possibly lost: 0 bytes in 0 blocks
==123==    still reachable: 58,198,246 bytes in 12,066 blocks
==123==         suppressed: 0 bytes in 0 blocks
==123== Rerun with --leak-check=full to see details of leaked memory
==123== 
==123== For counts of detected and suppressed errors, rerun with: -v
==123== Use --track-origins=yes to see where uninitialised values come from
==123== ERROR SUMMARY: 1136 errors from 4 contexts (suppressed: 0 from 0)
```

The key piece of information is the "definitely lost" line. It tells us that we've leaked 4,000 bytes. For more information, we can run it with `--leak-check=full`, which will display detailed information about each leak:

```
$ RD -d "valgrind --leak-check=full"
....

> q()
Save workspace image? [y/n/c]: n
==155== 
==155== HEAP SUMMARY:
==155==     in use at exit: 58,202,246 bytes in 12,067 blocks
==155==   total heap usage: 33,735 allocs, 21,668 frees, 97,866,854 bytes allocated
==155== 
==155== 4,000 bytes in 1 blocks are definitely lost in loss record 223 of 1,397
==155==    at 0x4C2FB0F: malloc (in /usr/lib/valgrind/vgpreload_memcheck-amd64-linux.so)
==155==    by 0x110A3D58: leak() (file9b408c0427.cpp:8)
==155==    by 0x110A3D9B: sourceCpp_1_leak (file9b408c0427.cpp:19)
==155==    by 0x4F28AA1: R_doDotCall (dotcode.c:567)
==155==    by 0x4F33C3D: do_dotcall (dotcode.c:1252)
==155==    by 0x4F6F25E: Rf_eval (eval.c:728)
==155==    by 0x4F74CC4: Rf_evalList (eval.c:2698)
==155==    by 0x4F6F130: Rf_eval (eval.c:719)
==155==    by 0x4F713BC: R_execClosure (eval.c:1617)
==155==    by 0x4F710B8: Rf_applyClosure (eval.c:1551)
==155==    by 0x4F6F3A1: Rf_eval (eval.c:747)
==155==    by 0x4FB6D12: Rf_ReplIteration (main.c:258)
==155== 
==155== LEAK SUMMARY:
==155==    definitely lost: 4,000 bytes in 1 blocks
==155==    indirectly lost: 0 bytes in 0 blocks
==155==      possibly lost: 0 bytes in 0 blocks
==155==    still reachable: 58,198,246 bytes in 12,066 blocks
==155==         suppressed: 0 bytes in 0 blocks
==155== Reachable blocks (those to which a pointer was found) are not shown.
==155== To see them, rerun with: --leak-check=full --show-leak-kinds=all
==155== 
==155== For counts of detected and suppressed errors, rerun with: -v
==155== Use --track-origins=yes to see where uninitialised values come from
==155== ERROR SUMMARY: 1137 errors from 5 contexts (suppressed: 0 from 0)
```

Not all leaks are as straightforward as this one, and in some cases Valgrind won't be sure that the memory is actually leaked. In those cases it will say "possibly lost". For more information about the messages from Valgrind, see the [FAQ](http://valgrind.org/docs/manual/faq.html#faq.deflost).

You can also build R with `--with-valgrind-instrumentation=2` to detect more kinds of memory bugs, at the cost of speed. With the wch1/r-debug Docker image, you can simply run it with `RDvalgrind`:

```
RDvalgrind -d valgrind
```


TODO: What about R-level memory leaks?


### Double-freeing memory

If you free the same region of memory twice, it may result in R crashing immediately, or R might do nothing right away. This can depend on the platform: on my Mac, it crashes the first time I try to do this, but on my Linux machine, I need to run it a few times. 

```
Rcpp::cppFunction("
  void double_free() {
    int* x = (int*)malloc(100 * sizeof(int));
    free(x);
    free(x);
  }
")
double_free()
```

Mac result:

```
> double_free()

R(12224,0x7fffa0c89340) malloc: *** error for object 0x7fef3d4c6320: pointer being freed was not allocated
*** set a breakpoint in malloc_error_break to debug
Abort trap: 6
```

Linux result:

```
> doublefree()
> doublefree()

 *** caught segfault ***
address 0x2e0000010, cause 'memory not mapped'
```


```
Rcpp::cppFunction("
  void doubledelete() {
    std::vector<int>* x = new std::vector<int>(100);
    delete x;
    delete x;
  }
")
doubledelete()
```

Mac:

```
> doubledelete()

R(12305,0x7fffa0c89340) malloc: *** error for object 0x7fc4e17ae8d0: pointer being freed was not allocated
*** set a breakpoint in malloc_error_break to debug
Abort trap: 6
```

Linux:

```
> doubledelete()
> doubledelete()

 *** caught segfault ***
address (nil), cause 'unknown'
```


### Dereferencing NULL pointers

Dereferencing a NULL pointer usually results in an immediate crash:

```
Rcpp::cppFunction("
  int deref_null() {
    int* x = (int*)NULL;
    return *x;
  }
")
deref_null()
```

Mac:

```
> deref_null()

 *** caught segfault ***
address (nil), cause 'memory not mapped'
```

Linux:

```
> deref_null()

 *** caught segfault ***
address 0x0, cause 'memory not mapped'
```


### Accessing memory that has been freed

```
Rcpp::cppFunction("
  int use_after_free() {
    int* x = (int*)malloc(100 * sizeof(int));
    free(x);
    x[2] = 1234;
    return x[2];
  }
")
use_after_free()
```

This function accesses memory after it has been freed. You might need to call it a number of times before anything obviously bad happens:

```
Rcpp::cppFunction("
  int use_after_free() {
    std::vector<int>* x = new std::vector<int>(100);
    delete x;
    (*x)[2] = 1234;
    return (*x)[2];
  }
")
use_after_free()
use_after_free()
use_after_free()
```

Here are some ways that R might crash when you do this:

```
#>  *** caught segfault ***
#> address 0x20, cause 'memory not mapped'
#> 
#>  *** caught illegal operation ***
#> address 0x7fff678b95e2, cause 'illegal opcode'


#> R(12770,0x7fffa0c89340) malloc: *** error for object 0x7fdf6579eb38: incorrect checksum for freed object - object was probably modified after being freed.
#> *** set a breakpoint in malloc_error_break to debug
#> Abort trap: 6
```

But what's worse, in the instances where R does not crash, it's possible between the time you `delete` the object and you assign values to it, the memory has been allocated for something else and you will overwrite someone else's data. (In this particular example, that's unlikely because the assignment happens right after the `delete`.) This will result in strange behavior that only manifests later.

Tools

### Buffer overrun

It's possible that nothing will happen; it's also possible that R will crash immediately, or start exhibiting weird behavior later.

```
Rcpp::cppFunction("
  int buffer_overrun() {
    int* x = (int*)malloc(100 * sizeof(int));
    x[100000] = 1234;
    return x[100000];
  }
")
buffer_overrun()
```

### Using uninitialized memory


```
Rcpp::cppFunction("
  int use_uninitialized() {
    int* x = (int*)malloc(100 * sizeof(int));
    return x[2];
  }
")
z<-use_uninitialized()
```

Regular R:

```
> use_uninitialized()
[1] -995733944
```

Tools:
* Valgrind

Valgrind:
```
> use_uninitialized()
[1]
... [other output] ...
==409== Use of uninitialised value of size 8
==409==    at 0x5783453: vsnprintf (vsnprintf.c:117)
==409==    by 0x575FEEE: snprintf (snprintf.c:33)
==409==    by 0x4FFF7C2: Rf_EncodeInteger (printutils.c:134)
==409==    by 0x4FFD8D2: Rf_printIntegerVector (printvector.c:88)
==409==    by 0x4FFE0EC: Rf_printVector (printvector.c:189)
==409==    by 0x4FF8F13: Rf_PrintValueRec (print.c:822)
==409==    by 0x4FF99E8: Rf_PrintValueEnv (print.c:1017)
==409==    by 0x4FB6D67: Rf_ReplIteration (main.c:262)
==409==    by 0x4FB6ED4: R_ReplConsole (main.c:308)
==409==    by 0x4FB8982: run_Rmainloop (main.c:1082)
==409==    by 0x4FB8998: Rf_mainloop (main.c:1089)
==409==    by 0x10896B: main (Rmain.c:29)
==409== 
 208316216
```

#### Other undefined behavior

```
Rcpp::cppFunction("
  int undefined_behavior(int n) {
    int k = 0x7fffffff;
    k += n;
    return k;
  }
")

undefined_behavior(100)
```

The result:

```
> undefined_behavior(10)
[1] -2147483639
```


Tools:
* UBSAN build of R


* Calling R's C functions from the wrong thread. R's code is generally not thread-safe.


### Unprotected R objects

Whenever an SEXP object is created from C code, it must be wrapped in a [`PROTECT()`](https://github.com/wch/r-source/blob/7927e82f/src/main/memory.c#L3163-L3169). This tells R that the object should not be garbage collected. At the end of a function, you must call [`UNPROTECT(n)`](https://github.com/wch/r-source/blob/7927e82f/src/main/memory.c#L3174-L3179), where `n` is a number that is equal to the number of previous `PROTECT()` calls in the function. This tells R that those previously-protected objects can be garbage collected. See [here](https://github.com/hadley/r-internals/blob/master/gc-rc.md) for more information.

If you create an SEXP without wrapping in `PROTECT()`, then when you call out to some functions in R (like if you create another SEXP), it may trigger a garbage collection which removes your object before you're done with it!

If you're writing C++ code with Rcpp, you are insulated from having to call `PROTECT()` manually because it's all done for you under the hood by Rcpp. However, you must still be aware of the memory management issues because Rcpp may have bugs (like [this one](https://github.com/RcppCore/Rcpp/issues/780) I found where a `PROTECT()` was missing) and because the lifetime of Rcpp objects partially determines the lifetime of the underlying R objects that they represent.

Here is an example of what can happen if R object that is not protected. This function creates two R numeric vectors `x`, and `y`, of length 1, populates them with the values 1 and 2, respectively, and then returns `x`.

```
Rcpp::cppFunction("
  SEXP unprotected_sexp() {
    SEXP x = Rf_allocVector(REALSXP, 10);
    REAL(x)[0] = 10;

    SEXP y = Rf_allocVector(LGLSXP, 1);
    LOGICAL(y)[0] = FALSE;

    return x;
  }
")
unprotected_sexp()
```


If you run it, you will most likely get the value you expect, 1:

```
> unprotected_sexp()
[1] 1
```

But there's a chance that, when R is allocating memory for `y`, it will garbage-collect the memory for `x` (because the allocation is not wrapped with `PROTECT()`) and allocate the same memory to `y`. The chances of this happening on any particular run is small (especially since the small amounts of memory involved are unlikely to trigger a GC event), but it will happen eventually. When it does, the altered data may not be noticed until much later, and it can be very difficult to reproduce the problem.

To make these kinds of problems more reproducible, you can tell R to do a garbage collection every time it allocates memory, by calling `gctorture(TRUE)`. That means that it does a GC just before it allocates memory for `x`, and just before it allocates memory for `y`. When we do that, here's what happens:

```
> gctorture(TRUE)
> unprotected_sexp()
[1] FALSE
```

The function is returning x, but the value is the one we assigned to `y`! This is because after garbage-collecting `x`, R allocated the memory for `y` in the same space as `x`.

This kind of problem won't be detected by low-level tools like valgrind and the SAN builds of R. At the C level, the code is fine; there are no buffer overruns, or accessing freed memory. The memory problem is at the R level.

Note: `gctorture(TRUE)` will make R run very slowly, so it's best to enable it just for the code that you suspect has problems, and then disable it once you're done, like this:

```
gctorture(TRUE)
unprotected_sexp()
gctorture(FALSE)
```

There are many other possible things that can happen when R objects are not protected. In the example above, we didn't have a buffer overrun, but that can happen, as can segfaults, or other strange things like values disappearing before you use them. In some of the code I was debugging, that happened, and it looks like this:

```
> gctorture(TRUE)
> e <- f()
> e
Error: object 'e' not found
```


Detected with the strictbarrier build and gctorture:

```
> Rcpp::cppFunction("
+   SEXP unprotected_sexp() {
+     SEXP x = Rf_allocVector(REALSXP, 10);
+     REAL(x)[0] = 1;
+ 
+     SEXP y = Rf_allocVector(LGLSXP, 10);
+     LOGICAL(y)[0] = FALSE;
+ 
+     return x;
+   }
+ ")
> gctorture(TRUE)
> unprotected_sexp()
Error in unprotected_sexp() : 
  unprotected object (0x5615b717ea88) encountered (was REALSXP)
```


Even with the strict barrier enabled and `gctorture(TRUE)`, some cases will fall through the cracks, because it does not detect when memory is freed and reallocated. Running the original example on the `RDstrictbarrier`, it simply returns `FALSE`, so the problem may not be obvious, especially if it's buried deep in other code:

```
Rcpp::cppFunction("
  SEXP unprotected_sexp() {
    SEXP x = Rf_allocVector(REALSXP, 1);
    REAL(x)[0] = 1;

    SEXP y = Rf_allocVector(LGLSXP, 1);
    LOGICAL(y)[0] = FALSE;

    return x;
  }
")
gctorture(TRUE)
unprotected_sexp()
gctorture(FALSE)
```

But there is a way around this. When the strict barrier is enabled, it is possible to tell R to NOT reuse memory for new objects. When you do this, it will find the problem immediately:

```
gctorture2(TRUE, inhibit_release = TRUE)
unprotected_sexp()
Error in unprotected_sexp() : 
  unprotected object (0x5615b5c23c48) encountered (was REALSXP)
```


Symptoms:

* Problems happen randomly
* Segfaults
* R objects go missing before you use them


Here is a sampling of error messages I encountered when debugging these problems:

```
 *** caught segfault ***
address 0x7fd970d37a70, cause 'memory not mapped'

Error: unimplemented type 'integer' in 'coerceToInteger'

Error in tryCatch(evalq(sys.calls(), <environment>), error = function (x)  : 
  Evaluation error: SET_VECTOR_ELT() can only be applied to a 'list', not a 'NULL'.

Error in tryCatch(evalq(sys.calls(), <environment>), error = function (x)  : 
  Evaluation error: SET_VECTOR_ELT() can only be applied to a 'list', not a 'bytecode'.
```


### Calling R functions from other threads

Multithreaded code adds another layer of complexity: if you write code which runs in a thread alongside the main R thread, the symptoms may be similar to those described above, but with an even more random pattern of behavior.

When I was modifying httpuv to be multithreaded, the goal was to split the work across two threads: the main R thread did the computations, and the I/O thread handled network communication. They communicate with each other using callback queues.

I was careful to call R functions only from the main R thread. The I/O thread should never call any R functions, because R's code is not thread-safe; calling R functions from another thread will likely result in race conditions, memory problems, and crashes.

By extension, Rcpp code should also not used from the background thread. Creating, modifying, or deleting an Rcpp object will indirectly call functions from R. Even making a copy of an Rcpp object on the background thread will result in R's memory management functions (like `R_PreserveObject()`) being called, and this can result in strange errors or crashes.

When an Rcpp object is created, the constructor calls [`R_PreserveObject()`](https://github.com/wch/r-source/blob/7927e82f/src/main/memory.c#L3306-L3314). Similar to `PROTECT()`, this function is used to prevent objects from being garbage collected; the difference is that `PROTECT()` is used to protect objects only within a function call, while `R_PreserveObject()` protects objects even after the function exits. When an Rcpp object's lifetime ends, the destructor calls [`R_ReleaseObject()`](https://github.com/wch/r-source/blob/7927e82f/src/main/memory.c#L3327-L3330). Both of these functions must be called on the main R thread; if they are called on a background thread, they may try to modify data structures at the same time as the main thread. The result is a corrupted memory management system.


Symptoms:

* Problems happen randomly


## Tools

(This section is a work in progress.)

These bugs may be difficult to find, but fortunately, we have an array of tools to find them. 

* **`gdb` and `lldb`:**
* **`gctorture()`:** This is an R function which helps find R objects which are not properly protected from garbage collection.
* **`--enable-strict-barrier`:** This is an option used when compiling R. It makes `gctorture()` even more effective.
* R with valgrind: (note: doesn't work with threads on mac) Valgrind levels 0,1,2
* R with SAN:
* R with thread checks:

R-devel
R-devel with strict barrier (configure opt)


### Compiling packages without optimizations

Typically, when R code is compiled

`~/.R/Makevars`:

```
CFLAGS += -g -O0 -Wall
CXXFLAGS += -g -O0 -Wall
CXX11FLAGS += -g -O0 -Wall
```

### `gctorture()`





### GDB in Docker

If you run R with `gdb` in a Docker container, it may just hang when you start R and print this message:

```
# R -d gdb
....
(gdb) run
Starting program: /usr/local/lib/R/bin/exec/R 
warning: Error disabling address space randomization: Operation not permitted
```

The solution is to start the Docker container with `--security-opt seccomp=unconfined`, as mentioned [here](https://stackoverflow.com/questions/35860527/warning-error-disabling-address-space-randomization-operation-not-permitted#comment62818827_35860527).

```
docker run --security-opt seccomp=unconfined --rm -ti --name rp r-protectcheck /bin/bash
```

### SAN build

Memory leaks

### R with write barrier

R objects that are created without `PROTECT()`


```
Error: unprotected object (0x557676a05438) encountered (was ENVSXP)
```

or

```
Error: unprotected object (0x55f2ea0ba018) encountered (was CLOSXP)
```

