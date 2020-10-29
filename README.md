# AudioShamir

A utility to split wav files (uncompressed PCM only because of a dependency) into, well, wav files using [Shamir's Secret Sharing Scheme](https://en.wikipedia.org/wiki/Shamir%27s_Secret_Sharing). 

## Some internals
This project originally started as an implementation of [this paper](researchgate.net/publication/274248847). However, the method in the paper

+ uses an expensive pre-processing step
+ is not lossless
+ expects some additional data (namely, size of the prime field and index of shares) to appear out of nowhere

Looking for easier(or better) ways to implement it, I came across the [GF(256)](http://www.cs.utsa.edu/~wagner/laws/FFM.html) field which allows us to directly split individual bytes. This, combined with adding metadata (as additional chunks) into shares gets rid of the aforementioned drawbacks.

The only disadvantage is that the number of shares cannot exceed 255. 

The code at src/Shamir.hs takes inspiration from [codahale/hs-shamir](github.com/codahale/hs-shamir). A commented-out prime-field implementation of the same algorithm is also included.

## Usage

After building the project using cabal, run
```
AudioShamir split filename.wav k n
```
to split the file into n shares with a threshold of k and
```
AudioShamir reconstruct [file_name_to_be_reconstructed] [file names of shares in any order]...
```
to reconstruct the secret. Note that files may be renamed; all the data needed for reconstruction is *inside* them.

[Warning: shares generated tend to be loud static buzz; lower the volume accordingly before listening to them]

I don't see why anyone would waste their time contributing to this, but contributions are welcome.