# purescript-native-build
howto build applications with purescript native cpp

I'm in the process of understanding how purescript native cpp
could be used to create or enhance native applications. 
In the process of evaluation of the current state of art I
stumbled about some issues which I want to outline here as follows.

	* The ability to generate shared objects
		For this to work one has to use explicit "C" linkage for the purescript
		objects (which are c++ functions)
	* Extend the native implementations of the standard packages as they are needed
		The current approach was to implement the "is unimplemented" feature
		which was detected at runtime.
		I feel this is not the intention purescript was made for, because we will
		rely on the code to not throw runtime exceptions which could be resolved
		at compile time.
		By removing this one is faced with the fact that the standard corefn files
		reference also dependencies which are actually never used in the application.
		Therefor [zephyr](https://github.com/coot/zephyr) does a great job by doing
		dead code elimination for given entry points. After this one has to implement 
		only the just needed functionality, - and you will produce only code which 
		will also be used.
	* The infrastructure for the foreign function implementations (FFI:)
		Currently there is an package system which works very fine for the js backend.
		There the ffi's are bundele inside the modules of the package.
		However for the native backends the specific ffi's are distributed as
		an git repository.
		In order to use just the ffi's which are needed for the application the dependencies
		which are luckily be find by corresponding module names will be used.
		If there exists an ffi implementation for an used module it will be build
		and linked in. But not only the ffi's in the ffi repo will be checked,
		also implementations in your source dir.
		Therefore naming conventions for the file and Directory names have to be regarded.
		For the official package  mypackage/{My.ModA My.ModB} we will have the
		native ffi as mypackage/{my-moda.cpp my-modb.cpp} in the ffi repo
		as **/{my-moda.cpp my-modb.cpp} in the purs sources. There is room for 
		an uniform naming convention. 
	* what has to be build and linked
		We use the set of module names we get after the dead code elimination in output/dce
		as key for finding the used modules and ffi's. We have provided one entry point 
		(Main.main) but should be able to get sets of module names for multiple entry points.
		After this one would be able to partion these into shared libs and plugins etc efficently.

We have implemented this for GNU Make and CMake. 

# How to build?

```bash
# Install Git
# Install Haskell Stack
# Install purescript
# Install spago
# Install zephyr
# Build and install purescript native cpp transpiler 'pscpp'
# from git@github.com:freylax/purescript-native.git

# check out this repo

git clone git@github.com:freylax/purescript-native-build.git
cd purescript-native-build

# fetch the ffi and gnumake standard lib
git submodule init
git submodule update

# in the Makefile check that the right pscpp will be used
# compile the project using GNU Make
	
make debug
./output/bin/main
# or for using CMake:

mkdir build
cd build
cmake ..
make
./main
