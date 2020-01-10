# use the gnu make standard library
include gmsl/gmsl

BIN_DIR := output/bin
INCLUDES:= -I output/cpp/runtime -I output/cpp/modules
DEBUG   := "-DDEBUG -g -O3"
RELEASE := "-DNDEBUG -O3"

CXXVERSION = $(shell $(CXX) --version)
ifneq (,$(findstring g++,$(CXXVERSION)))
  PSCPPFLAGS += "--ucns"
endif

override CXXFLAGS += --std=c++11
# debugging makefile, view contents of variable 
print-%:
	@echo '$($*)'
## Not all environments support globstar (** dir pattern)
rwildcard=$(wildcard $1$2) $(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2))
# all ffi sources are in ffi dir and src
FFI_SRCS=$(foreach d,$(wildcard ffi/*),$(wildcard $d/*.cpp)) \
         $(call rwildcard,src/,*.cpp)
# modules which are truely needed
USED_MOD=$(notdir $(wildcard output/dce/*))
# Module to lower case >> '.'->'-', lower case
modtolc=$(foreach m,$(1),$(subst .,-,$(call lc,$(m))))
# Module to underline >> '.'->'_'
modtoul=$(foreach m,$(1),$(subst .,_,$(m)))
# filter out given files $(1) by Modules $(2) 
filtermod=$(strip $(foreach f,$(1),$(if $(filter $(basename $(notdir $(f))),$(2)),$(f))))

# the needed corefn, we take it from output/dce, because
# they only reference the truly needed dependencies
USED_CFN=$(foreach m,$(USED_MOD),output/dce/$(m)/corefn.json)
# ffi cpp
USED_FFI=$(call filtermod,$(FFI_SRCS),$(call modtolc,$(USED_MOD)))
# purescript compiled cpp
USED_PSC=$(foreach m,$(call modtoul,$(USED_MOD)),output/cpp/modules/$(m).cpp)
USED_CPP=$(USED_FFI) $(USED_PSC) $(wildcard output/cpp/runtime/*.cpp)

# purs -> corefn -> dead code elimination -> cpp
#
# we set the timestamp of the dce files to the ones in purs
# because these are the logical correct ones, otherwise
# we would rebuild the generated sources evry time
.PHONY: codegen
codegen:
	@echo "codegen" 
	@spago build -u '--codegen corefn -o output/purs' \
                     -t 'rm -fr output/dce/*'             \
                     -t 'zephyr Main.main -g corefn -i output/purs -o output/dce' \
                     -t '(cd output/dce;for d in *; do touch $$d/corefn.json -r ../purs/$$d/corefn.json; done)' \
                     -t 'pscpp output/dce/*/corefn.json'

USED_OBJ = $(USED_CPP:.cpp=.o)
DEPS = $(USED_OBJ:.o=.d)

-include $(DEPS)

%.o: %.cpp
	@echo "Creating" $@ "(C++)"
	@$(CXX) $(CXXFLAGS) $(INCLUDES) -MMD -MP -c -o $@ $< 

$(BIN_DIR)/main: $(USED_OBJ)
	@echo "Linking" $@
	@mkdir -p $(BIN_DIR)
	@$(CXX) $^ -o $@ $(LDFLAGS)

debug: codegen
	@$(MAKE) $(BIN_DIR)/main CXXFLAGS+=$(DEBUG)

clean-%:
	@-rm -rf output/$*
clean:
	@-rm -rf output
clean-obj:
	@-rm -f $(USED_OBJ)
