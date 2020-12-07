{-# LANGUAGE OverloadedStrings #-}

import Codec.Audio.Wave
import Control.Monad
import qualified Data.ByteString as B
import Shamir
import System.Environment (getArgs)
import System.IO

main = do
  l <- getArgs
  case l of
    "split" : [filename, k', n'] -> do
      let k = read k' :: Int
          n = read n' :: Int
      if k <= n && n > 0 && n < 256
        then do
          wav <- readWaveFile filename
          h <- openFile filename ReadMode
          forM_
            (map fromIntegral [1 .. n])
            ( \n ->
                writeWaveFile
                  (show n ++ filename)
                  wav {waveOtherChunks = ("n", B.singleton n) : (waveOtherChunks wav)}
                  (const $ return ())
            )
          -- guess what const $ return () does? take an argument and return an empty IO action. how boring
          
          handles <- forM [1 .. n] (\n -> openFile (show n ++ filename) ReadWriteMode)
          -- write mode truncates, can't use append because we need to change the size
          
          hSeek h AbsoluteSeek (fromIntegral (waveDataOffset wav) - 4)
          -- TIL negation is haskell's only unary operator. It is binary here though
          
          mapM_ (\a -> hSeek a AbsoluteSeek (fromIntegral (waveDataOffset wav) + 5)) handles
          -- plus 10 for "n   ", size and n(+ buffer). minus 4 for size of the data chunk
          -- minus one because of an off-by-one error that took a long time to debug
          
          size <- B.hGet h 4
          -- get size from original file, copy it over to the shares
          
          forM_ handles $ flip B.hPut size
          -- totally loving not having to write a loop for otherwise imperative actions
          
          forM_
            [1 .. (waveDataSize wav)]
            ( \u -> do
                b <- B.hGet h 1
                shares <- generateShares k (fromIntegral n) (B.head b)
                putStr $ flip replicate '=' (floor $ 20 * (fromIntegral u) / (fromIntegral $ waveDataSize wav)) ++ "\r"
                -- minimal loading screen; strange animations are completely coincidental
                zipWithM_ ((. B.singleton) . B.hPut) handles shares
                -- the point-free form. I can't decide if it's an abomination or a blessing yet
            )
          putStrLn "done."
        else putStrLn "wrong k of n; please ensure k<=n, 0<n<256"
    "reconstruct" : filename : l -> do
      wavs <- mapM readWaveFile l
      print wavs
      let wav = head wavs -- reference file
      
      let ns = map (B.head . snd . head . filter (("n\NUL\NUL\NUL" ==) . fst) . waveOtherChunks) wavs
      -- composition moment
      
      writeWaveFile filename (wav {waveOtherChunks = filter (("n\NUL\NUL\NUL" /=) . fst) $ waveOtherChunks wav}) (const $ return ())
      
      h <- openFile filename AppendMode
      handles <- forM l $ flip openFile ReadMode
      mapM_ (\a -> hSeek a AbsoluteSeek (fromIntegral $ waveDataOffset wav)) handles
      forM_
        [1 .. (waveDataSize wav)]
        ( \u -> do
            shares <- mapM (flip B.hGet 1) handles
            B.hPut h $ B.singleton (combineShares $ zip ns (map B.head shares))
            putStr $ flip replicate '=' (floor $ 20 * (fromIntegral u) / (fromIntegral $ waveDataSize wav)) ++ "\r"
        )
        
      putStrLn "done."
      
    _ -> putStrLn "malformed arguments. please use either \"split file k n\" or \"reconstruct newfilename file1 file2 ..\""
