{ shadps4 }:

shadps4.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [ ./reuse-duplicate-shader-permutations.patch ];
})
